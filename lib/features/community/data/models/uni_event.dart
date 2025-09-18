// COMMUNITY 2.0
import 'package:cloud_firestore/cloud_firestore.dart';

class UniEvent {
  // COMMUNITY 2.0
  const UniEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startAt,
    this.endAt,
    this.location,
    required this.createdBy,
    this.imageUrl,
    required this.createdAt,
  });

  final String id; // COMMUNITY 2.0
  final String title; // COMMUNITY 2.0
  final String? description; // COMMUNITY 2.0
  final DateTime startAt; // COMMUNITY 2.0
  final DateTime? endAt; // COMMUNITY 2.0
  final String? location; // COMMUNITY 2.0
  final String createdBy; // COMMUNITY 2.0
  final String? imageUrl; // COMMUNITY 2.0
  final DateTime createdAt; // COMMUNITY 2.0

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
        'location': location,
        'createdBy': createdBy,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory UniEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UniEvent(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      description: d['description'] as String?,
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate(),
      location: d['location'] as String?,
      createdBy: (d['createdBy'] as String?) ?? '',
      imageUrl: d['imageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

