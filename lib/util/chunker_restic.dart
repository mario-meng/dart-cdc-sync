import 'dart:typed_data';
import 'chunker_ffi.dart';
import 'hash.dart';
import '../entity/chunk.dart';

/// Restic-based chunker using FFI
/// 
/// This uses the mature restic/chunker implementation via FFI
/// for better incremental sync performance
class ResticChunker {
  final String filePath;
  final ChunkerFFI _ffi;
  int? _handle;

  ResticChunker(this.filePath) : _ffi = ChunkerFFI();

  /// Initialize the chunker
  Future<void> init() async {
    _handle = _ffi.chunkerNew(filePath);
  }

  /// Get all chunks for the file
  Future<List<Chunk>> getChunks() async {
    if (_handle == null) {
      throw StateError('Chunker not initialized. Call init() first.');
    }

    final chunks = <Chunk>[];
    
    while (true) {
      final chunkData = _ffi.chunkerNext(_handle!);
      if (chunkData == null) break; // EOF
      
      final chunkHash = hash(chunkData);
      chunks.add(Chunk(id: chunkHash, data: chunkData));
    }
    
    return chunks;
  }

  /// Close the chunker
  void close() {
    if (_handle != null) {
      _ffi.chunkerClose(_handle!);
      _handle = null;
    }
  }

  /// Get minimum chunk size
  static int getMinSize() {
    return ChunkerFFI().getMinSize();
  }

  /// Get maximum chunk size
  static int getMaxSize() {
    return ChunkerFFI().getMaxSize();
  }
}

