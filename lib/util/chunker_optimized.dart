import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'hash.dart';

/// 优化的分块器 - 使用固定分块 + Isolate 并发
class ChunkerOptimized {
  static const int minSize = 512 * 1024; // 512 KB
  static const int maxSize = 8 * 1024 * 1024; // 8 MB

  /// 对文件进行分块（使用 Isolate 处理大文件）
  static Future<List<ChunkInfo>> chunkFile(String filePath) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 小文件直接处理
    if (fileSize < 10 * 1024 * 1024) {
      return await _chunkFileSync(filePath);
    }

    // 大文件使用 Isolate 处理
    return await _chunkFileIsolate(filePath);
  }

  /// 同步分块（用于小文件）
  static Future<List<ChunkInfo>> _chunkFileSync(String filePath) async {
    final chunks = <ChunkInfo>[];
    final file = await File(filePath).open();

    try {
      int offset = 0;
      while (true) {
        final buffer = Uint8List(maxSize);
        await file.setPosition(offset);
        final bytesRead = await file.readInto(buffer);

        if (bytesRead == 0) break;

        final chunkData = buffer.sublist(0, bytesRead);
        final chunkHash = hash(chunkData);

        chunks.add(ChunkInfo(
          id: chunkHash,
          offset: offset,
          length: bytesRead,
        ));

        offset += bytesRead;
      }
    } finally {
      await file.close();
    }

    return chunks;
  }

  /// 使用 Isolate 分块（用于大文件）
  static Future<List<ChunkInfo>> _chunkFileIsolate(String filePath) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(_chunkWorker, [receivePort.sendPort, filePath]);

    final chunks = await receivePort.first as List<ChunkInfo>;
    return chunks;
  }

  /// Isolate 工作函数
  static void _chunkWorker(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final filePath = args[1] as String;

    try {
      final chunks = await _chunkFileSync(filePath);
      sendPort.send(chunks);
    } catch (e) {
      sendPort.send(<ChunkInfo>[]);
    }
  }
}

/// 块信息
class ChunkInfo {
  final String id;
  final int offset;
  final int length;

  ChunkInfo({
    required this.id,
    required this.offset,
    required this.length,
  });
}
