# Chunker FFI Build Guide

This guide explains how to build the native chunker library for different platforms.

## Quick Start (macOS)

If you're on macOS, simply run:

```bash
cd chunker-ffi
./build.sh
```

This will:
1. Build a universal macOS library (arm64 + amd64)
2. Automatically move it to `lib/native/`
3. The library will be ready to use

## Platform-Specific Instructions

### macOS

**Requirements:**
- Go 1.24+
- Xcode Command Line Tools

**Build:**
```bash
cd chunker-ffi
./build.sh
```

**Output:**
- `lib/native/libchunker.dylib` (universal binary)

### Linux

**Requirements:**
- Go 1.24+
- GCC

**Build on Linux:**
```bash
cd chunker-ffi
GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_linux_amd64.so chunker.go
# For ARM64
GOOS=linux GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_linux_arm64.so chunker.go

# Move to lib/native/
mkdir -p ../lib/native
mv libchunker_linux_*.so ../lib/native/
rm -f *.h
```

**Note:** Cross-compiling from macOS to Linux requires a Linux cross-compiler toolchain, which is not included by default.

### Windows

**Requirements:**
- Go 1.24+
- MinGW-w64 (for cross-compilation)

**Build on Windows:**
```bash
cd chunker-ffi
go build -buildmode=c-shared -o libchunker.dll chunker.go
move libchunker.dll ..\lib\native\
del *.h
```

**Cross-compile from macOS/Linux:**
```bash
# Install mingw-w64 first
# macOS: brew install mingw-w64
# Linux: apt-get install mingw-w64

cd chunker-ffi
GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc go build -buildmode=c-shared -o libchunker.dll chunker.go
mkdir -p ../lib/native
mv libchunker.dll ../lib/native/
rm -f *.h
```

### Android

**Requirements:**
- Go 1.24+
- Android NDK

**Build:**
```bash
# Set up Android NDK
export ANDROID_NDK_HOME=/path/to/android-ndk

cd chunker-ffi

# ARM64
GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
  CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang \
  go build -buildmode=c-shared -o libchunker_android_arm64.so chunker.go

# x86_64 (for emulator)
GOOS=android GOARCH=amd64 CGO_ENABLED=1 \
  CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/x86_64-linux-android21-clang \
  go build -buildmode=c-shared -o libchunker_android_amd64.so chunker.go

# Move to lib/native/
mkdir -p ../lib/native
mv libchunker_android_*.so ../lib/native/
rm -f *.h
```

## Verification

After building, verify the library works:

```bash
cd ..
dart run -e "import 'lib/util/chunker_ffi.dart'; void main() { final c = ChunkerFFI(); print('Min: \${c.getMinSize()}, Max: \${c.getMaxSize()}'); }"
```

Expected output:
```
Min: 524288, Max: 8388608
```

## Directory Structure

After building, your project should look like:

```
flow-repo/
├── chunker-ffi/
│   ├── README.md          # API documentation
│   ├── BUILD_GUIDE.md     # This file
│   ├── build.sh           # Build script
│   ├── chunker.go         # Go source
│   ├── go.mod
│   └── go.sum
├── lib/
│   ├── native/            # Native libraries (gitignored)
│   │   ├── libchunker.dylib                 # macOS
│   │   ├── libchunker_linux_amd64.so        # Linux x64
│   │   ├── libchunker_linux_arm64.so        # Linux ARM64
│   │   ├── libchunker.dll                   # Windows
│   │   ├── libchunker_android_arm64.so      # Android ARM64
│   │   └── libchunker_android_amd64.so      # Android x64
│   └── util/
│       └── chunker_ffi.dart                  # Dart FFI bindings
...
```

## Troubleshooting

### Library not found

**Error:**
```
Failed to load dynamic library '/path/to/libchunker.dylib': dlopen(...) no such file
```

**Solution:**
1. Make sure you've run `./build.sh`
2. Check that the library exists in `lib/native/`
3. Verify you're on the correct platform

### Go module errors

**Error:**
```
package github.com/restic/chunker is not in GOROOT
```

**Solution:**
```bash
cd chunker-ffi
go mod download
```

### Cross-compilation errors

**Error:**
```
# runtime/cgo
linux_syscall.c:67:13: error: call to undeclared function 'setresgid'
```

**Solution:**
This is expected when cross-compiling without the proper toolchain. Build on the target platform instead, or install the cross-compiler toolchain.

## CI/CD Integration

For continuous integration, you can build on multiple platforms:

**GitHub Actions example:**

```yaml
jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.24'
      - run: cd chunker-ffi && ./build.sh
      - uses: actions/upload-artifact@v3
        with:
          name: libchunker-macos
          path: lib/native/libchunker.dylib

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.24'
      - run: cd chunker-ffi && ./build.sh
      - uses: actions/upload-artifact@v3
        with:
          name: libchunker-linux
          path: lib/native/libchunker_linux_*.so

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.24'
      - run: cd chunker-ffi && go build -buildmode=c-shared -o libchunker.dll chunker.go
      - run: mkdir -p lib/native && move libchunker.dll lib/native/
      - uses: actions/upload-artifact@v3
        with:
          name: libchunker-windows
          path: lib/native/libchunker.dll
```

## License

This FFI wrapper is part of the Flow Repo project. The underlying chunker library is from [restic/chunker](https://github.com/restic/chunker).

