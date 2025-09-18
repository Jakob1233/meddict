import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/post_model.dart';
import '../data/repositories/post_repository.dart';

export '../data/repositories/post_repository.dart' show PostSort;

class PagedPostsArgs {
  const PagedPostsArgs({
    this.category,
    this.type,
    this.sort = PostSort.newest,
    this.timeWindow,
    this.limit = 20,
    this.scope,
    this.semester,
    this.universityCode,
  });

  final String? category;
  final String? type;
  final PostSort sort;
  final Duration? timeWindow;
  final int limit;
  final String? scope;
  final String? semester;
  final String? universityCode;

  PagedPostsArgs copyWith({
    String? category,
    String? type,
    PostSort? sort,
    Duration? timeWindow,
    int? limit,
    String? scope,
    String? semester,
    String? universityCode,
  }) {
    return PagedPostsArgs(
      category: category ?? this.category,
      type: type ?? this.type,
      sort: sort ?? this.sort,
      timeWindow: timeWindow ?? this.timeWindow,
      limit: limit ?? this.limit,
      scope: scope ?? this.scope,
      semester: semester ?? this.semester,
      universityCode: universityCode ?? this.universityCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedPostsArgs &&
        other.category == category &&
        other.type == type &&
        other.sort == sort &&
        other.limit == limit &&
        other._timeWindowMs == _timeWindowMs &&
        other.scope == scope &&
        other.semester == semester &&
        other.universityCode == universityCode;
  }

  @override
  int get hashCode =>
      Object.hash(category, type, sort, limit, _timeWindowMs, scope, semester, universityCode);

  int? get _timeWindowMs => timeWindow?.inMilliseconds;
}

class PagedPostsState {
  const PagedPostsState({
    this.posts = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<PostModel> posts;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  PagedPostsState copyWith({
    List<PostModel>? posts,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return PagedPostsState(
      posts: posts ?? this.posts,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PagedPostsNotifier extends StateNotifier<PagedPostsState> {
  PagedPostsNotifier({required this.repo, required this.args})
      : super(const PagedPostsState());

  final PostRepository repo;
  final PagedPostsArgs args;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _isFetching = false;

  Future<void> loadInitial() async {
    if (_isFetching) return;
    _isFetching = true;
    state = state.copyWith(isLoadingInitial: true, isLoadingMore: false, error: null, clearError: true);
    try {
      final result = await repo.fetchPostsPage(
        category: args.category,
        type: args.type,
        sort: args.sort,
        timeWindow: args.timeWindow,
        limit: args.limit,
        scope: args.scope,
        semester: args.semester,
        universityCode: args.universityCode,
      );
      _cursor = result.lastDocument;
      state = state.copyWith(
        posts: result.posts,
        hasMore: result.hasMore,
        isLoadingInitial: false,
        isLoadingMore: false,
      );
    } catch (err) {
      state = state.copyWith(isLoadingInitial: false, error: err);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> loadMore() async {
    if (_isFetching || !state.hasMore) return;
    _isFetching = true;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await repo.fetchPostsPage(
        category: args.category,
        type: args.type,
        sort: args.sort,
        timeWindow: args.timeWindow,
        limit: args.limit,
        startAfter: _cursor,
        scope: args.scope,
        semester: args.semester,
        universityCode: args.universityCode,
      );
      _cursor = result.lastDocument;
      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (err) {
      state = state.copyWith(isLoadingMore: false, error: err);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    await loadInitial();
  }
}
