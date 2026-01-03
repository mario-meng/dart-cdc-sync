import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Compression utility class
///
/// Note: DejaVu uses Zstd, but Zstd support in Dart is limited
/// Using ZLib compression for better compatibility
class Compression {
  /// Compress data using ZLib
  Future<Uint8List> compress(Uint8List data) async {
    final encoder = ZLibEncoder();
    return Uint8List.fromList(encoder.encode(data));
  }

  /// Decompress data using ZLib
  Future<Uint8List> decompress(Uint8List data) async {
    final decoder = ZLibDecoder();
    return Uint8List.fromList(decoder.decodeBytes(data));
  }
}
