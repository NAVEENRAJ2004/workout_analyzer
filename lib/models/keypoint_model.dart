import 'dart:convert';

class KeypointEntry {
  final String id;
  final String keypointsJson;
  final DateTime timestamp;
  final String imagePath; // Can be local path or URL

  KeypointEntry({
    required this.id,
    required this.keypointsJson,
    required this.timestamp,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keypointsJson': keypointsJson,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory KeypointEntry.fromMap(Map<String, dynamic> map) {
    return KeypointEntry(
      id: map['id'] as String,
      keypointsJson: map['keypointsJson'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePath: map['imagePath'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory KeypointEntry.fromJson(String source) => KeypointEntry.fromMap(json.decode(source));
}
