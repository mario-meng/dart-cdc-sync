import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:pointycastle/export.dart';
import '../entity/index.dart';
import '../entity/file.dart';
import '../entity/chunk.dart';
import '../store/store.dart';
import '../cloud/cloud.dart';
import '../util/hash.dart';
import '../util/chunker_restic.dart';

/// 仓库，负责数据快照和同步
class Repo {
  final String dataPath;
  final String repoPath;
  final String deviceID;
  final String deviceName;
  final String deviceOS;
  final Store store;
  final Cloud? cloud;

  Repo._({
    required this.dataPath,
    required this.repoPath,
    required this.deviceID,
    required this.deviceName,
    required this.deviceOS,
    required this.store,
    this.cloud,
  });

  /// 创建新的仓库
  static Future<Repo> create({
    required String dataPath,
    required String repoPath,
    required String deviceID,
    required String deviceName,
    required String deviceOS,
    required Uint8List aesKey,
    Cloud? cloud,
  }) async {
    // 确保目录存在
    await io.Directory(repoPath).create(recursive: true);
    await io.Directory(path.join(repoPath, 'indexes')).create(recursive: true);
    await io.Directory(path.join(repoPath, 'objects')).create(recursive: true);
    await io.Directory(path.join(repoPath, 'files')).create(recursive: true);
    await io.Directory(path.join(repoPath, 'refs')).create(recursive: true);

    final store = Store(repoPath: repoPath, aesKey: aesKey);

    // 确保路径是绝对路径
    final absDataPath = path.isAbsolute(dataPath)
        ? path.normalize(dataPath)
        : path.normalize(path.absolute(dataPath));
    final absRepoPath = path.isAbsolute(repoPath)
        ? path.normalize(repoPath)
        : path.normalize(path.absolute(repoPath));

    return Repo._(
      dataPath: absDataPath,
      repoPath: absRepoPath,
      deviceID: deviceID,
      deviceName: deviceName,
      deviceOS: deviceOS,
      store: store,
      cloud: cloud,
    );
  }

  /// 获取相对路径
  String _relPath(String absPath) {
    final normalized = path.normalize(path.absolute(absPath));
    if (!normalized.startsWith(dataPath)) {
      throw ArgumentError(
          'Path is not under dataPath: $absPath (dataPath: $dataPath)');
    }
    var relative = normalized.substring(dataPath.length);
    // 移除开头的路径分隔符
    while (relative.isNotEmpty &&
        (relative.startsWith('/') || relative.startsWith('\\'))) {
      relative = relative.substring(1);
    }
    // 确保以 / 开头
    return '/' + relative.replaceAll('\\', '/');
  }

