// COMMUNITY 3.0
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class RoomRepository {
  // COMMUNITY 3.0
  RoomRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  Stream<List<Room>> streamRooms({String? semester, String? topic}) {
    // COMMUNITY 3.0 optional filters
    Query<Map<String, dynamic>> q = _rooms.orderBy('name');
    if (semester != null && semester.isNotEmpty) {
      q = q.where('semester', isEqualTo: semester);
    }
    if (topic != null && topic.isNotEmpty) {
      q = q.where('topic', isEqualTo: topic);
    }
    return q.snapshots().map((s) => s.docs.map(Room.fromDoc).toList());
  }

  // Kept for backward compatibility (without new fields)
  Future<String> create({
    required String name,
    String? description,
    required String createdBy,
  }) async {
    final doc = _rooms.doc();
    final model = Room(
      id: doc.id,
      name: name,
      description: description,
      membersCount: 1,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      imageAsset: 'assets/images/rooms/room_01.png', // COMMUNITY 3.0 default
      semester: 'unspezifisch', // COMMUNITY 3.0 default
      topic: 'allgemein', // COMMUNITY 3.0 default
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  // COMMUNITY 3.0: new create with imageAsset/semester/topic
  Future<String> createRoom({
    required String name,
    String? description,
    required String createdBy,
    required String imageAsset,
    required String semester,
    required String topic,
  }) async {
    final doc = _rooms.doc();
    final model = Room(
      id: doc.id,
      name: name,
      description: description,
      membersCount: 1,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      imageAsset: imageAsset,
      semester: semester,
      topic: topic,
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> join(String roomId) async {
    await _rooms.doc(roomId).update({'membersCount': FieldValue.increment(1)});
  }

  Future<void> leave(String roomId) async {
    await _rooms.doc(roomId).update({'membersCount': FieldValue.increment(-1)});
  }
}
