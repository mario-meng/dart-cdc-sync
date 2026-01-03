# Chunker FFI Library

This directory contains the Go-based chunker FFI (Foreign Function Interface) implementation using [restic/chunker](https://github.com/restic/chunker) for content-defined chunking (CDC).

## Overview

The chunker library provides native performance CDC chunking by wrapping the battle-tested restic/chunker Go library. It exposes C-compatible functions that can be called from Dart via FFI.

## Prerequisites

- **Go 1.24+**: Required to build the shared library
- **GCC/Clang**: Required for cross-compilation
- **lipo** (macOS only): For creating universal binaries

### Install Go

```bash
# macOS
brew install go

# Linux
sudo apt-get install golang-go  # Debian/Ubuntu
sudo yum install golang          # RHEL/CentOS

# Or download from: https://golang.org/dl/
```

## Building

### Quick Build (Current Platform Only)

```bash
cd chunker-ffi
./build.sh
```

This will build libraries for all supported platforms:
- **macOS**: `libchunker.dylib` (universal binary: arm64 + amd64)
- **Linux**: `libchunker_linux_amd64.so`, `libchunker_linux_arm64.so`
- **Windows**: `libchunker.dll`
- **Android**: `libchunker_android_arm64.so`, `libchunker_android_amd64.so`

### Build for Specific Platform

```bash
# macOS (arm64)
GOOS=darwin GOARCH=arm64 go build -buildmode=c-shared -o libchunker_darwin_arm64.dylib chunker.go

# macOS (amd64)
GOOS=darwin GOARCH=amd64 go build -buildmode=c-shared -o libchunker_darwin_amd64.dylib chunker.go

# Linux (amd64)
GOOS=linux GOARCH=amd64 go build -buildmode=c-shared -o libchunker_linux_amd64.so chunker.go

# Linux (arm64)
GOOS=linux GOARCH=arm64 go build -buildmode=c-shared -o libchunker_linux_arm64.so chunker.go

# Windows (amd64)
GOOS=windows GOARCH=amd64 go build -buildmode=c-shared -o libchunker.dll chunker.go
```

### Create macOS Universal Binary

```bash
lipo -create libchunker_darwin_arm64.dylib libchunker_darwin_amd64.dylib -output libchunker.dylib
```

## Library Locations

After building, the libraries are automatically placed in `../lib/native/` directory:

```
lib/native/
├── libchunker.dylib                  # macOS universal binary
├── libchunker_linux_amd64.so         # Linux x86_64
├── libchunker_linux_arm64.so         # Linux ARM64
├── libchunker.dll                     # Windows
├── libchunker_android_arm64.so       # Android ARM64
└── libchunker_android_amd64.so       # Android x86_64
```

## API Reference

### Functions

#### ChunkerNew
```c
int ChunkerNew(const char* filePath);
```
Creates a new chunker for the given file path.
- **Parameters**: `filePath` - Path to the file to chunk
- **Returns**: Handle ID (>0) on success, 0 on error

#### ChunkerNext
```c
int ChunkerNext(int handle, char* buffer, int bufferSize);
```
Gets the next chunk from the chunker.
- **Parameters**: 
  - `handle` - Chunker handle from ChunkerNew
  - `buffer` - Buffer to store chunk data
  - `bufferSize` - Size of the buffer
- **Returns**: Chunk size (>0) on success, 0 on EOF, -1 on error

#### ChunkerClose
```c
void ChunkerClose(int handle);
```
Closes the chunker and frees resources.
- **Parameters**: `handle` - Chunker handle to close

#### ChunkerGetMinSize
```c
int ChunkerGetMinSize();
```
Returns the minimum chunk size (512KB).

#### ChunkerGetMaxSize
```c
int ChunkerGetMaxSize();
```
Returns the maximum chunk size (8MB).

## Chunking Parameters

- **Polynomial**: `0x3DA3358B4DC173` (same as DejaVu)
- **Min Size**: 512 KB
- **Max Size**: 8 MB

## Usage from Dart

The Dart FFI bindings are located in `lib/util/chunker_ffi.dart`. Example:

```dart
import 'package:dart_cdc_sync/util/chunker_ffi.dart';

final chunker = ChunkerFFI();
final handle = chunker.chunkerNew('/path/to/file');

while (true) {
  final chunk = chunker.chunkerNext(handle);
  if (chunk == null) break; // EOF
  
  // Process chunk data
  print('Chunk size: ${chunk.length}');
}

chunker.chunkerClose(handle);
```

## Troubleshooting

### Library Not Found

If you get "Failed to load dynamic library" error:
1. Make sure you've run `./build.sh` in the `chunker-ffi` directory
2. Check that the library file exists in `lib/native/`
3. Verify the library is built for your platform/architecture

### Build Errors

**"go: command not found"**
- Install Go: https://golang.org/dl/

**"package github.com/restic/chunker is not in GOROOT"**
- Run: `go mod download`

**"lipo: command not found" (macOS)**
- Install Xcode Command Line Tools: `xcode-select --install`

### Cross-Compilation Issues

**CGO is disabled**
- Set `CGO_ENABLED=1` environment variable

**Missing cross-compiler**
- Install appropriate GCC cross-compiler for target platform

## Development

### Dependencies

The library depends on:
- `github.com/restic/chunker v0.4.0`

Install dependencies:
```bash
go mod download
```

### Testing

Test the library before using in Dart:
```bash
# Build
./build.sh

# Verify build
file libchunker.dylib  # macOS
file libchunker_linux_amd64.so  # Linux
```

## License

This FFI wrapper is part of the Flow Repo project. The underlying chunker library is from [restic/chunker](https://github.com/restic/chunker).

## References

- [restic/chunker](https://github.com/restic/chunker) - The underlying CDC library
- [Dart FFI](https://dart.dev/guides/libraries/c-interop) - Dart Foreign Function Interface
- [Go shared libraries](https://golang.org/cmd/cgo/) - Building Go shared libraries

