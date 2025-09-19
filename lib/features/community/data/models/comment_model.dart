// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  CommentModel({
    required this.id,
    required this.postId,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.parentId,
    this.upvoters = const [],
    this.downvoters = const [],
  });

  final String id;
  final String postId;
  final String body;
  final String createdBy;
  final Timestamp createdAt;
  final String? parentId;
  final List<String> upvoters;
  final List<String> downvoters;

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'body': body,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'parentId': parentId,
      'upvoters': upvoters,
      'downvoters': downvoters,
    };
  }

  factory CommentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CommentModel(
      id: doc.id,
      postId: (d['postId'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      createdBy: (d['createdBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?) ?? Timestamp.now(),
      parentId: d['parentId'] as String?,
      upvoters: (d['upvoters'] as List?)?.cast<String>() ?? const [],
      downvoters: (d['downvoters'] as List?)?.cast<String>() ?? const [],
    );
  }
}
