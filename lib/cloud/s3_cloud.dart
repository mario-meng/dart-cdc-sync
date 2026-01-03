import 'dart:io' as io;
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'cloud.dart';

/// S3-compatible cloud storage implementation
class S3Cloud implements Cloud {
  final String endpoint;
  final String accessKey;
  final String secretKey;
  final String bucket;
  final String region;
  final bool pathStyle;
  final int timeout;
  final int availableSize;

  late final S3 _s3Client;

  S3Cloud({
    required this.endpoint,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    required this.region,
    this.pathStyle = false,
    this.timeout = 60,
    required this.availableSize,
  }) {
    // Initialize S3 client
    _s3Client = S3(
      region: region,
      credentials: AwsClientCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
      ),
      endpointUrl: endpoint,
    );
  }

  void close() {
    _s3Client.close();
  }

  String _getKey(String filePath) {
    // Build key using POSIX path separator, without leading slash
    // Using standard 'repo' prefix for consistency
    return path.posix.join('repo', filePath);
  }

  @override
  Future<int> uploadObject(String filePath, {bool overwrite = false}) async {
    final file = io.File(filePath);
    if (!await file.exists()) {
      throw io.FileSystemException('File not found', filePath);
    }

    final data = await file.readAsBytes();
    return await uploadBytes(filePath, Uint8List.fromList(data),
        overwrite: overwrite);
  }

  @override
  Future<int> uploadBytes(String filePath, Uint8List data,
      {bool overwrite = false}) async {
    final key = _getKey(filePath);

    try {
      await _s3Client.putObject(
        bucket: bucket,
        key: key,
        body: data,
        contentType: 'application/octet-stream',
      );
      return data.length;
    } catch (e) {
      throw Exception('Upload failed for $key: $e');
    }
  }

  @override
  Future<Uint8List> downloadObject(String filePath) async {
    final key = _getKey(filePath);

    try {
      final response = await _s3Client.getObject(
        bucket: bucket,
        key: key,
      );

      if (response.body == null) {
        throw io.FileSystemException('Object not found', filePath);
      }

      return Uint8List.fromList(response.body!);
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('NoSuchKey')) {
        throw io.FileSystemException('Object not found', filePath);
      }
      throw Exception('Download failed for $key: $e');
    }
  }

  @override
  Future<bool> objectExists(String filePath) async {
    final key = _getKey(filePath);

    try {
      await _s3Client.headObject(
        bucket: bucket,
        key: key,
      );
      return true;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('NoSuchKey')) {
        return false;
      }
      // 其他错误重新抛出
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> listObjects(String prefix) async {
    // Build full prefix for S3
    final fullPrefix = prefix.isEmpty ? 'repo/' : 'repo/$prefix';

    try {
      final objects = <String, int>{};
      String? continuationToken;
      int pageCount = 0;

      // 支持分页，获取所有对象
      do {
        pageCount++;
        final response = await _s3Client.listObjectsV2(
          bucket: bucket,
          prefix: fullPrefix,
          maxKeys: 1000,
          continuationToken: continuationToken,
        );

        if (response.contents != null) {
          for (final obj in response.contents!) {
            if (obj.key != null) {
              // Remove 'repo/' prefix to get relative path
              var relativePath = obj.key!;
              if (relativePath.startsWith('repo/')) {
                relativePath = relativePath.substring(5);
              }
              objects[relativePath] = obj.size ?? 0;
            }
          }
        }

        continuationToken = response.nextContinuationToken;

        // 如果还有更多页，继续获取
        if (continuationToken != null) {
          print('  已获取 ${objects.length} 个对象（第 $pageCount 页），继续获取...');
        }
      } while (continuationToken != null);

      if (pageCount > 1) {
        print('  共获取 $pageCount 页，总计 ${objects.length} 个对象');
      }

      return objects;
    } catch (e) {
      // OSS returns NoSuchKey when prefix has no objects, treat as empty
      if (e.toString().contains('NoSuchKey')) {
        return {};
      }
      throw Exception('List objects failed for $prefix: $e');
    }
  }

  @override
  Future<void> deleteObject(String filePath) async {
    final key = _getKey(filePath);

    try {
      await _s3Client.deleteObject(
        bucket: bucket,
        key: key,
      );
    } catch (e) {
      throw Exception('Delete failed for $key: $e');
    }
  }

  @override
  int getAvailableSize() => availableSize;
}
