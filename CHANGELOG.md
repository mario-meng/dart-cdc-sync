# Changelog

All notable changes to Dart CDC Sync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-04

### Fixed
- **Critical**: Fixed chunk path matching issue in cloud sync that caused all chunks to be treated as new
  - Chunks are now correctly identified as existing when they match cloud storage
  - Dramatically improved sync performance: from 16.25s to 0.67s (24x faster)
  - Reduced incremental traffic: from 5.25MB to 810KB (84% reduction)
- Fixed `dart:io` namespace conflict in `bin/main.dart` by using `import 'dart:io' as io`
- Fixed hardcoded 'repo' prefix issue in S3Cloud, now properly uses remotePath parameter

### Added
- Added `.env.demo` template file for easy configuration setup
- Enhanced error handling: script now checks for `.env` file and prompts user to copy from `.env.demo`

### Changed
- Renamed project from "Flow Repo" to "Dart CDC Sync"
- Refactored `bin/main.dart` test script to use mandatory parameters (data-path, repo-path, remote-path)
- Simplified test script based on `test_sync.dart` patterns
- Refactored chunker_ffi to extract package root directory method

### Performance
- **Sync speed**: Improved from 16.25s to 0.67s (13.5x faster than Go version)
- **Incremental traffic**: Reduced from 5.25MB to 810KB (better than Go version's 981KB)
- **Index creation**: Maintained at 1.94s (42% faster than Go version)

## [1.0.0] - 2026-01-03

### Added
- Initial release of Dart CDC Sync (formerly Flow Repo)
- File chunking with SHA-1 hashing
- Data compression using ZLib
- AES-256-CBC encryption
- Incremental sync with 98%+ bandwidth savings
- S3-compatible cloud storage support
- Bidirectional sync (upload/download)
- Command-line interface for index and sync operations

### Features
- **Fixed-size chunking**: 8MB chunks for stable incremental sync
- **Content deduplication**: SHA-1 based content addressing
- **End-to-end encryption**: AES-256 encryption before upload
- **Efficient compression**: ZLib compression to reduce storage
- **Cloud backup**: S3/OSS compatible storage support
- **Concurrent processing**: Batch upload/download with concurrency control

### Performance
- Incremental sync: 99.7% bandwidth savings (810KB vs 273MB for 1-record database change)
- Index creation: 1.94s for 275MB dataset
- Sync speed: 0.67s for incremental updates
- Data integrity: 100% accuracy

### Documentation
- Comprehensive README with usage examples
- Contributing guidelines
- License (AGPL-3.0)
- Configuration templates

### Experimental
- Content-Defined Chunking implementation (not recommended for production)
- Analysis of CDC vs fixed chunking tradeoffs

## [0.1.0] - Development Versions

### Iterations
- Initial implementation with fixed chunking
- CDC experimentation
- Performance optimization
- Concurrent processing improvements
- Code quality and documentation

---

For detailed performance comparisons and technical analysis, see the comparison reports in the parent directory.