  /// 获取绝对路径
  String _absPath(String relPath) {
    // 移除开头的 '/'
    var cleanPath = relPath;
    while (cleanPath.isNotEmpty && cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    return path.join(dataPath, cleanPath);
  }

  /// 获取最新的索引
  Future<Index?> latest() async {
    final latestFile = io.File(path.join(repoPath, 'refs', 'latest'));
    if (!await latestFile.exists()) {
      return null;
    }

    final indexID = (await latestFile.readAsString()).trim();
    return await store.getIndex(indexID);
  }

  /// 更新最新索引引用
  Future<void> updateLatest(Index index) async {
    final refsDir = io.Directory(path.join(repoPath, 'refs'));
    await refsDir.create(recursive: true);

    final latestFile = io.File(path.join(repoPath, 'refs', 'latest'));
    await latestFile.writeAsString(index.id);
  }

  /// 创建索引
  Future<Index> index(String memo) async {
    final startTime = DateTime.now();

    // 扫描文件
    final files = <File>[];
    await _walkDataPath((filePath, stat) {
      final relPath = _relPath(filePath);
      files.add(File.newFile(
          relPath, stat.size, stat.modified.millisecondsSinceEpoch));
    });

    final scanDuration = DateTime.now().difference(startTime);
    print('文件扫描完成: ${files.length} 个文件，耗时 ${scanDuration.inMilliseconds}ms');

    if (files.isEmpty) {
      throw Exception('Empty index: no files found');
    }

    // 获取最新索引
    final latest = await this.latest();
    final isInit = latest == null;

    // 创建新索引（无论是否初始化）
    Index currentIndex = Index(
      id: randHash(),
      memo: memo,
      created: DateTime.now().millisecondsSinceEpoch,
      files: [],
      count: 0,
      size: 0,
      systemID: deviceID,
      systemName: deviceName,
      systemOS: deviceOS,
    );

    // 计算差异
    List<File> latestFiles = [];
    if (!isInit) {
      latestFiles = await _getFiles(latest!.files);
    }

    final (upserts, removes) = _diffFiles(files, latestFiles);

    if (upserts.isEmpty && removes.isEmpty && !isInit) {
      // 没有变化，返回最新索引
      return latest!;
    }

    // 处理需要更新的文件（限制并发数）
    final chunkStartTime = DateTime.now();
    print('处理变更文件: ${upserts.length} 个');

    // 限制并发数，避免过多文件同时打开
    const maxConcurrency = 3;
    for (int i = 0; i < upserts.length; i += maxConcurrency) {
      final batch = upserts.skip(i).take(maxConcurrency).toList();
      final futures = batch.asMap().entries.map((entry) {
        final idx = i + entry.key;
        final file = entry.value;
        return _putFileChunks(file).then((_) {
          print('  [${idx + 1}/${upserts.length}] ${file.path}');
        });
      }).toList();

      await Future.wait(futures);
    }

    final chunkDuration = DateTime.now().difference(chunkStartTime);
    print('文件分块完成，耗时 ${chunkDuration.inMilliseconds}ms');

    // 构建新索引
    for (final file in files) {
      currentIndex = Index(
        id: currentIndex.id,
        memo: currentIndex.memo,
        created: currentIndex.created,
        files: [...currentIndex.files, file.id],
        count: currentIndex.count + 1,
        size: currentIndex.size + file.size,
        systemID: currentIndex.systemID,
        systemName: currentIndex.systemName,
        systemOS: currentIndex.systemOS,
        checkIndexID: currentIndex.checkIndexID,
      );
    }

    // 保存索引
    await store.putIndex(currentIndex);
    await updateLatest(currentIndex);

    return currentIndex;
  }

  /// 处理文件分块
  Future<void> _putFileChunks(File fileEntity) async {
    final absPath = _absPath(fileEntity.path);

    // 检查文件是否存在
    final file = io.File(absPath);
    if (!await file.exists()) {
      throw io.FileSystemException(
        'File not found: $absPath (relative path: ${fileEntity.path})',
        absPath,
      );
    }

    final fileStat = await file.stat();

    // If file is smaller than min chunk size, treat as single chunk
    if (fileStat.size < ResticChunker.getMinSize()) {
      final data = await io.File(absPath).readAsBytes();
      final chunkHash = hash(data);
      fileEntity.chunks.add(chunkHash);

      final chunk = Chunk(id: chunkHash, data: data);
      await store.putChunk(chunk);
    } else {
      // Use restic/chunker via FFI
      final resticChunker = ResticChunker(absPath);
      try {
        await resticChunker.init();
        final chunks = await resticChunker.getChunks();

        for (final chunk in chunks) {
          fileEntity.chunks.add(chunk.id);
          await store.putChunk(chunk);
        }
      } finally {
        resticChunker.close();
      }
    }

    // Save file metadata
    await store.putFile(fileEntity);
  }

  /// 获取文件列表
  Future<List<File>> _getFiles(List<String> fileIDs) async {
    final files = <File>[];
    for (final fileID in fileIDs) {
      try {
        final file = await store.getFile(fileID);
        files.add(file);
      } catch (e) {
        // 忽略不存在的文件
      }
    }
    return files;
  }

  /// 计算文件差异
  (List<File>, List<File>) _diffFiles(List<File> current, List<File> latest) {
    final currentMap = {for (var f in current) f.path: f};
    final latestMap = {for (var f in latest) f.path: f};

    final upserts = <File>[];
    final removes = <File>[];

    // 找出新增和修改的文件
    for (final file in current) {
      final latestFile = latestMap[file.path];
      if (latestFile == null || latestFile.id != file.id) {
        upserts.add(file);
      }
    }

    // 找出删除的文件
    for (final file in latest) {
      if (!currentMap.containsKey(file.path)) {
        removes.add(file);
      }
    }

    return (upserts, removes);
  }

  /// 遍历数据路径
  Future<void> _walkDataPath(
      Function(String filePath, io.FileStat stat) callback) async {
    final dir = io.Directory(dataPath);
    if (!await dir.exists()) {
      print('警告: 数据目录不存在: $dataPath');
      return;
    }

    int fileCount = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is io.File) {
        // 跳过隐藏文件和临时文件
        final name = path.basename(entity.path);
        if (name.startsWith('.') || name.endsWith('.tmp')) {
          continue;
        }

        // 跳过特定文件
        try {
          final relPath = _relPath(entity.path);
          if (relPath.endsWith('/storage/local.json') ||
              relPath.endsWith('/storage/recent-doc.json')) {
            continue;
          }

          final stat = await entity.stat();
          if (stat.type == io.FileSystemEntityType.file) {
            callback(entity.path, stat);
            fileCount++;
          }
        } catch (e) {
          // 如果路径转换失败，尝试直接使用
          try {
            final stat = await entity.stat();
            if (stat.type == io.FileSystemEntityType.file) {
              callback(entity.path, stat);
              fileCount++;
            }
          } catch (e2) {
            // 忽略无法访问的文件
            print('警告: 无法访问文件 ${entity.path}: $e2');
          }
        }
      }
    }

