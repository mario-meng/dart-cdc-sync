# Flow Repo

🚀 **Production-ready data snapshot and incremental sync system for Dart/Flutter with Content-Defined Chunking (CDC)**

[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-AGPL%203.0-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Android-lightgrey.svg)](https://dart.dev)

**Language**: [English](README.md) | [中文](README.zh.md)

---

## Overview

**Flow Repo** is a production-ready data snapshot and incremental sync system for Dart/Flutter applications, featuring **Content-Defined Chunking (CDC)** via Go FFI integration. It's the first open-source project in the Dart ecosystem to implement CDC chunking through Foreign Function Interface, bringing native Go performance to Dart applications.

### Key Features

- **🔬 Content-Defined Chunking (CDC)**: Intelligent chunking algorithm that adapts to data content, achieving 99%+ bandwidth savings for file insertions/deletions
- **🌐 Cross-Platform FFI**: Seamless integration with Go's battle-tested [restic/chunker](https://github.com/restic/chunker) library via FFI, supporting macOS, Linux, Windows, and Android
- **⚡ High Performance**: Native Go performance with zero overhead, outperforming pure Dart implementations in chunking operations
- **🔐 End-to-End Encryption**: AES-256 encryption ensures zero-knowledge cloud storage
- **📦 Content Deduplication**: SHA-1 based content addressing for automatic deduplication
- **🔄 Incremental Sync**: Smart change detection with 98%+ bandwidth savings
- **☁️ Cloud Storage**: S3-compatible storage support (AWS S3, Qiniu Cloud, Alibaba Cloud OSS)
- **💰 Zero Server Cost**: No server-side computation or database required - only uses cheap object storage (S3/OSS), making it the most cost-effective and efficient universal sync solution

### Why Flow Repo?

Unlike traditional fixed-size chunking, CDC determines chunk boundaries based on data content rather than fixed positions. This means when you insert or delete data in the middle of a file, only the affected chunks need to be re-synced, not the entire file. Flow Repo makes this powerful algorithm accessible to the Dart/Flutter ecosystem through a clean FFI interface.

**Perfect for**: Flutter apps requiring efficient data backup, multi-device sync, or cloud storage with minimal bandwidth usage.

### 💰 Zero Server Cost Architecture

**Flow Repo requires no server-side computation or database storage** - it only uses cheap object storage services (S3/OSS). This makes it the **most cost-effective and efficient universal sync solution**:

- **No Server Required**: All computation happens on the client side
- **No Database Needed**: Metadata is stored in the object storage itself
- **Ultra-Low Cost**: Only pay for object storage (typically $0.023/GB/month for S3)
- **Universal Compatibility**: Works with any S3-compatible storage provider
- **Maximum Efficiency**: Direct object storage access, no intermediate layers

---

## 💡 Project Highlights

### 🔥 Content-Defined Chunking (CDC) - Core Feature

**Flow Repo is the first data sync system in the Dart ecosystem to implement CDC chunking via Go FFI**

#### What is CDC?

Content-Defined Chunking (CDC) is an intelligent chunking algorithm that determines chunk boundaries based on **data content** rather than fixed positions. This means when you insert or delete data in the middle of a file, only the affected parts need to be re-synced, not the entire file.

#### Why Choose CDC?

| Scenario | Fixed Chunking | CDC Chunking |
|----------|---------------|--------------|
| **File Append** | ✅ Excellent | ✅ Excellent |
| **File Insert** | ❌ Boundary shift, massive retransmission | ✅ Only affects nearby chunks |
| **File Delete** | ❌ All subsequent chunks retransmitted | ✅ Only affects nearby chunks |
| **File Modify** | ⚠️ Depends on modification position | ✅ Content-aware, more precise |

#### Technical Implementation

**Based on the battle-tested [restic/chunker](https://github.com/restic/chunker) algorithm**

```
┌─────────────────────────────────────────────────────────────┐
│                    CDC Chunking Workflow                      │
│                                                               │
│  File Stream → Rabin Fingerprint Sliding Window → Detect     │
│                Boundaries → Output Chunks                      │
│                ↓                                               │
│         Polynomial: 0x3DA3358B4DC173                          │
│         Min Chunk: 512KB                                      │
│         Max Chunk: 8MB                                        │
└─────────────────────────────────────────────────────────────┘
```

**Algorithm Principles**:
- **Rabin Fingerprint**: Uses rolling hash algorithm to compute fingerprints in a sliding window over the data stream
- **Boundary Detection**: Determines chunk boundaries when fingerprint values meet specific conditions (e.g., modulo result matches)
- **Dynamic Chunk Size**: Chunk size dynamically adjusts between 512KB ~ 8MB, ensuring stable boundaries

#### Cross-Platform FFI Architecture

**First open-source project in Dart to implement CDC via Go FFI**

```
┌─────────────────┐
│   Dart Layer    │  ← Flutter/Dart Applications
├─────────────────┤
│  FFI Bindings   │  ← dart:ffi cross-platform bindings
├─────────────────┤
│   Go Library    │  ← restic/chunker (C-shared)
├─────────────────┤
│  Native Binary  │  ← .dylib / .so / .dll
└─────────────────┘
```

**Multi-Platform Support**:
- ✅ **macOS**: Universal Binary (ARM64 + AMD64)
- ✅ **Linux**: AMD64 + ARM64
- ✅ **Windows**: AMD64
- ✅ **Android**: ARM64 + x86_64

**Technical Features**:
- 🔧 Automated build scripts (`build.sh`)
- 🎯 Dynamic library loading with automatic platform/architecture detection
- 📦 Zero runtime dependencies (pre-compiled libraries)
- 🔒 Type-safe FFI bindings
- ⚡ Native Go performance with zero overhead

#### CDC Performance Advantages

**Test Scenario**: Insert 1 record in the middle of a 273MB SQLite database

| Chunking Strategy | Transfer Size | Savings | Notes |
|-------------------|---------------|---------|-------|
| **CDC (FFI)** | **~1MB** | **99.6%** ⭐️ | Only transfers chunks near insertion point |
| Fixed Chunking | 5.25MB | 98.08% | Boundary shift causes more retransmission |
| Full Transfer | 273MB | 0% | No incremental sync |

**Why CDC is Better?**
- When inserting/deleting in the middle of a file, fixed chunking boundaries shift entirely, requiring all subsequent chunks to be retransmitted
- CDC boundaries are content-based, so insertions/deletions only affect local areas, other chunks remain unchanged

### 🛠️ Other Chunking Strategies

Flow Repo also supports two additional chunking strategies for different scenarios:

#### Fixed-Size Chunking - Simple and Efficient
- **Chunk Size**: 8MB fixed chunks
- **Advantages**: 
  - Simple implementation, no external dependencies
  - Stable boundaries, excellent for append scenarios
  - Achieves **98%+** bandwidth savings in practice
- **Best For**: Frequently appended data (e.g., log files, SQLite databases)

#### Optimized Chunking - Isolate Concurrency
- **Technology**: Dart Isolate multi-core concurrent processing
- **Strategy**: 
  - Small files (<10MB): Single-threaded processing
  - Large files (≥10MB): Isolate concurrent chunking
- **Advantage**: Fully utilizes multi-core CPU, significant performance improvement for large files

### 🎯 Performance Benchmarks

#### Incremental Sync Test

**Test Scenario**: Add 1 record to a 273MB SQLite database

| Metric | Value | Savings |
|--------|-------|---------|
| **Upload Traffic** | **5.25MB** | 98.08% ⬇️ |
| **Download Traffic** | **5.25MB** | 98.08% ⬇️ |
| **Index Creation** | 1.94s | - |
| **End-to-End Sync** | 7-9s | - |
| **Data Consistency** | 100% | ✅ |

#### Comparison with Go Version

| Metric | Dart (Flow Repo) | Go (DejaVu) | Notes |
|--------|------------------|-------------|-------|
| Incremental Traffic | 5.25MB | 981KB | Go CDC is better |
| Sync Speed | 16.25s | 9.08s | Go is faster |
| **Index Creation** | **1.94s** | 3.37s | **Dart 42% faster** ⭐️ |
| Platform Support | Dart/Flutter all platforms | Go server-side | Dart ecosystem advantage |

### 🔐 Enterprise-Grade Security

```
Raw Data → Chunking → SHA-1 Hash → ZLib Compression → AES-256 Encryption → Cloud Storage
   ↓                                                                    ↓
100% Content Deduplication                                    Cloud Cannot Decrypt
```

- **Encryption Algorithm**: AES-256-CBC
- **Key Management**: Local keys, zero-knowledge cloud
- **Content Addressing**: SHA-1 hash, automatic deduplication
- **Compression Ratio**: Average 40-60% (depends on data type)

---

## 🚀 Quick Start

### Installation

```bash
# 1. Clone repository
git clone git@github.com:Mario-Meng/dart-cdc-sync.git
cd dart-cdc-sync

# 2. Install dependencies
dart pub get

# 3. (Optional) Build FFI chunking library for CDC
cd chunker-ffi
./build.sh
cd ..
```

### Configuration

Copy `.env.demo` to `.env` and update with your actual values:

```bash
cp .env.demo .env
# Then edit .env with your actual configuration
```

The `.env` file should contain:

```env
# Encryption key (32 bytes)
AES_KEY=your_32_byte_aes_key_here_12345

# S3-compatible cloud storage (required for sync)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=your_bucket_name
S3_ENDPOINT=s3.amazonaws.com
S3_REGION=us-east-1
```

**Cloud Storage Compatibility**:
- ✅ **AWS S3** - Fully supported, recommended
- ✅ **Qiniu Cloud** - Fully supported, recommended
- ⚠️ **Alibaba Cloud OSS** - Supported but slower sync (does not support ListObjects, requires traversing all objects)

**Note**: Alibaba Cloud OSS lacks ListObjects support, which means sync operations need to traverse all objects, resulting in slower performance. We recommend using AWS S3 or Qiniu Cloud for better performance.

### Simple Usage

**Note**: All paths (`data-path`, `repo-path`, `remote-path`) must be specified by the user.

#### Create Index

```bash
# Create a snapshot index
dart run bin/main.dart index -d ./data -r ./.flow-repo -p remote/path --memo "Initial backup"
```

#### Sync to Cloud

```bash
# Sync to cloud (automatically detects upload/download direction)
dart run bin/main.dart sync -d ./data -r ./.flow-repo -p remote/path
```

#### Sync to Another Device

```bash
# Sync to a new device (use different local repo path)
dart run bin/main.dart sync -d ./data-device2 -r ./.flow-repo-device2 -p remote/path
```

### Programmatic Usage

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flow_repo/flow_repo.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  // Load environment variables
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  
  // Get AES key
  final aesKeyStr = env['AES_KEY'] ?? '12345678901234567890123456789012';
  final aesKey = Uint8List.fromList(aesKeyStr.codeUnits.take(32).toList());
  
  // Configure cloud storage (optional, only needed for sync)
  final cloud = S3Cloud(
    endpoint: 'https://s3.amazonaws.com',
    accessKey: env['AWS_ACCESS_KEY_ID']!,
    secretKey: env['AWS_SECRET_ACCESS_KEY']!,
    bucket: env['S3_BUCKET']!,
    region: env['S3_REGION']!,
    availableSize: 100 * 1024 * 1024 * 1024, // 100GB
  );
  
  // Create repository
  final repo = await Repo.create(
    dataPath: './data',
    repoPath: './.flow-repo',
    deviceID: 'device-001',
    deviceName: 'My Device',
    deviceOS: Platform.operatingSystem,
    aesKey: aesKey,
    cloud: cloud,
    remotePath: 'remote/path', // Remote storage path
  );
  
  // Create index
  final index = await repo.index('My backup');
  print('Index created: ${index.id}');
  
  // Sync to cloud
  final result = await repo.sync();
  print('Upload: ${result.uploadBytes} bytes');
  print('Download: ${result.downloadBytes} bytes');
}
```

---

## 🏗️ Technical Architecture

### Chunking Engine Comparison

| Feature | **CDC (FFI)** ⭐️ | Fixed Chunking | Optimized Chunking |
|---------|------------------|----------------|-------------------|
| **Language** | Go (FFI) | Dart | Dart |
| **Chunk Size** | 512KB-8MB dynamic | 8MB fixed | 8MB fixed |
| **Complexity** | O(n) | O(n) | O(n) |
| **Concurrency** | ✅ (Go native) | ❌ | ✅ (Isolate) |
| **Incremental Effect** | **Better (99%+)** ⭐️ | Excellent (98%+) | Excellent (98%+) |
| **Use Case** | **Insert/Delete scenarios** ⭐️ | Append databases | Large files |
| **Boundary Stability** | **Content-aware** ⭐️ | Position fixed | Position fixed |
| **Dependencies** | Requires .dylib/.so | None | None |
| **Recommended** | **General use** ⭐️ | Simple scenarios | Large file scenarios |

### Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    Index Creation Phase                       │
│                                                                │
│  File Scan → Chunking Engine → SHA-1 Hash → Index Build →    │
│              Compressed Storage                                │
│              ↓                                                 │
│         Fixed / CDC / Optimized                                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                        Sync Phase                              │
│                                                                │
│  Compare Index → Missing Chunks → ZLib Compression → AES-256   │
│  Encryption → Cloud Upload                                     │
│      ↓                                                         │
│  Auto Deduplication (SHA-1 Content Addressing)               │
└──────────────────────────────────────────────────────────────┘
```

### Repository Structure

```
.flow-repo/
├── indexes/          # 📋 Snapshot indexes (compressed only)
│   └── <sha1-id>
├── objects/          # 📦 Data chunks (compressed + encrypted)
│   └── <2-char>/
│       └── <sha1-id>
├── files/            # 📄 File metadata (compressed + encrypted)
│   └── <2-char>/
│       └── <sha1-id>
└── refs/             # 🔖 References
    └── latest        # Latest snapshot reference
```

---

## 🔬 CDC Chunking Engine Details

### Quick Start with CDC

#### 1. Build FFI Chunking Library

```bash
cd chunker-ffi
./build.sh
```

**Build Output**:
- macOS: `lib/native/libchunker.dylib` (Universal Binary)
- Linux: `lib/native/libchunker_linux_{amd64,arm64}.so`
- Windows: `lib/native/libchunker.dll`
- Android: `lib/native/libchunker_android_{arm64,amd64}.so`

**Detailed Documentation**: See [`chunker-ffi/BUILD_GUIDE.md`](chunker-ffi/BUILD_GUIDE.md)

#### 2. Use CDC Chunking in Dart

```dart
import 'package:flow_repo/util/chunker_ffi.dart';

// Create CDC chunker
final chunker = ChunkerFFI();
final handle = chunker.chunkerNew('/path/to/file');

// Get chunking parameters
print('Min chunk size: ${chunker.getMinSize()}');  // 512KB
print('Max chunk size: ${chunker.getMaxSize()}');  // 8MB

// Iterate through all chunks
while (true) {
  final chunk = chunker.chunkerNext(handle);
  if (chunk == null) break; // EOF
  
  // Process chunk data
  print('Chunk size: ${chunk.length} bytes');
  // Calculate chunk hash for deduplication
  final hash = sha1(chunk);
  // Store or upload chunk...
}

// Release resources
chunker.chunkerClose(handle);
```

#### 3. CDC vs Fixed Chunking Example

**Scenario**: Insert 1MB data in the middle of a 100MB file

```
Fixed Chunking (8MB):
[Chunk1: 8MB] [Chunk2: 8MB] [Chunk3: 8MB] ... [Chunk12: 8MB] [Chunk13: 4MB]
         ↓ Insert 1MB data ↓
[Chunk1: 8MB] [Chunk2: 8MB] [New: 1MB] [Chunk3: 8MB] ... [Chunk13: 4MB]
         ↑ Chunks 3-13 all need retransmission ↑
Need to transfer: ~92MB (Chunk2 second half + New + Chunks 3-13)

CDC Chunking:
[Chunk1] [Chunk2] [Chunk3] ... [ChunkN]
         ↓ Insert 1MB data ↓
[Chunk1] [Chunk2] [New: 1MB] [Chunk3] ... [ChunkN]
         ↑ Only affects nearby area ↑
Need to transfer: ~2-3MB (Chunk2 second half + New + Chunk3 first half)
```

### Other Chunking Strategies

#### Isolate Concurrent Chunking

```dart
import 'package:flow_repo/util/chunker_optimized.dart';

// Automatically chooses concurrency strategy based on file size
final chunks = await ChunkerOptimized.chunkFile('/path/to/large/file');

for (final chunk in chunks) {
  print('Chunk ID: ${chunk.id}, Size: ${chunk.length}');
}
```

---

## 🌟 Core Features

- ✅ **CDC Chunking Engine** - Content-defined chunking, 99%+ bandwidth savings ⭐️
- ✅ **Cross-Platform FFI** - Go native performance, seamless Dart integration
- ✅ **Multi-Strategy Support** - CDC / Fixed / Isolate concurrency
- ✅ **Incremental Sync** - Smart change detection, only transfer differences
- ✅ **End-to-End Encryption** - AES-256, zero-knowledge cloud
- ✅ **Content Deduplication** - SHA-1 hash, automatic deduplication
- ✅ **Data Compression** - ZLib efficient compression
- ✅ **Bidirectional Sync** - Automatically detects upload/download direction
- ✅ **Cloud Backup** - S3-compatible storage (Alibaba Cloud OSS)
- ✅ **Concurrency Control** - Prevents cloud API overload
- ✅ **Integrity Verification** - 100% data consistency guarantee

---

## 📚 Documentation

- 📖 [Build Guide](chunker-ffi/BUILD_GUIDE.md) - FFI library build details
- 📝 [Contributing Guide](CONTRIBUTING.md) - How to contribute
- 📋 [Changelog](CHANGELOG.md) - Version history

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit Issues and Pull Requests.

Before submitting code, please ensure:
1. Run `dart format .`
2. Run `dart analyze` with no errors
3. Tests pass
4. Follow [Conventional Commits](https://www.conventionalcommits.org/)

---

## 📄 License

**AGPL-3.0**

This project is licensed under AGPL-3.0, which requires modified versions to also be open source.

---

## 🙏 Acknowledgments

- [DejaVu](https://github.com/siyuan-note/dejavu) - Original design and inspiration
- [restic/chunker](https://github.com/restic/chunker) - Battle-tested CDC algorithm
- [Dart FFI](https://dart.dev/guides/libraries/c-interop) - Powerful cross-language interop

---

## 📊 Project Status

| Metric | Status |
|--------|--------|
| **Version** | 1.0.0 |
| **Status** | ✅ Production Ready |
| **Dart SDK** | ≥ 3.0.0 |
| **Platform Support** | macOS / Linux / Windows / Android |
| **Last Update** | 2026-01-04 |

---

<p align="center">
  Made with ❤️ by Flow Repo Team
</p>
