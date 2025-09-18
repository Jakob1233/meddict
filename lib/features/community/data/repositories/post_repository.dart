// COMMUNITY INTEGRATION
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/post_model.dart';

enum PostSort { newest, upvotes }

class PagedPostsResult {
  PagedPostsResult({
    required this.posts,
    required this.hasMore,
    this.lastDocument,
  });

  final List<PostModel> posts;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class _AuthorProfile {
  const _AuthorProfile({this.name, this.handle, this.avatar});

  final String? name;
  final String? handle;
  final String? avatar;
}

class PostRepository {
  PostRepository(this._firestore, this._storage);
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _postsCol =>
      _firestore.collection('posts');

  Stream<List<PostModel>> latestPostsStream({int limit = 50}) {
    return _postsCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostModel.fromDoc).toList());
  }

  Query<Map<String, dynamic>> _queryWithFilters({
    String? category,
    String? type,
    Duration? since,
    PostSort sort = PostSort.newest,
    bool forPaging = false,
    int? limit,
    String? scope,
    String? semester,
    String? universityCode,
  }) {
    var query = _postsCol as Query<Map<String, dynamic>>;

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (type != null && type.isNotEmpty) {
      query = query.where('type', isEqualTo: type);
    }

    if (scope != null && scope.isNotEmpty) {
      query = query.where('scope', isEqualTo: scope);
    }

    if (semester != null && semester.isNotEmpty) {
      query = query.where('semester', isEqualTo: semester);
    }

    if (universityCode != null && universityCode.isNotEmpty) {
      query = query.where('universityCode', isEqualTo: universityCode);
    }

    Timestamp? sinceTs;
    if (since != null) {
      sinceTs = Timestamp.fromDate(DateTime.now().subtract(since));
      query = query.where('createdAt', isGreaterThanOrEqualTo: sinceTs);
    }

    // Firestore requires the inequality field to be the first orderBy.
    if (sinceTs != null) {
      query = query.orderBy('createdAt', descending: true);
      if (sort == PostSort.upvotes) {
        query = query.orderBy('upvotesCount', descending: true);
      }
    } else {
      if (sort == PostSort.upvotes) {
        query = query.orderBy('upvotesCount', descending: true).orderBy('createdAt', descending: true);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
    }

    if (forPaging && limit != null && limit > 0) {
      query = query.limit(limit);
    }

    return query;
  }

  Future<PagedPostsResult> fetchPostsPage({
    String? category,
    String? type,
    PostSort sort = PostSort.newest,
    Duration? timeWindow,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? scope,
    String? semester,
    String? universityCode,
  }) async {
    final effectiveLimit = (sort == PostSort.upvotes && timeWindow != null) ? limit * 3 : limit;
    var query = _queryWithFilters(
      category: category,
      type: type,
      since: timeWindow,
      sort: sort,
      forPaging: true,
      limit: effectiveLimit,
      scope: scope,
      semester: scope == 'semester' ? semester : null,
      universityCode: (scope == 'semester' || scope == 'uni') ? universityCode : null,
    );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    var posts = snap.docs.map(PostModel.fromDoc).toList();

    if (sort == PostSort.upvotes && timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow);
      posts = posts
          .where((p) => p.createdAt.toDate().isAfter(cutoff))
          .toList()
        ..sort((a, b) {
          final cmp = b.upvotesCount.compareTo(a.upvotesCount);
          if (cmp != 0) return cmp;
          return b.createdAt.toDate().compareTo(a.createdAt.toDate());
        });

      if (posts.length > limit) {
        posts = posts.sublist(0, limit);
      }
    }

    return PagedPostsResult(
      posts: posts,
      hasMore: snap.docs.length == effectiveLimit,
      lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  Stream<List<PostModel>> feedStream({int limit = 20}) {
    return _queryWithFilters(limit: limit, forPaging: true)
        .snapshots()
        .map((s) => s.docs.map(PostModel.fromDoc).toList());
  }

  Stream<List<PostModel>> topPostsStream({
    Duration window = const Duration(days: 30),
    int limit = 10,
    String? category,
    String? type,
  }) {
    final query = _queryWithFilters(
      category: category,
      since: window,
      type: type,
      sort: PostSort.newest,
      forPaging: true,
      limit: limit * 3,
    );

    return query.snapshots().map((snapshot) {
      final cutoff = DateTime.now().subtract(window);
      final items = snapshot.docs
          .map(PostModel.fromDoc)
          .where((p) => p.createdAt.toDate().isAfter(cutoff))
          .toList()
        ..sort((a, b) {
          final cmp = b.upvotesCount.compareTo(a.upvotesCount);
          if (cmp != 0) return cmp;
          return b.createdAt.toDate().compareTo(a.createdAt.toDate());
        });
      return items.take(limit).toList();
    });
  }

  // COMMUNITY 2.0
  Stream<List<PostModel>> streamMedThreadLatest({int limit = 50}) =>
      latestPostsStream(limit: limit);

  Stream<PostModel?> postStream(String postId) {
    return _postsCol.doc(postId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PostModel.fromDoc(doc);
    });
  }

  Stream<List<PostModel>> postsByCommunityStream({required String communityId, int limit = 50}) {
    return _postsCol
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostModel.fromDoc).toList());
  }

  // COMMUNITY 2.0
  Stream<List<PostModel>> streamRoomPosts(String roomId, {int limit = 50}) {
    return _postsCol
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostModel.fromDoc).toList());
  }

  Future<_AuthorProfile> _resolveAuthorProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      if (data == null) return const _AuthorProfile();
      final email = data['email'] as String?;
      final rawDisplayName = (data['displayName'] as String?) ?? (email != null ? email.split('@').first : null);
      final displayName = (rawDisplayName != null && rawDisplayName.isNotEmpty) ? rawDisplayName : null;
      String? handle;
      if (displayName != null) {
        final slug = displayName.split(RegExp(r'\s+')).first.toLowerCase();
        if (slug.isNotEmpty) {
          handle = '@$slug';
        }
      }
      return _AuthorProfile(
        name: displayName,
        handle: handle,
        avatar: data['photoURL'] as String?,
      );
    } catch (_) {
      return const _AuthorProfile();
    }
  }

  // COMMUNITY 3.0: create post inside a room
  Future<void> createRoomPost({
    required String roomId,
    required String createdBy,
    required String body,
    String? title,
    List<String>? tags,
    String? localImagePath,
    String? localFilePath,
  }) async {
    final author = await _resolveAuthorProfile(createdBy);

    final doc = _postsCol.doc();

    // Upload optional attachment(s)
    String? imageUrl;
    String? fileUrl;
    String? fileName;
    String? fileMime;

    if (localImagePath != null && localImagePath.isNotEmpty) {
      final file = File(localImagePath);
      final ext = localImagePath.split('.').last.toLowerCase();
      final isPng = ext == 'png';
      final isGif = ext == 'gif';
      final mime = isGif
          ? 'image/gif'
          : (isPng ? 'image/png' : 'image/jpeg');
      final ref = _storage.ref().child('posts/${doc.id}/image.$ext');
      await ref.putFile(file, SettableMetadata(contentType: mime));
      imageUrl = await ref.getDownloadURL();
    } else if (localFilePath != null && localFilePath.isNotEmpty) {
      final file = File(localFilePath);
      fileName = localFilePath.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      fileMime = _guessMime(ext);
      final ref = _storage.ref().child('posts/${doc.id}/files/$fileName');
      await ref.putFile(file, SettableMetadata(contentType: fileMime));
      fileUrl = await ref.getDownloadURL();
    }

    final model = PostModel(
      id: doc.id,
      type: 'post',
      title: title ?? '',
      body: body,
      tags: tags ?? const [],
      createdBy: createdBy,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      upvotes: 0,
      answersCount: 0,
      communityId: null,
      roomId: roomId,
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
      fileMime: fileMime,
      upvoters: const [],
      downvoters: const [],
      authorName: author.name,
      authorHandle: author.handle,
      authorAvatarUrl: author.avatar,
    );
    await doc.set(model.toMap());
  }

  String _guessMime(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  // --- Safe numeric coercion: handles null, int, double/num gracefully
  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  Future<String> createPost(PostModel post, {File? imageFile}) async {
    final doc = _postsCol.doc();
    String? imageUrl;
    if (imageFile != null) {
      final ref = _storage.ref().child('posts/${doc.id}/images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.uri.pathSegments.last}');
      final task = await ref.putFile(imageFile);
      imageUrl = await task.ref.getDownloadURL();
    }

    final data = post.toMap();
    data['imageUrl'] = imageUrl;
    await doc.set(data);
    return doc.id;
  }

  Future<String> _createCommunityPost({
    required String type,
    required String createdBy,
    required String title,
    required String body,
    String? category,
    String? semester,
    String? examKind,
    List<String>? tags,
    String? refType,
    String? refId,
    Map<String, dynamic>? meta,
    String scope = 'community',
    String? universityCode,
  }) async {
    final doc = _postsCol.doc();
    final author = await _resolveAuthorProfile(createdBy);
    final now = Timestamp.now();

    final sanitizedTags = tags?.where((t) => t.trim().isNotEmpty).map((t) => t.trim()).toList() ?? const [];
    final sanitizedMeta = meta == null
        ? null
        : meta.map((key, value) => MapEntry(key, value is String ? value.trim() : value));

    final model = PostModel(
      id: doc.id,
      type: type,
      title: title.trim(),
      body: body.trim(),
      tags: sanitizedTags,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      upvotes: 0,
      answersCount: 0,
      communityId: null,
      roomId: null,
      upvoters: const [],
      downvoters: const [],
      authorName: author.name,
      authorHandle: author.handle,
      authorAvatarUrl: author.avatar,
      category: category,
      semester: semester,
      examKind: examKind,
      refType: refType,
      refId: refId,
      meta: sanitizedMeta,
      scope: scope,
      universityCode: universityCode,
    );

    await doc.set(model.toMap());
    return doc.id;
  }

  Future<String> createQuestionPost({
    required String createdBy,
    required String category,
    required String title,
    required String body,
    required String scope,
    String? semester,
    String? universityCode,
    List<String>? tags,
    String? refType,
    String? refId,
  }) {
    return _createCommunityPost(
      type: 'question',
      createdBy: createdBy,
      title: title,
      body: body,
      category: category,
      semester: semester,
      universityCode: universityCode,
      tags: tags,
      refType: refType,
      refId: refId,
      scope: scope,
    );
  }

  Future<String> createExamTipPost({
    required String createdBy,
    required String category,
    required String title,
    required String body,
    required List<String> bullets,
    String? semester,
    String? examKind,
  }) {
    final sanitizedBullets = bullets.where((b) => b.trim().isNotEmpty).map((b) => b.trim()).toList();
    final meta = <String, dynamic>{
      'bullets': sanitizedBullets,
    };
    if (semester != null && semester.isNotEmpty) meta['semester'] = semester;
    if (examKind != null && examKind.isNotEmpty) meta['examKind'] = examKind;

    return _createCommunityPost(
      type: 'exam_tip',
      createdBy: createdBy,
      title: title,
      body: body,
      category: category,
      semester: semester,
      examKind: examKind,
      meta: meta,
      scope: 'community',
    );
  }

  Future<String> createExperiencePost({
    required String createdBy,
    required String title,
    required String body,
    required Map<String, dynamic> template,
    String? category,
    String? semester,
  }) {
    final filteredTemplate = template.entries
        .where((entry) => entry.value != null &&
            ((entry.value is String && (entry.value as String).trim().isNotEmpty) ||
                (entry.value is List && (entry.value as List).isNotEmpty)))
        .fold<Map<String, dynamic>>({}, (acc, entry) {
      acc[entry.key] = entry.value;
      return acc;
    });

    return _createCommunityPost(
      type: 'experience',
      createdBy: createdBy,
      title: title,
      body: body,
      category: category,
      semester: semester,
      meta: filteredTemplate.isEmpty ? null : filteredTemplate,
      scope: 'community',
    );
  }

  Future<void> toggleVote({required String postId, required String userId, required bool isUpvote}) async {
    // Backwards-compatible: delegate to voteOnPost
    return voteOnPost(postId: postId, userId: userId, isUpvote: isUpvote);
  }

  Future<void> voteOnPost({
    required String postId,
    required String userId,
    required bool isUpvote,
  }) async {
    final fs = _firestore; // ensure single instance

    await fs.runTransaction((tx) async {
      // 1) READS FIRST
      final postRef = fs.collection('posts').doc(postId);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;

      final data = postSnap.data() as Map<String, dynamic>;
      final createdBy = (data['createdBy'] as String?) ?? '';

      // Prepare sets & counters from post
      final upSet = <String>{...((data['upvoters'] as List?)?.cast<String>() ?? const <String>[])};
      final downSet = <String>{...((data['downvoters'] as List?)?.cast<String>() ?? const <String>[])};
      var up = _asInt(data['upvotes']);
      var down = _asInt(data['downvotes']);

      final hadUp = upSet.contains(userId);
      final hadDown = downSet.contains(userId);

      // Compute vote transitions & karma delta
      var karmaDelta = 0;
      if (isUpvote) {
        if (hadDown) {
          downSet.remove(userId);
          if (down > 0) down -= 1;
          karmaDelta += 1; // removing a downvote restores +1 karma
        }
        if (hadUp) {
          upSet.remove(userId);
          if (up > 0) up -= 1;
          karmaDelta -= 1;
        } else {
          upSet.add(userId);
          up += 1;
          karmaDelta += 1;
        }
      } else {
        if (hadUp) {
          upSet.remove(userId);
          if (up > 0) up -= 1;
          karmaDelta -= 1; // removing an upvote subtracts karma
        }
        if (hadDown) {
          downSet.remove(userId);
          if (down > 0) down -= 1;
          karmaDelta += 1; // removing a downvote restores +1 karma
        } else {
          downSet.add(userId);
          down += 1;
          karmaDelta -= 1; // adding a downvote subtracts karma
        }
      }

      // If we will touch karma, READ user now (still before writes)
      int? oldKarma;
      DocumentReference<Map<String, dynamic>>? userRef;
      if (createdBy.isNotEmpty && karmaDelta != 0) {
        userRef = fs.collection('users').doc(createdBy);
        final userSnap = await tx.get(userRef);
        final userData = (userSnap.data() as Map<String, dynamic>?) ?? const {};
        oldKarma = _asInt(userData['karma']);
      }

      // 2) WRITES AFTER ALL READS
      tx.update(postRef, {
        'upvoters': upSet.toList(),
        'downvoters': downSet.toList(),
        'upvotes': up,
        'downvotes': down,
      });

      if (userRef != null && oldKarma != null && karmaDelta != 0) {
        tx.set(userRef, {'karma': oldKarma + karmaDelta}, SetOptions(merge: true));
      }
    });
  }

  // Neutralize user's vote (remove any up/down by the user) and adjust karma accordingly
  Future<void> removeVote({required String postId, required String userId}) async {
    final fs = _firestore;

    await fs.runTransaction((tx) async {
      // 1) READS FIRST
      final postRef = fs.collection('posts').doc(postId);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;

      final data = postSnap.data() as Map<String, dynamic>;
      final createdBy = (data['createdBy'] as String?) ?? '';

      final upSet = <String>{...((data['upvoters'] as List?)?.cast<String>() ?? const <String>[])};
      final downSet = <String>{...((data['downvoters'] as List?)?.cast<String>() ?? const <String>[])};
      var up = _asInt(data['upvotes']);
      var down = _asInt(data['downvotes']);

      var karmaDelta = 0;

      if (upSet.remove(userId)) {
        if (up > 0) up -= 1;
        karmaDelta -= 1;
      }
      if (downSet.remove(userId)) {
        if (down > 0) down -= 1;
        karmaDelta += 1;
      }

      // Read user (if needed) BEFORE any writes
      int? oldKarma;
      DocumentReference<Map<String, dynamic>>? userRef;
      if (createdBy.isNotEmpty && karmaDelta != 0) {
        userRef = fs.collection('users').doc(createdBy);
        final userSnap = await tx.get(userRef);
        final userData = (userSnap.data() as Map<String, dynamic>?) ?? const {};
        oldKarma = _asInt(userData['karma']);
      }

      // 2) WRITES AFTER ALL READS
      tx.update(postRef, {
        'upvoters': upSet.toList(),
        'downvoters': downSet.toList(),
        'upvotes': up,
        'downvotes': down,
      });

      if (userRef != null && oldKarma != null && karmaDelta != 0) {
        tx.set(userRef, {'karma': oldKarma + karmaDelta}, SetOptions(merge: true));
      }
    });
  }

  Future<void> updateAnswersCount(String postId, int count) async {
    await _postsCol.doc(postId).update({'answersCount': count, 'commentsCount': count});
  }

  Future<void> deletePost(String postId) async {
    // Try delete storage images under posts/<postId>/images/** and the single imageUrl if present
    try {
      final folderRef = _storage.ref().child('posts/$postId/images');
      final list = await folderRef.listAll();
      for (final item in list.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (_) {}

    // Delete related comments in batches
    try {
      const pageSize = 300;
      final commentsCol = _firestore.collection('comments');
      while (true) {
        final snap = await commentsCol.where('postId', isEqualTo: postId).limit(pageSize).get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < pageSize) break;
      }
    } catch (_) {}

    // Finally delete the post document
    await _postsCol.doc(postId).delete();
  }
}
