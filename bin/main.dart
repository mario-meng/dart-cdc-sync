import 'dart:io';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart';
import 'package:flow_repo/flow_repo.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('data-path', abbr: 'd', defaultsTo: './data-0', help: '数据目录路径')
    ..addOption('repo-path',
        abbr: 'r', defaultsTo: './.flow-repo', help: '仓库目录路径')
    ..addFlag('help', abbr: 'h', negatable: false, help: '显示帮助信息')
    ..addCommand(
        'index',
        ArgParser()
          ..addOption('memo',
              abbr: 'm', defaultsTo: '[Auto] Index', help: '索引备注'))
    ..addCommand('sync', ArgParser());

  final results = parser.parse(args);

  if (results['help'] == true || results.command == null) {
    print('Flow Repo - 数据快照和同步工具');
    print('');
    print('用法:');
    print('  dart run bin/main.dart <command> [options]');
    print('');
    print('命令:');
    print('  index    创建数据索引');
    print('  sync     同步到云端');
    print('');
    print('选项:');
    print(parser.usage);
    exit(0);
  }

  // 加载环境变量
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);

  // 获取配置
  final dataPath = results['data-path'] as String;
  final repoPath = results['repo-path'] as String;

  // AES 密钥（32字节）
  final aesKeyStr = env['AES_KEY'] ?? '12345678901234567890123456789012';
  final aesKey = Uint8List.fromList(aesKeyStr.codeUnits.take(32).toList());

  // 创建仓库
  Cloud? cloud;
  if (results.command!.name == 'sync') {
    // 配置 S3 云存储
    final accessKey = env['OSS_ACCESS_KEY_ID'] ?? '';
    final secretKey = env['OSS_ACCESS_KEY_SECRET'] ?? '';
    final bucket = env['OSS_BUCKET_NAME'] ?? '';
    final endpoint = env['OSS_ENDPOINT'] ?? '';
    final region = env['OSS_REGION'] ?? 'oss-cn-shenzhen';

    if (accessKey.isEmpty ||
        secretKey.isEmpty ||
        bucket.isEmpty ||
        endpoint.isEmpty) {
      print('错误: 同步需要配置 OSS 环境变量');
      print('请设置以下环境变量:');
      print('  OSS_ACCESS_KEY_ID');
      print('  OSS_ACCESS_KEY_SECRET');
      print('  OSS_BUCKET_NAME');
      print('  OSS_ENDPOINT');
      exit(1);
    }

    // 阿里云 OSS 需要使用虚拟主机样式的 endpoint
    // 格式：https://bucket.endpoint
    final ossEndpoint = endpoint.contains('aliyuncs.com')
        ? 'https://$bucket.$endpoint'
        : (endpoint.startsWith('http') ? endpoint : 'https://$endpoint');

    cloud = S3Cloud(
      endpoint: ossEndpoint,
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
    deviceName: 'My Device',
    deviceOS: Platform.operatingSystem,
    aesKey: aesKey,
    cloud: cloud,
  );

  try {
    if (results.command!.name == 'index') {
    final memo = results.command!['memo'] as String;
    print('开始创建索引...');
    print('数据目录: $dataPath');
    print('仓库目录: $repoPath');
    print('索引备注: $memo');
    print('');

    try {
      final startTime = DateTime.now();
      final index = await repo.index(memo);
      final duration = DateTime.now().difference(startTime);

      print('索引创建成功!');
      print('索引 ID: ${index.id}');
      print('文件数量: ${index.count}');
      print('总大小: ${_formatBytes(index.size)}');
      print('创建时间: ${DateTime.fromMillisecondsSinceEpoch(index.created)}');
      print('耗时: ${duration.inMilliseconds}ms');
    } catch (e) {
      print('错误: $e');
      exit(1);
    }
  } else if (results.command!.name == 'sync') {
    print('开始同步到云端...');
    print('数据目录: $dataPath');
    print('仓库目录: $repoPath');
    print('');

    try {
      final totalStartTime = DateTime.now();

      // 执行同步（sync 方法会自动处理）
      final result = await repo.sync();

      final totalDuration = DateTime.now().difference(totalStartTime);

      print('\n同步完成!');
      print('数据变更: ${result.dataChanged ? "是" : "否"}');
      print(
          '总耗时: ${totalDuration.inMilliseconds}ms (${(totalDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');

      if (result.uploadBytes > 0) {
        print('\n【上传统计】');
        print('上传流量: ${_formatBytes(result.uploadBytes)}');
        print('上传文件数: ${result.uploadFileCount}');
        print('上传块数: ${result.uploadChunkCount}');
      }
      if (result.downloadBytes > 0) {
        print('\n【下载统计】');
        print('下载流量: ${_formatBytes(result.downloadBytes)}');
        print('下载文件数: ${result.downloadFileCount}');
        print('下载块数: ${result.downloadChunkCount}');
      }
    } catch (e) {
      print('错误: $e');
      exit(1);
    }
  }
  } finally {
    // Clean up resources
    if (cloud != null && cloud is S3Cloud) {
      cloud.close();
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}
