// COMMUNITY 3.0
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart'; // COMMUNITY 3.0
import '../models/uni_event.dart';

class EventRepository {
  // COMMUNITY 3.0
  EventRepository(this._firestore, this._storage);
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  Stream<List<UniEvent>> streamUpcoming() {
    final now = Timestamp.fromDate(DateTime.now());
    return _events
        .where('startAt', isGreaterThanOrEqualTo: now)
        .orderBy('startAt')
        .snapshots()
        .map((s) => s.docs.map(UniEvent.fromDoc).toList());
  }

  Stream<List<UniEvent>> streamPast() {
    final now = Timestamp.fromDate(DateTime.now());
    return _events
        .where('startAt', isLessThan: now)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UniEvent.fromDoc).toList());
  }

  // Kept for backward compatibility
  Future<String> create({
    required String title,
    String? description,
    required DateTime startAt,
    DateTime? endAt,
    String? location,
    required String createdBy,
    File? image,
  }) async {
    final doc = _events.doc();
    String? imageUrl;
    if (image != null) {
      final ref = _storage
          .ref('events/${doc.id}/images/${DateTime.now().millisecondsSinceEpoch}_${image.uri.pathSegments.last}');
      final task = await ref.putFile(image);
      imageUrl = await task.ref.getDownloadURL();
    }
    final model = UniEvent(
      id: doc.id,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      location: location,
      createdBy: createdBy,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  // COMMUNITY 3.0: Upload cover to events/{eventId}/cover.jpg
  Future<String?> uploadEventImage(String eventId, XFile file) async {
    try {
      final ref = _storage.ref('events/$eventId/cover.jpg');
      final upload = await ref.putFile(File(file.path));
      return await upload.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // COMMUNITY 3.0: create Firestore doc first, then optional image upload and patch
  Future<String> createEvent({
    required String title,
    String? description,
    required DateTime startAt,
    DateTime? endAt,
    String? location,
    required String createdBy,
    XFile? imageFile,
  }) async {
    final doc = _events.doc();
    final model = UniEvent(
      id: doc.id,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      location: location,
      createdBy: createdBy,
      imageUrl: null,
      createdAt: DateTime.now(),
    );
    await doc.set(model.toMap());

    if (imageFile != null) {
      final url = await uploadEventImage(doc.id, imageFile);
      if (url != null) {
        await doc.update({'imageUrl': url});
      }
    }
    return doc.id;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _events.doc(id).update(data);
  }

  Future<void> delete(String id) async => _events.doc(id).delete();
}
