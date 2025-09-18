// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentRepository {
  CommentRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _commentsCol =>
      _firestore.collection('comments');

  Stream<List<CommentModel>> commentsStream({required String postId}) {
    return _commentsCol
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(CommentModel.fromDoc).toList());
  }

  Future<String> addComment({
    required String postId,
    required String body,
    required String createdBy,
    String? parentId,
  }) async {
    final doc = _commentsCol.doc();
    await doc.set(CommentModel(
      id: doc.id,
      postId: postId,
      body: body,
      createdBy: createdBy,
      createdAt: Timestamp.now(),
      parentId: parentId,
    ).toMap());
    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
      'answersCount': FieldValue.increment(1),
    });
    return doc.id;
  }

  Future<void> toggleVote({required String commentId, required String userId, required bool isUpvote}) async {
    final doc = _commentsCol.doc(commentId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(doc);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final up = (data['upvoters'] as List?)?.cast<String>() ?? <String>[];
      final down = (data['downvoters'] as List?)?.cast<String>() ?? <String>[];
      up.remove(userId);
      down.remove(userId);
      if (isUpvote) {
        up.add(userId);
      } else {
        down.add(userId);
      }
      txn.update(doc, {
        'upvoters': up,
        'downvoters': down,
      });
    });
  }
}
