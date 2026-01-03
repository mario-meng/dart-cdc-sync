# Changelog

All notable changes to Flow Repo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-03

### Added
- Initial release of Flow Repo
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
- Incremental sync: 98.08% bandwidth savings (5.25MB vs 273MB for 1-record database change)
- Index creation: ~2s for 275MB dataset
- Sync speed: 7-9s for incremental updates
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

