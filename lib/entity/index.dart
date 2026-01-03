/// Index represents a snapshot index
class Index {
  /// Hash ID
  final String id;

  /// Index memo/description
  final String memo;

  /// Creation time (milliseconds timestamp)
  final int created;

  /// List of file IDs
  final List<String> files;

  /// Total file count
  final int count;

  /// Total size in bytes
  final int size;

  /// System/Device ID
  final String systemID;

  /// System/Device name
  final String systemName;

  /// System/Device OS
  final String systemOS;

  /// Check Index ID
  final String? checkIndexID;

  Index({
    required this.id,
    required this.memo,
    required this.created,
    required this.files,
    required this.count,
    required this.size,
    required this.systemID,
    required this.systemName,
    required this.systemOS,
    this.checkIndexID,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'memo': memo,
        'created': created,
        'files': files,
        'count': count,
        'size': size,
        'systemID': systemID,
        'systemName': systemName,
        'systemOS': systemOS,
        if (checkIndexID != null) 'checkIndexID': checkIndexID,
      };

  factory Index.fromJson(Map<String, dynamic> json) => Index(
        id: json['id'] as String,
        memo: json['memo'] as String,
        created: json['created'] as int,
        files: List<String>.from(json['files'] as List),
        count: json['count'] as int,
        size: json['size'] as int,
        systemID: json['systemID'] as String,
        systemName: json['systemName'] as String,
        systemOS: json['systemOS'] as String,
        checkIndexID: json['checkIndexID'] as String?,
      );

  @override
  String toString() {
    final sizeStr = _formatBytes(size);
    final dateStr = DateTime.fromMillisecondsSinceEpoch(created)
        .toIso8601String()
        .replaceAll('T', ' ')
        .substring(0, 19);
    return 'device=$systemID/$systemOS, id=$id, files=${files.length}, size=$sizeStr, created=$dateStr';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }
}