    if (fileCount == 0) {
      print('警告: 在 $dataPath 中没有找到任何文件');
    }
  }

  /// 同步到云端（双向同步）
  Future<SyncResult> sync() async {
    if (cloud == null) {
      throw Exception('Cloud storage not configured');
    }

    // 获取本地最新索引
    final localLatest = await latest();
    final hasLocalData = localLatest != null;

    // 获取云端最新索引
    Index? cloudLatest;
    try {
      final latestData = await cloud!.downloadObject('refs/latest');
      final cloudLatestID = String.fromCharCodes(latestData).trim();

      // 下载并解析云端索引
      final indexData = await cloud!.downloadObject('indexes/$cloudLatestID');

      // 索引数据只压缩不加密
      try {
        final decompressed =
            await store.compressionInstance.decompress(indexData);
        cloudLatest = Index.fromJson(
          jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>,
        );
      } catch (e) {
        // 如果解压失败，尝试直接解析
        try {
          cloudLatest = Index.fromJson(
            jsonDecode(utf8.decode(indexData)) as Map<String, dynamic>,
          );
        } catch (e2) {
          throw Exception('Failed to parse cloud index: $e, $e2');
        }
      }

      print('云端索引: ${cloudLatest.id}');
      print('云端文件数: ${cloudLatest.count}');
    } catch (e) {
      print('云端没有索引或获取失败: $e');
    }

    // 决定同步方向
    if (cloudLatest == null && hasLocalData) {
      // 云端无数据，本地有数据 -> 上传
      print('云端无数据，上传本地数据');
      return await _uploadToCloud(localLatest!);
    } else if (cloudLatest != null && !hasLocalData) {
      // 云端有数据，本地无数据 -> 下载
      print('本地无数据，从云端下载');
      return await _downloadFromCloud(cloudLatest);
    } else if (cloudLatest != null && hasLocalData) {
      // 双方都有数据 -> 比较并同步
      if (cloudLatest.id == localLatest!.id) {
        // Data matches, check if local files exist
        final missingFiles = await _checkLocalFiles(cloudLatest);
        if (missingFiles.isNotEmpty) {
          // Local files missing, restore from cloud
          print('Local files missing (${missingFiles.length}), restoring from cloud');
          return await _downloadFromCloud(cloudLatest);
        }

        print('Local and cloud data are in sync, no changes needed');
        return SyncResult(
          dataChanged: false,
          uploadBytes: 0,
          downloadBytes: 0,
          uploadFileCount: 0,
          downloadFileCount: 0,
          uploadChunkCount: 0,
          downloadChunkCount: 0,
        );
      }

      // 简化处理：如果云端更新，下载；否则上传
      if (cloudLatest.created > localLatest.created) {
        print('云端数据更新，下载云端数据');
        return await _downloadFromCloud(cloudLatest);
      } else {
        print('本地数据更新，上传本地数据');
        return await _uploadToCloud(localLatest);
      }
    } else {
      throw Exception('No data to sync');
    }
  }

  /// 检查本地文件是否存在
  Future<List<String>> _checkLocalFiles(Index index) async {
    final missingFiles = <String>[];

    try {
      final files = await _getFiles(index.files);

      for (final file in files) {
        final absPath = _absPath(file.path);
        final localFile = io.File(absPath);

        // 检查文件是否存在且大小一致
        if (!await localFile.exists()) {
          missingFiles.add(file.path);
        } else {
          final stat = await localFile.stat();
          if (stat.size != file.size) {
            missingFiles.add(file.path);
          }
        }
      }
    } catch (e) {
      // 如果无法获取文件列表，认为文件丢失
      print('检查本地文件失败: $e');
      return ['<all>'];
    }

    if (missingFiles.isNotEmpty) {
      print('本地缺失或不一致的文件: ${missingFiles.length} 个');
    }

    return missingFiles;
  }

  /// 上传到云端
  Future<SyncResult> _uploadToCloud(Index localLatest) async {
    print('上传本地数据到云端...');

    final uploadStats = UploadStats();
    await _uploadMissingObjects(localLatest, uploadStats);

    // 更新云端 latest 引用
    await cloud!.uploadBytes(
        'refs/latest', Uint8List.fromList(localLatest.id.codeUnits));

    return SyncResult(
      dataChanged:
          uploadStats.uploadChunkCount > 0 || uploadStats.uploadFileCount > 0,
      uploadBytes: uploadStats.uploadBytes,
      downloadBytes: 0,
      uploadFileCount: uploadStats.uploadFileCount,
      downloadFileCount: 0,
      uploadChunkCount: uploadStats.uploadChunkCount,
      downloadChunkCount: 0,
    );
  }

  /// 从云端下载
  Future<SyncResult> _downloadFromCloud(Index cloudLatest) async {
    print('从云端下载数据...');

    final downloadStats = DownloadStats();

    // 下载所有文件
    final files = await _downloadCloudFiles(cloudLatest, downloadStats);

    // 恢复文件到本地
    await _restoreFiles(files);

    // 保存索引到本地
    await store.putIndex(cloudLatest);
    await updateLatest(cloudLatest);

    return SyncResult(
      dataChanged: true,
      uploadBytes: 0,
      downloadBytes: downloadStats.downloadBytes,
      uploadFileCount: 0,
      downloadFileCount: downloadStats.downloadFileCount,
      uploadChunkCount: 0,
      downloadChunkCount: downloadStats.downloadChunkCount,
    );
  }

  /// 下载云端文件（限制并发数）
  Future<List<File>> _downloadCloudFiles(
      Index cloudIndex, DownloadStats stats) async {
    const maxConcurrency = 5; // 最大并发数
    final files = <File>[];

    // 并发下载所有文件元数据
    final fileFutures = cloudIndex.files.map((fileID) async {
      final fileData = await cloud!.downloadObject(
        'files/${fileID.substring(0, 2)}/${fileID.substring(2)}',
      );
      stats.downloadBytes += fileData.length;
      stats.downloadFileCount++;

      // 文件元数据需要先解密再解压
      final keyParam = KeyParameter(store.aesKey);
      final iv = Uint8List(16);
      final params = PaddedBlockCipherParameters(
        ParametersWithIV(keyParam, iv),
        null,
      );
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(false, params);
      final decrypted = Uint8List.fromList(cipher.process(fileData));

      final decompressed =
          await store.compressionInstance.decompress(decrypted);
      final fileJson =
          jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
      return File.fromJson(fileJson);
    }).toList();

    files.addAll(await Future.wait(fileFutures));

    // 收集所有需要下载的块任务
    final chunkDownloadTasks = <Future<void> Function()>[];
    for (final file in files) {
      for (final chunkID in file.chunks) {
        if (!await store.chunkExists(chunkID)) {
          chunkDownloadTasks.add(() async {
            final chunkData = await cloud!.downloadObject(
              'objects/${chunkID.substring(0, 2)}/${chunkID.substring(2)}',
            );
            stats.downloadBytes += chunkData.length;
            stats.downloadChunkCount++;

            final chunkPath = path.join(
              repoPath,
              'objects',
              chunkID.substring(0, 2),
              chunkID.substring(2),
            );
            await io.Directory(path.dirname(chunkPath)).create(recursive: true);
            await io.File(chunkPath).writeAsBytes(chunkData);

            print('  下载块: $chunkID (${_formatBytes(chunkData.length)})');
          });
        }
      }
    }

    // 分批并发下载块
    for (int i = 0; i < chunkDownloadTasks.length; i += maxConcurrency) {
      final batch = chunkDownloadTasks.skip(i).take(maxConcurrency);
      await Future.wait(batch.map((task) => task()));
    }

    // 保存所有文件元数据
    for (final file in files) {
      await store.putFile(file);
    }

    return files;
  }

  /// 恢复文件到数据目录
  Future<void> _restoreFiles(List<File> files) async {
    for (final file in files) {
      final absPath = _absPath(file.path);

      // 确保目录存在
      await io.Directory(path.dirname(absPath)).create(recursive: true);

      // 组装文件内容
      final buffer = <int>[];
      for (final chunkID in file.chunks) {
        final chunk = await store.getChunk(chunkID);
        buffer.addAll(chunk.data);
      }

      // 写入文件
      await io.File(absPath).writeAsBytes(buffer);

      print('已恢复: ${file.path} (${_formatBytes(file.size)})');
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

  /// 上传缺失的对象（优化版本）
  Future<void> _uploadMissingObjects(Index index, UploadStats stats) async {
    const maxConcurrency = 20; // 最大并发数（上传）

    // 上传索引
    final indexData =
        await io.File(path.join(repoPath, 'indexes', index.id)).readAsBytes();
    await cloud!.uploadBytes('indexes/${index.id}', indexData);
    stats.uploadBytes += indexData.length;

    // 获取所有文件
    final files = await _getFiles(index.files);

    // Concurrent object existence checking (OSS uses HeadObject)
    print('Checking cloud objects (concurrent HeadObject)...');
    
    final uploadTasks = <Future<void> Function()>[];
    int newChunks = 0;
    int existingChunks = 0;
    int newFiles = 0;
    int existingFiles = 0;

    // Batch check file metadata existence
    final fileCheckFutures = files.map((file) async {
      final filePath =
          'files/${file.id.substring(0, 2)}/${file.id.substring(2)}';
      final exists = await cloud!.objectExists(filePath);
      return {'file': file, 'path': filePath, 'exists': exists};
    }).toList();
    
    final fileResults = await Future.wait(fileCheckFutures);
    
    for (final result in fileResults) {
      if (!(result['exists'] as bool)) {
        newFiles++;
        final file = result['file'] as File;
        final filePath = result['path'] as String;
        uploadTasks.add(() async {
          final fileData = await io.File(path.join(repoPath, 'files',
                  file.id.substring(0, 2), file.id.substring(2)))
              .readAsBytes();
          await cloud!.uploadBytes(filePath, fileData);
          stats.uploadBytes += fileData.length;
          stats.uploadFileCount++;
        });
      } else {
        existingFiles++;
      }
    }

    // 收集所有需要检查的chunks
    final allChunkPaths = <Map<String, String>>[];
    for (final file in files) {
      for (final chunkID in file.chunks) {
        allChunkPaths.add({
          'id': chunkID,
          'path': 'objects/${chunkID.substring(0, 2)}/${chunkID.substring(2)}',
        });
      }
    }
    
    print('Checking ${allChunkPaths.length} chunks...');
    
    // 尝试使用 ListObjects 批量查询（最快）
    Map<String, bool>? cloudObjects;
    try {
      print('使用 ListObjects 批量查询云端对象...');
      cloudObjects = await _listCloudObjects();
      print('已获取云端对象列表: ${cloudObjects.length} 个对象');
    } catch (e) {
      print('批量查询失败，将使用 HeadObject 逐个检查: $e');
    }
    
    if (cloudObjects != null && cloudObjects.isNotEmpty) {
      // 使用批量查询结果（非常快）
      for (final chunk in allChunkPaths) {
        final exists = cloudObjects.containsKey(chunk['path']!);
        if (!exists) {
          newChunks++;
          uploadTasks.add(() async {
            final chunkData = await io.File(path.join(repoPath, 'objects',
                    chunk['id']!.substring(0, 2), chunk['id']!.substring(2)))
                .readAsBytes();
            await cloud!.uploadBytes(chunk['path']!, chunkData);
            stats.uploadBytes += chunkData.length;
            stats.uploadChunkCount++;
          });
        } else {
          existingChunks++;
        }
      }
      print('批量检查完成！');
    } else {
      // 降级方案：使用高并发 HeadObject
      const checkConcurrency = 50; // 检查并发数（HeadObject请求很轻量，可以高并发）
      print('使用并发 HeadObject 检查（并发度: $checkConcurrency）...');
      
      for (int i = 0; i < allChunkPaths.length; i += checkConcurrency) {
        final batch = allChunkPaths.skip(i).take(checkConcurrency);
        final checkFutures = batch.map((chunk) async {
          final exists = await cloud!.objectExists(chunk['path']!);
          return {'chunk': chunk, 'exists': exists};
        }).toList();
        
        final results = await Future.wait(checkFutures);
        
        for (final result in results) {
          final chunk = result['chunk'] as Map<String, String>;
          if (!(result['exists'] as bool)) {
            newChunks++;
            uploadTasks.add(() async {
              final chunkData = await io.File(path.join(repoPath, 'objects',
                      chunk['id']!.substring(0, 2), chunk['id']!.substring(2)))
                  .readAsBytes();
              await cloud!.uploadBytes(chunk['path']!, chunkData);
              stats.uploadBytes += chunkData.length;
              stats.uploadChunkCount++;
            });
          } else {
            existingChunks++;
          }
        }
        
        // 进度提示（每50个显示一次）
        final current = i + batch.length;
        if (current % 50 == 0 || current == allChunkPaths.length) {
          print('  已检查 $current/${allChunkPaths.length} chunks...');
        }
      }
    }

    print('Analysis: $newFiles new files, $existingFiles existing files');
    print('Analysis: $newChunks new chunks, $existingChunks existing chunks');
    print('Total to upload: ${uploadTasks.length} objects');

    // 分批并发执行（限制并发数）
    for (int i = 0; i < uploadTasks.length; i += maxConcurrency) {
      final batch = uploadTasks.skip(i).take(maxConcurrency);
      await Future.wait(batch.map((task) => task()));
    }
  }

  /// Batch list cloud objects (optimize API calls)
  /// Note: OSS may return NoSuchKey for empty prefixes, which is handled gracefully
  Future<Map<String, bool>> _listCloudObjects() async {
    final objects = <String, bool>{};

    try {
      // List with empty prefix to get all objects under repo/
      final allObjects = await cloud!.listObjects('');
      
      allObjects.forEach((key, value) {
        objects[key] = true;
      });
      
      print('Cloud objects found: ${objects.length} (may be 0 if first sync or OSS returns NoSuchKey)');
    } catch (e) {
      // Listing may fail, will check objects individually during upload
      // This is normal for first sync or when OSS returns NoSuchKey for empty results
    }

    return objects;
  }
}

/// 同步结果
class SyncResult {
  final bool dataChanged;
  final int uploadBytes;
  final int downloadBytes;
  final int uploadFileCount;
  final int downloadFileCount;
  final int uploadChunkCount;
  final int downloadChunkCount;

  SyncResult({
    required this.dataChanged,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.uploadFileCount,
    required this.downloadFileCount,
    required this.uploadChunkCount,
    required this.downloadChunkCount,
  });
}

/// 上传统计
class UploadStats {
  int uploadBytes = 0;
  int uploadFileCount = 0;
  int uploadChunkCount = 0;
}

/// 下载统计
class DownloadStats {
  int downloadBytes = 0;
  int downloadFileCount = 0;
  int downloadChunkCount = 0;
}
