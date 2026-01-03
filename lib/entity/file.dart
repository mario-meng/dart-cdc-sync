import '../util/hash.dart';

/// File represents a file entity with metadata
class File {
  /// Hash ID
  final String id;

  /// File path
  final String path;

  /// File size in bytes
  final int size;

  /// Last modified time (milliseconds timestamp)
  final int updated;

  /// List of chunk IDs
  final List<String> chunks;

  File({
    required this.id,
    required this.path,
    required this.size,
    required this.updated,
    required this.chunks,
  });

  /// Creates a new File object
  ///
  /// File ID is computed from path and updated time
  factory File.newFile(String path, int size, int updated) {
    // File ID = SHA1(path + updated/1000)
    final id = hashString('$path${updated ~/ 1000}');
    return File(
      id: id,
      path: path,
      size: size,
      updated: updated,
      chunks: [],
    );
  }

  /// Get updated time in seconds
  int secUpdated() => updated ~/ 1000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'size': size,
        'updated': updated,
        'chunks': chunks,
      };

  factory File.fromJson(Map<String, dynamic> json) => File(
        id: json['id'] as String,
        path: json['path'] as String,
        size: json['size'] as int,
        updated: json['updated'] as int,
        chunks: List<String>.from(json['chunks'] as List),
      );
}
