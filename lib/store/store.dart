import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../entity/chunk.dart';
import '../entity/file.dart';
import '../entity/index.dart';
import '../util/hash.dart';
import '../util/crypto.dart';
import '../util/compression.dart';

/// Storage layer responsible for local storage, compression and encryption
class Store {
  final String repoPath;
  final Uint8List aesKey;
  final Compression compression;

  Store({
    required this.repoPath,
    required this.aesKey,
  }) : compression = Compression();

  /// Public access to compression (used by Repo for index decompression)
  Compression get compressionInstance => compression;

  /// Get absolute path for chunk
  String _chunkAbsPath(String id) {
    final dir = id.substring(0, 2);
    final file = id.substring(2);
    return path.join(repoPath, 'objects', dir, file);
  }

  /// Get absolute path for index
  String _indexAbsPath(String id) {
    return path.join(repoPath, 'indexes', id);
  }

  /// Get absolute path for file metadata
  String _fileAbsPath(String id) {
    final dir = id.substring(0, 2);
    final file = id.substring(2);
    return path.join(repoPath, 'files', dir, file);
  }

  /// Store chunk
  Future<void> putChunk(Chunk chunk) async {
    if (chunk.id.isEmpty) {
      throw ArgumentError('Invalid chunk ID');
    }

    final filePath = _chunkAbsPath(chunk.id);
    final file = io.File(filePath);

    // Return if already exists
    if (await file.exists()) {
      return;
    }

    // Ensure directory exists
    await file.parent.create(recursive: true);

    // Compress and encrypt
    final encoded = await _encodeData(Uint8List.fromList(chunk.data));

    // Write file safely
    await _writeFileSafer(filePath, encoded);
  }

  /// Get chunk by ID
  Future<Chunk> getChunk(String id) async {
    final filePath = _chunkAbsPath(id);
    final file = io.File(filePath);

    if (!await file.exists()) {
      throw io.FileSystemException('Chunk not found', filePath);
    }

    final data = await file.readAsBytes();
    final decoded = await _decodeData(data);

    return Chunk(id: id, data: decoded);
  }

  /// 检查 Chunk 是否存在
  Future<bool> chunkExists(String id) async {
    final filePath = _chunkAbsPath(id);
    return await io.File(filePath).exists();
  }

  /// 存储 File
  Future<void> putFile(File file) async {
    if (file.id.isEmpty) {
      throw ArgumentError('Invalid file ID');
    }

    final filePath = _fileAbsPath(file.id);
    final f = io.File(filePath);

    // 确保目录存在
    await f.parent.create(recursive: true);

    // 序列化为 JSON
    final json = jsonEncode(file.toJson());
    final data = utf8.encode(json);

    // 压缩和加密
    final encoded = await _encodeData(Uint8List.fromList(data));

    // 安全写入文件
    await _writeFileSafer(filePath, encoded);
  }

  /// 获取 File
  Future<File> getFile(String id) async {
    final filePath = _fileAbsPath(id);
    final f = io.File(filePath);

    if (!await f.exists()) {
      throw io.FileSystemException('File not found', filePath);
    }

    final data = await f.readAsBytes();
    final decoded = await _decodeData(data);

    final json = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
    return File.fromJson(json);
  }

  /// 存储 Index
  Future<void> putIndex(Index index) async {
    if (index.id.isEmpty) {
      throw ArgumentError('Invalid index ID');
    }

    final filePath = _indexAbsPath(index.id);
    final f = io.File(filePath);

    // 确保目录存在
    await f.parent.create(recursive: true);

    // 序列化为 JSON
    final json = jsonEncode(index.toJson());
    final data = utf8.encode(json);

    // 索引只压缩不加密（与 dejavu 一致）
    final compressed = await compression.compress(Uint8List.fromList(data));

    // 安全写入文件
    await _writeFileSafer(filePath, compressed);
  }

  /// 获取 Index
  Future<Index> getIndex(String id) async {
    final filePath = _indexAbsPath(id);
    final f = io.File(filePath);

    if (!await f.exists()) {
      throw io.FileSystemException('Index not found', filePath);
    }

    final data = await f.readAsBytes();
    // 索引只压缩不加密
    final decompressed = await compression.decompress(data);

    final json = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
    return Index.fromJson(json);
  }

  /// 检查 Index 是否存在
  Future<bool> indexExists(String id) async {
    final filePath = _indexAbsPath(id);
    return await io.File(filePath).exists();
  }

  /// 编码数据（压缩 + 加密）
  Future<Uint8List> _encodeData(Uint8List data) async {
    // 先压缩
    final compressed = await compression.compress(data);
    // 再加密
    return await encryptAES(compressed, aesKey);
  }

  /// 解码数据（解密 + 解压）
  Future<Uint8List> _decodeData(Uint8List data) async {
    // 先解密
    final decrypted = await decryptAES(data, aesKey);
    // 再解压
    return await compression.decompress(decrypted);
  }

  /// 安全写入文件（先写入临时文件，然后重命名）
  Future<void> _writeFileSafer(String filePath, Uint8List data) async {
    final file = io.File(filePath);
    final tempPath = '$filePath.tmp';

    // 写入临时文件
    await io.File(tempPath).writeAsBytes(data);

    // 重命名为目标文件
    await io.File(tempPath).rename(filePath);
  }
}
