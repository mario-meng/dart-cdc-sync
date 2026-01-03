import 'dart:typed_data';

/// Cloud storage interface
abstract class Cloud {
  /// Upload object from file path
  Future<int> uploadObject(String filePath, {bool overwrite = false});

  /// Upload bytes data
  Future<int> uploadBytes(String filePath, Uint8List data,
      {bool overwrite = false});

  /// Download object
  Future<Uint8List> downloadObject(String filePath);

  /// Check if object exists
  Future<bool> objectExists(String filePath);

  /// List objects with prefix
  Future<Map<String, int>> listObjects(String prefix);

  /// Delete object
  Future<void> deleteObject(String filePath);

  /// Get available storage size
  int getAvailableSize();
}
