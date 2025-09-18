import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutterquiz/models/post.dart';

enum QaSort { newest, top }

class PostRepository {
  PostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const int _limit = 20;

  Query<Map<String, dynamic>> _qNewest(Query<Map<String, dynamic>> q) {
    return q.orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _qTop(Query<Map<String, dynamic>> q) {
    return q
        .orderBy('upvotesCount', descending: true)
        .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _baseSemester(String sem) {
    return _firestore
        .collection('posts')
        .where('scope', isEqualTo: 'semester')
        .where('semester', isEqualTo: sem);
  }

  Query<Map<String, dynamic>> _baseUni(String uniCode) {
    return _firestore
        .collection('posts')
        .where('scope', isEqualTo: 'uni')
        .where('universityCode', isEqualTo: uniCode);
  }

  Query<Map<String, dynamic>> _baseCommunity() {
    return _firestore
        .collection('posts')
        .where('scope', isEqualTo: 'community');
  }

  Query<Map<String, dynamic>> _applySort(Query<Map<String, dynamic>> query, QaSort sort) {
    return sort == QaSort.newest ? _qNewest(query) : _qTop(query);
  }

  Future<List<Post>> fetchSemester({
    required String sem,
    required QaSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _applySort(_baseSemester(sem), sort);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(_limit);
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromDoc).toList();
  }

  Future<List<Post>> fetchUni({
    required String uni,
    required QaSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _applySort(_baseUni(uni), sort);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(_limit);
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromDoc).toList();
  }

  Future<List<Post>> fetchCommunity({
    required QaSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _applySort(_baseCommunity(), sort);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(_limit);
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromDoc).toList();
  }

  Future<List<Post>> fetchAllgemein({
    required String uni,
    required QaSort sort,
  }) async {
    final results = await Future.wait([
      fetchUni(uni: uni, sort: sort),
      fetchCommunity(sort: sort),
    ]);
    final merged = <String, Post>{
      for (final post in [...results[0], ...results[1]]) post.id: post,
    };
    final items = merged.values.toList();
    items.sort((a, b) {
      if (sort == QaSort.newest) {
        return b.createdAt.compareTo(a.createdAt);
      }
      final upvoteCmp = b.upvotesCount.compareTo(a.upvotesCount);
      if (upvoteCmp != 0) {
        return upvoteCmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }
}

String? extractCreateIndexUrl(String? msg) {
  if (msg == null) return null;
  final regex = RegExp(r'https://console\.firebase\.google\.com/[^\s]+create_composite=[^\s]+');
  final match = regex.firstMatch(msg);
  return match?.group(0);
}
