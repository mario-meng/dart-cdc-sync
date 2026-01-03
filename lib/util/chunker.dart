import 'dart:io';
import 'dart:typed_data';

/// Content-Defined Chunking implementation
///
/// Based on restic/chunker using rolling hash algorithm
/// Uses fixed-size chunking for stability and performance
class Chunker {
  static const int minSize = 512 * 1024; // 512 KB
  static const int maxSize = 8 * 1024 * 1024; // 8 MB
  static const int polynomial = 0x3DA3358B4DC173; // Fixed polynomial value

  final RandomAccessFile file;
  final int polynomialValue;
  final int minChunkSize;
  final int maxChunkSize;

  int _pos = 0;
  int _windowPos = 0;
  int _buzHash = 0;
  final Uint8List _window = Uint8List(64);

  Chunker(
    this.file, {
    int? polynomialValue,
    int? minChunkSize,
    int? maxChunkSize,
  })  : polynomialValue = polynomialValue ?? polynomial,
        minChunkSize = minChunkSize ?? minSize,
        maxChunkSize = maxChunkSize ?? maxSize;

  int? _fileLength;

  /// Get file length (cached)
  Future<int> _getFileLength() async {
    if (_fileLength == null) {
      _fileLength = await file.length();
    }
    return _fileLength!;
  }

  /// Get next chunk
  ///
  /// Uses fixed-size chunking for better incremental sync performance
  /// This provides stable chunk boundaries for reliable deduplication
  Future<ChunkResult?> next() async {
    final fileLength = await _getFileLength();
    if (_pos >= fileLength) {
      return null;
    }

    // Calculate chunk size for this read
    final remaining = fileLength - _pos;
    final chunkSize = remaining > maxChunkSize ? maxChunkSize : remaining;

    // Read data
    await file.setPosition(_pos);
    final buffer = Uint8List(chunkSize);
    final read = await file.readInto(buffer, 0, chunkSize);

    if (read == 0) {
      return null;
    }

    _pos += read;

    // Return actual data read
    if (read < chunkSize) {
      return ChunkResult(data: buffer.sublist(0, read), length: read);
    }
    return ChunkResult(data: buffer, length: read);
  }

  void _resetHash() {
    _buzHash = 0;
    _windowPos = 0;
    _window.fillRange(0, _window.length, 0);
  }

  void _updateHash(int byte) {
    // 移除窗口中最旧的字节
    final oldByte = _window[_windowPos];
    _buzHash ^= _hashByte(oldByte, _window.length);

    // 添加新字节
    _window[_windowPos] = byte;
    _buzHash ^= _hashByte(byte, 0);

    // 更新窗口位置
    _windowPos = (_windowPos + 1) % _window.length;
  }

  int _hashByte(int byte, int offset) {
    if (offset == 0) {
      return byte;
    }
    // 简化实现：使用多项式值的幂
    var result = byte;
    for (int i = 0; i < offset; i++) {
      result = (result * polynomialValue) % (1 << 64);
    }
    return result;
  }

  Future<void> close() async {
    await file.close();
  }
}

/// Chunk result containing data and length
class ChunkResult {
  final Uint8List data;
  final int length;

  ChunkResult({required this.data, required this.length});
}
