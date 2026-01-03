#!/bin/bash

set -e

echo "Building chunker-ffi for multiple platforms..."
echo ""

# Create native library directory
NATIVE_DIR="../lib/native"
mkdir -p "$NATIVE_DIR"

# macOS
echo "Building for macOS (arm64 and x86_64)..."
GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_darwin_arm64.dylib chunker.go
GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_darwin_amd64.dylib chunker.go

# Create universal binary for macOS
lipo -create libchunker_darwin_arm64.dylib libchunker_darwin_amd64.dylib -output libchunker.dylib
rm libchunker_darwin_arm64.dylib libchunker_darwin_amd64.dylib libchunker_darwin_arm64.h libchunker_darwin_amd64.h 2>/dev/null || true
echo "✓ macOS: libchunker.dylib"

# Linux
echo "Building for Linux (x86_64 and arm64)..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_linux_amd64.so chunker.go 2>/dev/null || echo "  ⚠ Skipped Linux amd64 (requires cross-compiler)"
GOOS=linux GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_linux_arm64.so chunker.go 2>/dev/null || echo "  ⚠ Skipped Linux arm64 (requires cross-compiler)"
echo "✓ Linux: libchunker_linux_*.so (if cross-compiler available)"

# Windows
echo "Building for Windows..."
GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc go build -buildmode=c-shared -o libchunker.dll chunker.go 2>/dev/null || echo "  ⚠ Skipped (requires mingw-w64)"
echo "✓ Windows: libchunker.dll (if mingw-w64 available)"

# Android (if needed)
echo "Building for Android..."
GOOS=android GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_android_arm64.so chunker.go 2>/dev/null || echo "  ⚠ Skipped (requires Android NDK)"
GOOS=android GOARCH=amd64 CGO_ENABLED=1 go build -buildmode=c-shared -o libchunker_android_amd64.so chunker.go 2>/dev/null || echo "  ⚠ Skipped (requires Android NDK)"
echo "✓ Android: libchunker_android_*.so (if NDK available)"

# iOS (if needed - requires special setup)
# echo "Building for iOS..."
# GOOS=ios GOARCH=arm64 go build -buildmode=c-archive -o libchunker.a chunker.go
# echo "✓ iOS: libchunker.a"

echo ""
echo "Moving libraries to $NATIVE_DIR..."
[ -f libchunker.dylib ] && mv libchunker.dylib "$NATIVE_DIR/" || echo "  ⚠ macOS library not found"
[ -f libchunker_linux_amd64.so ] && mv libchunker_linux_amd64.so "$NATIVE_DIR/" || echo "  ⚠ Linux amd64 library not found"
[ -f libchunker_linux_arm64.so ] && mv libchunker_linux_arm64.so "$NATIVE_DIR/" || echo "  ⚠ Linux arm64 library not found"
[ -f libchunker.dll ] && mv libchunker.dll "$NATIVE_DIR/" || echo "  ⚠ Windows library not found"
[ -f libchunker_android_arm64.so ] && mv libchunker_android_arm64.so "$NATIVE_DIR/" || echo "  ⚠ Android arm64 library not found"
[ -f libchunker_android_amd64.so ] && mv libchunker_android_amd64.so "$NATIVE_DIR/" || echo "  ⚠ Android amd64 library not found"

# Clean up header files (we only need the libraries)
rm -f *.h

echo ""
echo "Build complete! Libraries installed in $NATIVE_DIR:"
ls -lh "$NATIVE_DIR"/libchunker* 2>/dev/null | awk '{print "  " $9, $5}'

echo ""
echo "Done! The Dart FFI bindings will automatically use these libraries."

