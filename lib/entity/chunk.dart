/// Chunk represents a file chunk with its data
class Chunk {
  /// Chunk ID (SHA-1 hash)
  final String id;

  /// Actual data content
  final List<int> data;

  Chunk({
    required this.id,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
      };

  factory Chunk.fromJson(Map<String, dynamic> json) => Chunk(
        id: json['id'] as String,
        data: List<int>.from(json['data'] as List),
      );
}
