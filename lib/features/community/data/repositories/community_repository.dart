// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_model.dart';

class CommunityRepository {
  CommunityRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('communities');

  Stream<List<CommunityModel>> communitiesStream() {
    return _col.orderBy('name').snapshots().map((s) => s.docs.map(CommunityModel.fromDoc).toList());
  }

  Stream<CommunityModel?> communityStream(String id) {
    return _col.doc(id).snapshots().map((d) => d.exists ? CommunityModel.fromDoc(d) : null);
  }

  Future<String> createCommunity(CommunityModel model) async {
    final doc = _col.doc();
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> join(String communityId, String userId) async {
    await _col.doc(communityId).update({
      'members': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> leave(String communityId, String userId) async {
    await _col.doc(communityId).update({
      'members': FieldValue.arrayRemove([userId])
    });
  }
}

