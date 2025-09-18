import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  Post({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.scope,
    required this.createdBy,
    required this.upvotesCount,
    required this.answersCount,
    required this.snapshot,
    this.authorName,
    this.authorHandle,
    this.authorAvatarUrl,
    this.category,
    this.semester,
    this.universityCode,
    this.imageUrl,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String scope;
  final String createdBy;
  final int upvotesCount;
  final int answersCount;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;
  final String? authorName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final String? category;
  final String? semester;
  final String? universityCode;
  final String? imageUrl;
  final List<String> tags;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    } else {
      createdAt = DateTime.now();
    }

    List<String> _castStringList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return const [];
    }

    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return Post(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      scope: (data['scope'] as String?)?.trim() ?? 'community',
      createdBy: (data['createdBy'] as String?) ?? '',
      upvotesCount: _asInt(data['upvotesCount'] ?? data['upvotes']),
      answersCount: _asInt(data['commentsCount'] ?? data['answersCount']),
      snapshot: doc,
      authorName: (data['authorName'] as String?)?.trim(),
      authorHandle: (data['authorHandle'] as String?)?.trim(),
      authorAvatarUrl: (data['authorAvatarUrl'] as String?)?.trim(),
      category: (data['category'] as String?)?.trim(),
      semester: (data['semester'] as String?)?.trim(),
      universityCode: (data['universityCode'] as String?)?.trim(),
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      tags: _castStringList(data['tags']),
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
