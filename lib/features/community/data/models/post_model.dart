// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  PostModel({
    required this.id,
    required this.type, // 'qa' | 'exam' | 'clerkship' | 'post'
    required this.title,
    required this.body,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.upvotes,
    this.downvotes = 0,
    required this.answersCount,
    this.communityId,
    this.roomId, // COMMUNITY 2.0
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileMime,
    this.upvoters = const [],
    this.downvoters = const [],
    this.authorName,
    this.authorHandle,
    this.authorAvatarUrl,
    this.category,
    this.semester,
    this.examKind,
    this.refType,
    this.refId,
    this.meta,
    this.scope,
    this.universityCode,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final List<String> tags;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final int upvotes;
  final int downvotes;
  final int answersCount;
  final String? communityId;
  final String? roomId; // COMMUNITY 2.0
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final String? fileMime;
  final List<String> upvoters;
  final List<String> downvoters;
  // Denormalized author fields (backward-compatible)
  final String? authorName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final String? category;
  final String? semester;
  final String? examKind;
  final String? refType;
  final String? refId;
  final Map<String, dynamic>? meta;
  final String? scope;
  final String? universityCode;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'title': title,
      'body': body,
      'tags': tags,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'upvotes': upvotes,
      'upvotesCount': upvotes,
      'downvotes': downvotes,
      'answersCount': answersCount,
      'commentsCount': answersCount,
      'communityId': communityId,
      'roomId': roomId, // COMMUNITY 2.0
      'upvoters': upvoters,
      'downvoters': downvoters,
    };
    if (authorName != null) map['authorName'] = authorName;
    if (authorHandle != null) map['authorHandle'] = authorHandle;
    if (authorAvatarUrl != null) map['authorAvatarUrl'] = authorAvatarUrl;
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    if (fileUrl != null) map['fileUrl'] = fileUrl;
    if (fileName != null) map['fileName'] = fileName;
    if (fileMime != null) map['fileMime'] = fileMime;
    if (category != null && category!.isNotEmpty) map['category'] = category;
    if (semester != null && semester!.isNotEmpty) map['semester'] = semester;
    if (examKind != null && examKind!.isNotEmpty) map['examKind'] = examKind;
    if (refType != null && refType!.isNotEmpty) map['refType'] = refType;
    if (refId != null && refId!.isNotEmpty) map['refId'] = refId;
    if (meta != null && meta!.isNotEmpty) map['meta'] = meta;
    map['scope'] = (scope != null && scope!.isNotEmpty) ? scope : 'community';
    if (universityCode != null && universityCode!.isNotEmpty) {
      map['universityCode'] = universityCode;
    }
    return map;
  }

  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawMeta = d['meta'];
    return PostModel(
      id: doc.id,
      type: (d['type'] as String?) ?? 'question',
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      tags: (d['tags'] as List?)?.cast<String>() ?? const [],
      createdBy: (d['createdBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?) ?? Timestamp.now(),
      updatedAt: (d['updatedAt'] as Timestamp?) ?? Timestamp.now(),
      upvotes: ((d['upvotesCount'] as num?) ?? (d['upvotes'] as num?) ?? 0)
          .toInt(),
      downvotes: (d['downvotes'] as num?)?.toInt() ?? 0,
      answersCount:
          ((d['commentsCount'] as num?) ?? (d['answersCount'] as num?) ?? 0)
              .toInt(),
      communityId: d['communityId'] as String?,
      roomId: d['roomId'] as String?, // COMMUNITY 2.0
      imageUrl: d['imageUrl'] as String?,
      fileUrl: d['fileUrl'] as String?,
      fileName: d['fileName'] as String?,
      fileMime: d['fileMime'] as String?,
      upvoters: (d['upvoters'] as List?)?.cast<String>() ?? const [],
      downvoters: (d['downvoters'] as List?)?.cast<String>() ?? const [],
      authorName: d['authorName'] as String?,
      authorHandle: d['authorHandle'] as String?,
      authorAvatarUrl: d['authorAvatarUrl'] as String?,
      category: (d['category'] as String?) ?? 'Divers',
      semester: d['semester'] as String?,
      examKind: d['examKind'] as String?,
      refType: d['refType'] as String?,
      refId: d['refId'] as String?,
      meta: rawMeta is Map<String, dynamic>
          ? rawMeta
          : rawMeta is Map
          ? rawMeta.map((key, value) => MapEntry(key.toString(), value))
          : null,
      scope: (d['scope'] as String?) ?? 'community',
      universityCode: d['universityCode'] as String?,
    );
  }

  int get score => upvotes - downvotes;

  int get upvotesCount => upvotes;

  int get commentsCount => answersCount;
}
