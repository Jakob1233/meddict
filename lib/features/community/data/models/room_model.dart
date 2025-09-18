// COMMUNITY 3.0
import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  // COMMUNITY 3.0
  const Room({
    required this.id,
    required this.name,
    this.description,
    required this.membersCount,
    required this.createdAt,
    required this.createdBy,
    required this.imageAsset, // COMMUNITY 3.0
    required this.semester, // COMMUNITY 3.0
    required this.topic, // COMMUNITY 3.0
  });

  final String id; // COMMUNITY 3.0
  final String name; // COMMUNITY 3.0
  final String? description; // COMMUNITY 3.0
  final int membersCount; // COMMUNITY 3.0
  final DateTime createdAt; // COMMUNITY 3.0
  final String createdBy; // COMMUNITY 3.0
  final String imageAsset; // COMMUNITY 3.0
  final String semester; // COMMUNITY 3.0
  final String topic; // COMMUNITY 3.0

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'membersCount': membersCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
        'imageAsset': imageAsset, // COMMUNITY 3.0
        'semester': semester, // COMMUNITY 3.0
        'topic': topic, // COMMUNITY 3.0
      };

  factory Room.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Room(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      description: d['description'] as String?,
      membersCount: (d['membersCount'] as num?)?.toInt() ?? 0,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: (d['createdBy'] as String?) ?? '',
      imageAsset: (d['imageAsset'] as String?) ?? 'assets/images/rooms/room_01.png', // COMMUNITY 3.0
      semester: (d['semester'] as String?) ?? 'unspezifisch', // COMMUNITY 3.0
      topic: (d['topic'] as String?) ?? 'allgemein', // COMMUNITY 3.0
    );
  }
}
