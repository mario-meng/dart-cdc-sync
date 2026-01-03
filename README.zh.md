# Dart CDC Sync

🚀 **基于内容定义分块 (CDC) 的生产级 Dart 数据快照与增量同步系统**

[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-AGPL%203.0-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Android-lightgrey.svg)](https://dart.dev)

**语言**: [English](README.md) | [中文](README.zh.md)

---

## 项目简介

**Dart CDC Sync** 是一个生产级的数据快照与增量同步系统，专为 Dart/Flutter 应用设计，通过 Go FFI 集成实现了**内容定义分块 (CDC)**。这是 Dart 生态中首个通过 Foreign Function Interface 实现 CDC 分块的开源项目，为 Dart 应用带来了原生 Go 性能。

### 核心特性

- **🔬 内容定义分块 (CDC)**: 智能分块算法，根据数据内容自适应调整，在文件插入/删除场景下实现 99%+ 的流量节省
- **🌐 跨平台 FFI**: 通过 FFI 无缝集成久经考验的 Go [restic/chunker](https://github.com/restic/chunker) 库，支持 macOS、Linux、Windows 和 Android
- **⚡ 高性能**: 原生 Go 性能，零开销，在分块操作上优于纯 Dart 实现
- **🔐 端到端加密**: AES-256 加密确保云端零知识存储
- **📦 内容去重**: 基于 SHA-1 的内容寻址，自动去重
- **🔄 增量同步**: 智能变化检测，实现 98%+ 流量节省
- **☁️ 云存储**: S3 兼容存储支持（AWS S3、七牛云、阿里云 OSS）
- **💰 零服务器成本**: 无需服务器端计算和数据库存储 - 仅使用廉价的对象存储（S3/OSS），是最低成本最高效率的通用同步方案

### 为什么选择 Dart CDC Sync？

与传统固定大小分块不同，CDC 根据数据内容而非固定位置确定块边界。这意味着在文件中间插入或删除数据时，只需重新同步受影响的数据块，而不是整个文件。Dart CDC Sync 通过简洁的 FFI 接口，让 Dart/Flutter 生态能够使用这一强大的算法。

**适用于**: 需要高效数据备份、多设备同步或最小带宽使用的云存储的 Flutter 应用。

### 📱 适合手机客户端数据同步

Dart CDC Sync **非常适合手机客户端数据同步**（数据库、图片、视频等文件）到服务器端加密存储。它提供了一个**仅需存储费用**的经济高效解决方案，大大降低服务器开销：

- **手机数据库同步**: 高效同步 SQLite 数据库和其他本地数据文件，最小化带宽使用
- **媒体文件备份**: 无缝备份照片、视频和其他大文件，支持增量同步
- **加密存储**: 所有数据在上传前加密，确保隐私和安全
- **零服务器开销**: 无需服务器端计算、无需数据库维护、无需 API 服务器
- **超低成本**: 只需支付对象存储费用（通常为 $0.023/GB/月），无额外基础设施成本
- **自动去重**: 跨设备的相同文件只存储一次，节省存储空间

这使得 Dart CDC Sync 成为需要可靠、安全且经济高效的云备份和同步功能的移动应用的理想解决方案。

### 💰 零服务器成本架构

**Dart CDC Sync 无需服务器端计算和数据库存储** - 仅使用廉价的对象存储服务（S3/OSS）。这使其成为**最低成本最高效率的通用同步方案**：

- **无需服务器**: 所有计算都在客户端完成
- **无需数据库**: 元数据存储在对象存储本身中
- **超低成本**: 只需支付对象存储费用（S3 通常为 $0.023/GB/月）
- **通用兼容**: 支持任何 S3 兼容的存储提供商
- **最高效率**: 直接访问对象存储，无中间层

---

## 💡 项目亮点

### 🔥 内容定义分块 (Content-Defined Chunking, CDC) - 核心特性

**Dart CDC Sync 是首个在 Dart 生态中通过 Go FFI 实现 CDC 分块的数据同步系统**

#### 什么是 CDC？

内容定义分块 (CDC) 是一种智能分块算法，它根据**数据内容**而非固定位置来确定块边界。这使得在文件中间插入或删除数据时，只有受影响的部分需要重新同步，而不是整个文件。

#### 为什么选择 CDC？

| 场景 | 固定分块 | CDC 分块 |
|------|---------|---------|
| **文件追加** | ✅ 优秀 | ✅ 优秀 |
| **文件中间插入** | ❌ 块边界偏移，大量重传 | ✅ 只影响插入点附近 |
| **文件删除** | ❌ 后续块全部重传 | ✅ 只影响删除点附近 |
| **文件修改** | ⚠️ 取决于修改位置 | ✅ 内容感知，更精确 |

#### 技术实现

**基于久经考验的 [restic/chunker](https://github.com/restic/chunker) 算法**

```
┌─────────────────────────────────────────────────────────────┐
│                    CDC 分块工作流程                            │
│                                                               │
│  文件流 → Rabin Fingerprint 滑动窗口 → 检测块边界 → 输出块   │
│              ↓                                                │
│        多项式: 0x3DA3358B4DC173                               │
│        最小块: 512KB                                          │
│        最大块: 8MB                                            │
└─────────────────────────────────────────────────────────────┘
```

**算法原理**:
- **Rabin Fingerprint**: 使用滚动哈希算法，在数据流中滑动窗口计算指纹
- **块边界检测**: 当指纹值满足特定条件时（如模运算结果匹配），确定块边界
- **动态块大小**: 块大小在 512KB ~ 8MB 之间动态调整，确保块边界稳定

#### 跨平台 FFI 架构

**首个在 Dart 中使用 Go FFI 实现 CDC 的开源项目**

```
┌─────────────────┐
│   Dart Layer    │  ← Flutter/Dart 应用
├─────────────────┤
│  FFI Bindings   │  ← dart:ffi 跨平台绑定
├─────────────────┤
│   Go Library    │  ← restic/chunker (C-shared)
├─────────────────┤
│  Native Binary  │  ← .dylib / .so / .dll
└─────────────────┘
```

**多平台支持**:
- ✅ **macOS**: Universal Binary (ARM64 + AMD64)
- ✅ **Linux**: AMD64 + ARM64
- ✅ **Windows**: AMD64
- ✅ **Android**: ARM64 + x86_64

**技术特点**:
- 🔧 自动化构建脚本 (`build.sh`)
- 🎯 动态库加载，自动检测平台和架构
- 📦 零依赖运行时（库已预编译）
- 🔒 类型安全的 FFI 绑定
- ⚡ 原生 Go 性能，无性能损失

#### CDC 性能优势

**实测场景**: 273MB SQLite 数据库在中间插入 1 条记录

| 分块策略 | 传输流量 | 节省率 | 说明 |
|---------|---------|--------|------|
| **CDC (FFI)** | **~1MB** | **99.6%** ⭐️ | 只传输插入点附近的数据块 |
| 固定分块 | 5.25MB | 98.08% | 块边界偏移导致更多重传 |
| 全量传输 | 273MB | 0% | 无增量同步 |

**为什么 CDC 更优？**
- 文件中间插入/删除时，固定分块的边界会整体偏移，导致后续所有块都需要重传
- CDC 的块边界基于内容，插入/删除只影响局部，其他块保持不变

### 🛠️ 其他分块策略

Dart CDC Sync 还支持两种额外的分块策略，满足不同场景需求：

#### 固定分块 (Fixed-Size Chunking) - 简单高效
- **块大小**: 8MB 固定分块
- **优势**: 
  - 实现简单，无外部依赖
  - 块边界稳定，追加场景表现优秀
  - 实测节省 **98%+** 流量
- **适用**: 频繁追加的数据（如日志文件、SQLite 数据库）

#### 优化分块 (Optimized Chunking) - Isolate 并发
- **技术**: Dart Isolate 多核并发处理
- **策略**: 
  - 小文件 (<10MB): 单线程处理
  - 大文件 (≥10MB): Isolate 并发分块
- **优势**: 充分利用多核 CPU，处理大文件时性能提升显著

### 🎯 极致性能表现

#### 增量同步实测

**测试场景**: 273MB SQLite 数据库新增 1 条记录

| 指标 | 数值 | 节省率 |
|------|------|--------|
| **上传流量** | **5.25MB** | 98.08% ⬇️ |
| **下载流量** | **5.25MB** | 98.08% ⬇️ |
| **索引创建** | 1.94s | - |
| **端到端同步** | 7-9s | - |
| **数据一致性** | 100% | ✅ |

#### 与 Go 版本对比

| 项目 | Dart (Dart CDC Sync) | Go (DejaVu) | 备注 |
|------|---------------------|-------------|------|
| 增量流量 | **810KB** | 981KB | **Dart 更优** ⭐️ |
| 同步速度 | **0.67s** | 9.08s | **Dart 快 13.5倍** ⭐️ |
| **索引创建** | **1.94s** | 3.37s | **Dart 快 42%** ⭐️ |
| 平台支持 | Dart/Flutter 全平台 | Go 服务端 | Dart 生态优势 |

### 🔐 企业级数据安全

```
原始数据 → 分块 → SHA-1 哈希 → ZLib 压缩 → AES-256 加密 → 云端存储
   ↓                                                    ↓
100% 内容去重                                   云端无法解密
```

- **加密算法**: AES-256-CBC
- **密钥管理**: 本地密钥，云端零知识
- **内容寻址**: SHA-1 哈希，自动去重
- **压缩比**: 平均 40-60% (根据数据类型)

---

## 🚀 快速开始

### 安装

```bash
# 1. 克隆仓库
git clone git@github.com:Mario-Meng/dart-cdc-sync.git
cd dart-cdc-sync

# 2. 安装依赖
dart pub get

# 3. (可选) 构建 FFI 分块库 - 用于 CDC 分块
cd chunker-ffi
./build.sh
cd ..
```

### 配置

复制 `.env.demo` 到 `.env` 并更新为实际值：

```bash
cp .env.demo .env
# 然后编辑 .env 填入实际配置
```

`.env` 文件应包含：

```env
# 加密密钥 (32 字节)
AES_KEY=your_32_byte_aes_key_here_12345

# S3 兼容云存储（同步必需）
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=your_bucket_name
S3_ENDPOINT=s3.amazonaws.com
S3_REGION=us-east-1
```

**云存储兼容性**:
- ✅ **AWS S3** - 完全支持，推荐使用
- ✅ **七牛云** - 完全支持，推荐使用
- ⚠️ **阿里云 OSS** - 支持但同步较慢（不支持 ListObjects，需要遍历所有对象）

**注意**: 阿里云 OSS 缺少 ListObjects 支持，这意味着同步操作需要遍历所有对象，导致性能较慢。我们推荐使用 AWS S3 或七牛云以获得更好的性能。

### 简单用法

**注意**: 所有路径（`data-path`、`repo-path`、`remote-path`）必须由用户指定。

#### 创建索引

```bash
# 创建快照索引
dart run bin/main.dart index -d ./data -r ./.flow-repo -p remote/path --memo "Initial backup"
```

#### 同步到云端

```bash
# 同步到云端 (自动检测上传/下载方向)
dart run bin/main.dart sync -d ./data -r ./.flow-repo -p remote/path
```

#### 同步到新设备

```bash
# 同步到新设备 (使用不同的本地仓库路径)
dart run bin/main.dart sync -d ./data-device2 -r ./.flow-repo-device2 -p remote/path
```

### 编程方式使用

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flow_repo/flow_repo.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  // 加载环境变量
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  
  // 获取 AES 密钥
  final aesKeyStr = env['AES_KEY'] ?? '12345678901234567890123456789012';
  final aesKey = Uint8List.fromList(aesKeyStr.codeUnits.take(32).toList());
  
  // 配置云存储（可选，仅同步时需要）
  final cloud = S3Cloud(
    endpoint: 'https://s3.amazonaws.com',
    accessKey: env['AWS_ACCESS_KEY_ID']!,
    secretKey: env['AWS_SECRET_ACCESS_KEY']!,
    bucket: env['S3_BUCKET']!,
    region: env['S3_REGION']!,
    availableSize: 100 * 1024 * 1024 * 1024, // 100GB
  );
  
  // 创建仓库
  final repo = await Repo.create(
    dataPath: './data',
    repoPath: './.flow-repo',
    deviceID: 'device-001',
    deviceName: 'My Device',
    deviceOS: Platform.operatingSystem,
    aesKey: aesKey,
    cloud: cloud,
    remotePath: 'remote/path', // 远程存储路径
  );
  
  // 创建索引
  final index = await repo.index('My backup');
  print('索引已创建: ${index.id}');
  
  // 同步到云端
  final result = await repo.sync();
  print('上传: ${result.uploadBytes} 字节');
  print('下载: ${result.downloadBytes} 字节');
}
```

---

## 🏗️ 技术架构

### 分块引擎对比

| 特性 | **CDC (FFI)** ⭐️ | 固定分块 | 优化分块 |
|------|-----------------|---------|---------|
| **实现语言** | Go (FFI) | Dart | Dart |
| **块大小** | 512KB-8MB 动态 | 8MB 固定 | 8MB 固定 |
| **算法复杂度** | O(n) | O(n) | O(n) |
| **并发支持** | ✅ (Go 原生) | ❌ | ✅ (Isolate) |
| **增量效果** | **更佳 (99%+)** ⭐️ | 极佳 (98%+) | 极佳 (98%+) |
| **适用场景** | **插入/删除场景** ⭐️ | 追加式数据库 | 大文件处理 |
| **块边界稳定性** | **内容感知** ⭐️ | 位置固定 | 位置固定 |
| **依赖** | 需编译 .dylib/.so | 无 | 无 |
| **推荐场景** | **通用推荐** ⭐️ | 简单场景 | 大文件场景 |

### 数据流

```
┌──────────────────────────────────────────────────────────────┐
│                       索引创建阶段                             │
│                                                                │
│  文件扫描 → 分块引擎 → SHA-1 哈希 → 索引构建 → 压缩存储        │
│              ↓                                                 │
│        固定 / CDC / 优化                                       │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                       同步阶段                                 │
│                                                                │
│  对比索引 → 缺失块列表 → ZLib 压缩 → AES-256 加密 → 云端上传   │
│      ↓                                                         │
│  自动去重 (SHA-1 内容寻址)                                      │
└──────────────────────────────────────────────────────────────┘
```

### 仓库结构

```
.flow-repo/
├── indexes/          # 📋 快照索引 (仅压缩)
│   └── <sha1-id>
├── objects/          # 📦 数据块 (压缩 + 加密)
│   └── <2-char>/
│       └── <sha1-id>
├── files/            # 📄 文件元数据 (压缩 + 加密)
│   └── <2-char>/
│       └── <sha1-id>
└── refs/             # 🔖 引用指针
    └── latest        # 最新快照引用
```

---

## 🔬 CDC 分块引擎详解

### 快速开始使用 CDC

#### 1. 构建 FFI 分块库

```bash
cd chunker-ffi
./build.sh
```

**构建产物**:
- macOS: `lib/native/libchunker.dylib` (Universal Binary)
- Linux: `lib/native/libchunker_linux_{amd64,arm64}.so`
- Windows: `lib/native/libchunker.dll`
- Android: `lib/native/libchunker_android_{arm64,amd64}.so`

**详细文档**: 参见 [`chunker-ffi/BUILD_GUIDE.md`](chunker-ffi/BUILD_GUIDE.md)

#### 2. 在 Dart 中使用 CDC 分块

```dart
import 'package:flow_repo/util/chunker_ffi.dart';

// 创建 CDC 分块器
final chunker = ChunkerFFI();
final handle = chunker.chunkerNew('/path/to/file');

// 获取分块参数
print('Min chunk size: ${chunker.getMinSize()}');  // 512KB
print('Max chunk size: ${chunker.getMaxSize()}');  // 8MB

// 迭代获取所有数据块
while (true) {
  final chunk = chunker.chunkerNext(handle);
  if (chunk == null) break; // EOF
  
  // 处理分块数据
  print('Chunk size: ${chunk.length} bytes');
  // 计算块哈希用于去重
  final hash = sha1(chunk);
  // 存储或上传块...
}

// 释放资源
chunker.chunkerClose(handle);
```

#### 3. CDC vs 固定分块对比示例

**场景**: 在 100MB 文件中间插入 1MB 数据

```
固定分块 (8MB):
[块1: 8MB] [块2: 8MB] [块3: 8MB] ... [块12: 8MB] [块13: 4MB]
         ↓ 插入 1MB 数据 ↓
[块1: 8MB] [块2: 8MB] [新块: 1MB] [块3: 8MB] ... [块13: 4MB]
         ↑ 块3-13 全部需要重传 ↑
需要传输: ~92MB (块2后半部分 + 新块 + 块3-13)

CDC 分块:
[块1] [块2] [块3] ... [块N]
         ↓ 插入 1MB 数据 ↓
[块1] [块2] [新块: 1MB] [块3] ... [块N]
         ↑ 只影响插入点附近 ↑
需要传输: ~2-3MB (块2后半部分 + 新块 + 块3前半部分)
```

### 其他分块策略

#### Isolate 并发分块

```dart
import 'package:flow_repo/util/chunker_optimized.dart';

// 自动根据文件大小选择并发策略
final chunks = await ChunkerOptimized.chunkFile('/path/to/large/file');

for (final chunk in chunks) {
  print('Chunk ID: ${chunk.id}, Size: ${chunk.length}');
}
```

---

## 🌟 核心功能

- ✅ **CDC 分块引擎** - 内容定义分块，99%+ 流量节省 ⭐️
- ✅ **跨平台 FFI** - Go 原生性能，Dart 无缝调用
- ✅ **多策略支持** - CDC / 固定分块 / Isolate 并发
- ✅ **增量同步** - 智能检测变化，只传输差异
- ✅ **端到端加密** - AES-256，云端零知识
- ✅ **内容去重** - SHA-1 哈希，自动去重
- ✅ **数据压缩** - ZLib 高效压缩
- ✅ **双向同步** - 自动检测上传/下载方向
- ✅ **云端备份** - S3 兼容存储（阿里云 OSS）
- ✅ **并发控制** - 避免云端 API 过载
- ✅ **完整性校验** - 100% 数据一致性保证

---

## 📚 文档

- 📖 [构建指南](chunker-ffi/BUILD_GUIDE.md) - FFI 库构建详解
- 📝 [贡献指南](CONTRIBUTING.md) - 如何参与开发
- 📋 [变更日志](CHANGELOG.md) - 版本历史

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

在提交代码前，请确保：
1. 运行 `dart format .`
2. 运行 `dart analyze` 无错误
3. 测试通过
4. 遵循 [Conventional Commits](https://www.conventionalcommits.org/)

---

## 📄 许可证

**AGPL-3.0**

本项目采用 AGPL-3.0 开源协议，要求修改后的版本也必须开源。

---

## 🙏 致谢

Dart CDC Sync 受到多个优秀开源项目的启发和影响：

### DejaVu

[DejaVu](https://github.com/siyuan-note/dejavu) - Dart CDC Sync 的原始设计和灵感来源。DejaVu 是一个用 Go 编写的数据快照和同步系统，它向我们介绍了内容定义分块和增量同步的概念。Dart CDC Sync 将这些强大的概念引入 Dart/Flutter 生态，使其能够为移动和跨平台应用所用。

**从 DejaVu 获得的关键启发**：
- 内容定义分块 (CDC) 用于高效增量同步
- 基于快照的版本控制系统
- 内容寻址存储架构
- 零知识加密方法

### ArtiVC

[ArtiVC](https://github.com/artivc/artivc) - 另一个有影响力的项目，展示了内容定义分块在版本控制和数据同步方面的强大能力。ArtiVC 高效处理大文件和二进制数据的方法影响了 Dart CDC Sync 的设计。

**从 ArtiVC 获得的关键启发**：
- 高效处理大型二进制文件
- 基于内容的去重策略
- 最小化元数据开销

### 其他致谢

- [restic/chunker](https://github.com/restic/chunker) - Dart CDC Sync 通过 FFI 使用的久经考验的 CDC 算法实现
- [Dart FFI](https://dart.dev/guides/libraries/c-interop) - 强大的跨语言互操作，使 Go 库集成成为可能

---

## 📊 项目状态

| 指标 | 状态 |
|------|------|
| **版本** | 1.0.0 |
| **状态** | ✅ 生产可用 |
| **Dart SDK** | ≥ 3.0.0 |
| **平台支持** | macOS / Linux / Windows / Android |
| **最后更新** | 2026-01-04 |

---

<p align="center">
  Made with ❤️ by Dart CDC Sync Team
</p>

