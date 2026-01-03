// This script is for testing purposes only
// Simple example demonstrating Flow Repo usage

import 'dart:io' as io;
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart';
import 'package:flow_repo/flow_repo.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('data-path',
        abbr: 'd', mandatory: true, help: 'Data directory path')
    ..addOption('repo-path',
        abbr: 'r', mandatory: true, help: 'Local repository path')
    ..addOption('remote-path',
        abbr: 'p', mandatory: true, help: 'Remote server storage path')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help information')
    ..addCommand(
        'index',
        ArgParser()
          ..addOption('memo',
              abbr: 'm', defaultsTo: '[Auto] Index', help: 'Index memo'))
    ..addCommand('sync', ArgParser());

  final results = parser.parse(args);

  if (results['help'] == true || results.command == null) {
    print('Flow Repo - Test Script');
    print('NOTE: This script is for testing purposes only');
    print('');
    print('Usage:');
    print('  dart run bin/main.dart <command> [options]');
    print('');
    print('Commands:');
    print('  index    Create data index');
    print('  sync     Sync to cloud');
    print('');
    print('Options:');
    print(parser.usage);
    io.exit(0);
  }

  // Load environment variables from .env file
  final envFile = io.File('.env');
  if (!await envFile.exists()) {
    print('Error: .env file not found');
    print('Please copy .env.demo to .env and update with your configuration:');
    print('  cp .env.demo .env');
    print('  # Then edit .env with your actual values');
    io.exit(1);
  }
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);

  // Get configuration from command line
  final dataPath = _expandPath(results['data-path'] as String);
  final repoPath = _expandPath(results['repo-path'] as String);
  final remotePath = results['remote-path'] as String;

  // AES key (32 bytes) - must be provided via environment
  final aesKeyStr = env['AES_KEY'];
  if (aesKeyStr == null || aesKeyStr.isEmpty) {
    print('Error: AES_KEY not found in .env file');
    io.exit(1);
  }
  final aesKey = Uint8List.fromList(aesKeyStr.codeUnits.take(32).toList());

  // Create repository
  Cloud? cloud;
  if (results.command!.name == 'sync') {
    // Configure S3 cloud storage - all values from .env
    final accessKey = env['AWS_ACCESS_KEY_ID'];
    final secretKey = env['AWS_SECRET_ACCESS_KEY'];
    final bucket = env['S3_BUCKET'];
    final endpoint = env['S3_ENDPOINT'];
    final region = env['S3_REGION'];

    // Validate required environment variables
    if (accessKey == null || accessKey.isEmpty) {
      print('Error: AWS_ACCESS_KEY_ID not found in .env file');
      io.exit(1);
    }
    if (secretKey == null || secretKey.isEmpty) {
      print('Error: AWS_SECRET_ACCESS_KEY not found in .env file');
      io.exit(1);
    }
    if (bucket == null || bucket.isEmpty) {
      print('Error: S3_BUCKET not found in .env file');
      io.exit(1);
    }
    if (endpoint == null || endpoint.isEmpty) {
      print('Error: S3_ENDPOINT not found in .env file');
      io.exit(1);
    }
    if (region == null || region.isEmpty) {
      print('Error: S3_REGION not found in .env file');
      io.exit(1);
    }

    print('Using cloud storage configuration:');
    print('  Bucket: $bucket');
    print('  Endpoint: $endpoint');
    print('  Region: $region');
    print('  Remote Path: $remotePath');
    print('');

    // Use path-style for standard S3
    final s3Endpoint =
        endpoint.startsWith('http') ? endpoint : 'https://$endpoint';

    cloud = S3Cloud(
      endpoint: s3Endpoint,
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
      availableSize: 100 * 1024 * 1024 * 1024, // 100GB
    );
  }

  final repo = await Repo.create(
    dataPath: dataPath,
    repoPath: repoPath,
    deviceID: 'device-001',
    deviceName: 'Test Device',
    deviceOS: io.Platform.operatingSystem,
    aesKey: aesKey,
    cloud: cloud,
    remotePath: remotePath,
  );

  try {
    if (results.command!.name == 'index') {
      final memo = results.command!['memo'] as String;
      print('Starting to create index...');
      print('Data directory: $dataPath');
      print('Repository directory: $repoPath');
      print('Remote path: $remotePath');
      print('Index memo: $memo');
      print('');

      try {
        final startTime = DateTime.now();
        final index = await repo.index(memo);
        final duration = DateTime.now().difference(startTime);

        print('Index created successfully!');
        print('Index ID: ${index.id}');
        print('File count: ${index.count}');
        print('Total size: ${_formatBytes(index.size)}');
        print(
            'Created at: ${DateTime.fromMillisecondsSinceEpoch(index.created)}');
        print('Duration: ${duration.inMilliseconds}ms');
      } catch (e) {
        print('Error: $e');
        io.exit(1);
      }
    } else if (results.command!.name == 'sync') {
      print('Starting to sync to cloud...');
      print('Data directory: $dataPath');
      print('Repository directory: $repoPath');
      print('Remote path: $remotePath');
      print('');

      try {
        final totalStartTime = DateTime.now();

        // Execute sync (sync method handles automatically)
        final result = await repo.sync();

        final totalDuration = DateTime.now().difference(totalStartTime);

        print('\nSync completed!');
        print('Data changed: ${result.dataChanged ? "Yes" : "No"}');
        print(
            'Total duration: ${totalDuration.inMilliseconds}ms (${(totalDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');

        if (result.uploadBytes > 0) {
          print('\n[Upload Statistics]');
          print('Upload traffic: ${_formatBytes(result.uploadBytes)}');
          print('Upload file count: ${result.uploadFileCount}');
          print('Upload chunk count: ${result.uploadChunkCount}');
        }
        if (result.downloadBytes > 0) {
          print('\n[Download Statistics]');
          print('Download traffic: ${_formatBytes(result.downloadBytes)}');
          print('Download file count: ${result.downloadFileCount}');
          print('Download chunk count: ${result.downloadChunkCount}');
        }
      } catch (e) {
        print('Error: $e');
        io.exit(1);
      }
    }
  } finally {
    // Clean up resources
    if (cloud != null && cloud is S3Cloud) {
      cloud.close();
    }
  }
}

/// Format bytes to human-readable string
String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}

/// Expand tilde (~) in path to user home directory
String _expandPath(String path) {
  if (path.startsWith('~/')) {
    final home =
        io.Platform.environment['HOME'] ?? io.Platform.environment['USERPROFILE'];
    if (home != null) {
      return path.replaceFirst('~', home);
    }
  }
  return path;
}
