import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Type definitions for FFI functions
typedef ChunkerNewNative = ffi.Int32 Function(ffi.Pointer<Utf8>);
typedef ChunkerNewDart = int Function(ffi.Pointer<Utf8>);

typedef ChunkerNextNative = ffi.Int32 Function(
    ffi.Int32, ffi.Pointer<ffi.Uint8>, ffi.Int32);
typedef ChunkerNextDart = int Function(int, ffi.Pointer<ffi.Uint8>, int);

typedef ChunkerCloseNative = ffi.Void Function(ffi.Int32);
typedef ChunkerCloseDart = void Function(int);

typedef ChunkerGetSizeNative = ffi.Int32 Function();
typedef ChunkerGetSizeDart = int Function();

/// FFI bindings for restic/chunker
class ChunkerFFI {
  static ffi.DynamicLibrary? _dylib;
  static int? _minSize;
  static int? _maxSize;

  static ffi.DynamicLibrary _loadLibrary() {
    if (_dylib != null) return _dylib!;

    try {
      // Get the library path relative to the package root
      // The native libraries are stored in lib/native/
      final packageRoot = _getPackageRoot();

      if (Platform.isMacOS) {
        final libPath = '$packageRoot/lib/native/libchunker.dylib';
        _dylib = ffi.DynamicLibrary.open(libPath);
      } else if (Platform.isLinux) {
        final libPath =
            '$packageRoot/lib/native/libchunker_linux_${_getArch()}.so';
        _dylib = ffi.DynamicLibrary.open(libPath);
      } else if (Platform.isWindows) {
        final libPath = '$packageRoot/lib/native/libchunker.dll';
        _dylib = ffi.DynamicLibrary.open(libPath);
      } else if (Platform.isAndroid) {
        // For Android, libraries should be bundled with the app
        _dylib = ffi.DynamicLibrary.open('libchunker_android_${_getArch()}.so');
      } else {
        throw UnsupportedError(
            'Platform not supported: ${Platform.operatingSystem}');
      }
    } catch (e) {
      throw Exception(
          'Failed to load chunker library: $e. Make sure to build it first using chunker-ffi/build.sh');
    }

    return _dylib!;
  }

  static String _getPackageRoot() {
    // Get the current script's directory and navigate to package root
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = Directory(scriptPath).parent;

    // When running from bin/, test/, or lib/, navigate up to package root
    var current = scriptDir;
    while (current.path != current.parent.path) {
      // Check if we're at the package root by looking for pubspec.yaml
      if (File('${current.path}/pubspec.yaml').existsSync()) {
        return current.path;
      }
      current = current.parent;
    }

    // Fallback: assume we're already at the root
    return Directory.current.path;
  }

  static String _getArch() {
    if (ffi.Abi.current() == ffi.Abi.macosArm64 ||
        ffi.Abi.current() == ffi.Abi.linuxArm64) {
      return 'arm64';
    }
    return 'amd64';
  }

  late final ChunkerNewDart _chunkerNew;
  late final ChunkerNextDart _chunkerNext;
  late final ChunkerCloseDart _chunkerClose;
  late final ChunkerGetSizeDart _chunkerGetMinSize;
  late final ChunkerGetSizeDart _chunkerGetMaxSize;

  ChunkerFFI() {
    final dylib = _loadLibrary();

    _chunkerNew =
        dylib.lookupFunction<ChunkerNewNative, ChunkerNewDart>('ChunkerNew');
    _chunkerNext =
        dylib.lookupFunction<ChunkerNextNative, ChunkerNextDart>('ChunkerNext');
    _chunkerClose = dylib
        .lookupFunction<ChunkerCloseNative, ChunkerCloseDart>('ChunkerClose');
    _chunkerGetMinSize =
        dylib.lookupFunction<ChunkerGetSizeNative, ChunkerGetSizeDart>(
            'ChunkerGetMinSize');
    _chunkerGetMaxSize =
        dylib.lookupFunction<ChunkerGetSizeNative, ChunkerGetSizeDart>(
            'ChunkerGetMaxSize');
  }

  /// Create a new chunker for the given file path
  int chunkerNew(String filePath) {
    final pathPtr = filePath.toNativeUtf8();
    try {
      final handle = _chunkerNew(pathPtr);
      if (handle == 0) {
        throw Exception('Failed to create chunker for $filePath');
      }
      return handle;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get next chunk from the chunker
  /// Returns chunk data, or null if EOF
  Uint8List? chunkerNext(int handle) {
    final maxSize = getMaxSize();
    final bufferPtr = malloc.allocate<ffi.Uint8>(maxSize);

    try {
      final size = _chunkerNext(handle, bufferPtr, maxSize);

      if (size == 0) return null; // EOF
      if (size < 0) throw Exception('Chunker error');

      // Copy data from C buffer to Dart
      return Uint8List.fromList(bufferPtr.asTypedList(size));
    } finally {
      malloc.free(bufferPtr);
    }
  }

  /// Close the chunker
  void chunkerClose(int handle) {
    _chunkerClose(handle);
  }

  /// Get minimum chunk size
  int getMinSize() {
    _minSize ??= _chunkerGetMinSize();
    return _minSize!;
  }

  /// Get maximum chunk size
  int getMaxSize() {
    _maxSize ??= _chunkerGetMaxSize();
    return _maxSize!;
  }
}
