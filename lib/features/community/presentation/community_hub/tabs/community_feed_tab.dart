import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/community/application/paged_posts_controller.dart';
import 'package:flutterquiz/features/community/data/models/post_model.dart';
import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

import '../widgets/community_post_card.dart';

enum QaFeedFilter { general, myUniversity, mySemester }

const _filterOptions = [
  QaFeedFilter.general,
  QaFeedFilter.myUniversity,
  QaFeedFilter.mySemester,
];

class CommunityFeedTab extends ConsumerStatefulWidget {
  const CommunityFeedTab({super.key});

  @override
  CommunityFeedTabState createState() => CommunityFeedTabState();
}

class CommunityFeedTabState extends ConsumerState<CommunityFeedTab> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  Timer? _debounce;
  QaFeedFilter _selectedFilter = QaFeedFilter.general;
  PostSort _sort = PostSort.newest;
  static const _topArgs = TopPostsArgs(limit: 8);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 280) {
      final userContext = ref.read(communityUserContextProvider);
      switch (_selectedFilter) {
        case QaFeedFilter.general:
          final argsList = <PagedPostsArgs?>[
            _universityArgs(userContext),
            _communityArgs(),
          ];
          for (final args in argsList) {
            if (args != null) {
              ref.read(pagedPostsProvider(args).notifier).loadMore();
            }
          }
          break;
        case QaFeedFilter.myUniversity:
          final args = _universityArgs(userContext);
          if (args != null) {
            ref.read(pagedPostsProvider(args).notifier).loadMore();
          }
          break;
        case QaFeedFilter.mySemester:
          final args = _semesterArgs(userContext);
          if (args != null) {
            ref.read(pagedPostsProvider(args).notifier).loadMore();
          }
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userContext = ref.watch(communityUserContextProvider);
    final topPostsAsync = ref.watch(topPostsProvider(_topArgs));
    bool requiresProfileDetails = false;
    bool isLoadingInitial = false;
    bool isLoadingMore = false;
    bool showIndexBanner = false;
    String? indexBannerUrl;
    String? genericError;
    List<PostModel> basePosts = const [];

    void collectError(Object? err) {
      if (err == null) return;
      if (err is FirebaseException && err.code == 'failed-precondition') {
        showIndexBanner = true;
        indexBannerUrl ??= _extractIndexUrl(err.message);
      } else {
        genericError ??= 'Q&A konnte nicht vollständig geladen werden.';
      }
    }

    switch (_selectedFilter) {
      case QaFeedFilter.general:
        final uniArgs = _universityArgs(userContext);
        final communityArgs = _communityArgs();

        final uniState = uniArgs != null
            ? ref.watch(pagedPostsProvider(uniArgs))
            : null;
        final communityState = ref.watch(pagedPostsProvider(communityArgs));

        basePosts = _mergeGeneral(
          uniState?.posts ?? const [],
          communityState.posts,
        );

        final loadingStates = <bool?>[
          uniState?.isLoadingInitial,
          communityState.isLoadingInitial,
        ];
        isLoadingInitial =
            loadingStates.any((e) => e ?? false) && basePosts.isEmpty;
        isLoadingMore =
            (uniState?.isLoadingMore ?? false) || communityState.isLoadingMore;
        collectError(uniState?.error);
        collectError(communityState.error);
        break;
      case QaFeedFilter.myUniversity:
        final uniArgs = _universityArgs(userContext);
        if (uniArgs == null) {
          requiresProfileDetails = true;
        } else {
          final state = ref.watch(pagedPostsProvider(uniArgs));
          basePosts = state.posts;
          isLoadingInitial = state.isLoadingInitial && basePosts.isEmpty;
          isLoadingMore = state.isLoadingMore;
          collectError(state.error);
        }
        break;
      case QaFeedFilter.mySemester:
        final semesterArgs = _semesterArgs(userContext);
        if (semesterArgs == null) {
          requiresProfileDetails = true;
        } else {
          final state = ref.watch(pagedPostsProvider(semesterArgs));
          basePosts = state.posts;
          isLoadingInitial = state.isLoadingInitial && basePosts.isEmpty;
          isLoadingMore = state.isLoadingMore;
          collectError(state.error);
        }
        break;
    }

    final posts = _applySearchAndSort(basePosts);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: AppDropdown<QaFeedFilter>(
            label: 'Filter',
            hintText: 'Filter',
            items: _filterOptions,
            itemLabel: (filter) => _filterLabel(filter),
            value: _selectedFilter,
            searchable: false,
            borderRadius: 16,
            onChanged: (filter) {
              if (filter == null || filter == _selectedFilter) return;
              setState(() => _selectedFilter = filter);
              unawaited(_refreshCurrent());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Stichwortsuche…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<PostSort>(
                value: _sort,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sort = value);
                  unawaited(_refreshCurrent());
                },
                items: const [
                  DropdownMenuItem(
                    value: PostSort.newest,
                    child: Text('Neueste'),
                  ),
                  DropdownMenuItem(
                    value: PostSort.upvotes,
                    child: Text('Upvotes'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCurrent,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: topPostsAsync.when(
                    data: (posts) => _TopPostsCarousel(posts: posts),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => _TopPostsErrorBanner(error: err),
                  ),
                ),
                if (showIndexBanner)
                  SliverToBoxAdapter(
                    child: _buildIndexErrorBanner(indexBannerUrl),
                  ),
                if (genericError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Material(
                        color: theme.colorScheme.surfaceVariant.withOpacity(
                          0.4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            genericError!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (requiresProfileDetails)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _missingProfileMessage(_selectedFilter),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  )
                else if (isLoadingInitial)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (posts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFeed(query: _query),
                  )
                else
                  SliverList.separated(
                    itemCount: posts.length + (isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      if (index >= posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = posts[index];
                      return CommunityPostCard(
                        post: post,
                        onTap: () => _openPost(context, post.id),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<PostModel> _filtered(List<PostModel> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((p) {
      final title = (p.title).toLowerCase();
      final body = (p.body).toLowerCase();
      return title.contains(q) ||
          body.contains(q) ||
          (p.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _openPost(BuildContext context, String postId) {
    Navigator.of(
      context,
    ).pushNamed(Routes.postDetail, arguments: {'postId': postId});
  }

  Future<void> _refreshCurrent() async {
    final context = ref.read(communityUserContextProvider);
    switch (_selectedFilter) {
      case QaFeedFilter.general:
        final futures = <Future<void>>[];
        for (final args in <PagedPostsArgs?>[
          _universityArgs(context),
          _communityArgs(),
        ]) {
          if (args != null) {
            futures.add(ref.read(pagedPostsProvider(args).notifier).refresh());
          }
        }
        await Future.wait(futures);
        break;
      case QaFeedFilter.myUniversity:
        final args = _universityArgs(context);
        if (args != null) {
          await ref.read(pagedPostsProvider(args).notifier).refresh();
        }
        break;
      case QaFeedFilter.mySemester:
        final args = _semesterArgs(context);
        if (args != null) {
          await ref.read(pagedPostsProvider(args).notifier).refresh();
        }
        break;
    }
  }

  List<PostModel> _applySearchAndSort(List<PostModel> base) {
    final filtered = _query.isEmpty
        ? List<PostModel>.from(base)
        : base.where((p) {
            final term = _query.toLowerCase();
            final title = p.title.toLowerCase();
            final body = p.body.toLowerCase();
            return title.contains(term) ||
                body.contains(term) ||
                (p.category?.toLowerCase().contains(term) ?? false);
          }).toList();

    filtered.sort(
      _sort == PostSort.upvotes ? _compareByUpvotes : _compareByNewest,
    );
    return filtered;
  }

  int _compareByNewest(PostModel a, PostModel b) {
    return b.createdAt.toDate().compareTo(a.createdAt.toDate());
  }

  int _compareByUpvotes(PostModel a, PostModel b) {
    final cmp = b.upvotesCount.compareTo(a.upvotesCount);
    if (cmp != 0) return cmp;
    return _compareByNewest(a, b);
  }

  List<PostModel> _mergeGeneral(
    List<PostModel> universityPosts,
    List<PostModel> communityPosts,
  ) {
    final ordered = <PostModel>[
      ...universityPosts,
      ...communityPosts,
    ];
    final map = <String, PostModel>{};
    for (final post in ordered) {
      map.putIfAbsent(post.id, () => post);
    }
    return map.values.toList();
  }

  PagedPostsArgs? _semesterArgs(CommunityUserContext context) {
    if (!context.hasSemester) return null;
    return PagedPostsArgs(
      limit: 20,
      sort: _sort,
      type: 'question',
      scope: 'semester',
      semester: context.semester,
      universityCode: context.universityCode,
    );
  }

  PagedPostsArgs? _universityArgs(CommunityUserContext context) {
    if (!context.hasUniversity) return null;
    return PagedPostsArgs(
      limit: 20,
      sort: _sort,
      type: 'question',
      scope: 'uni',
      universityCode: context.universityCode,
    );
  }

  PagedPostsArgs _communityArgs() {
    return PagedPostsArgs(
      limit: 20,
      sort: _sort,
      type: 'question',
      scope: 'community',
    );
  }

  String _filterLabel(QaFeedFilter filter) {
    switch (filter) {
      case QaFeedFilter.general:
        return 'Allgemein';
      case QaFeedFilter.myUniversity:
        return 'Meine Uni';
      case QaFeedFilter.mySemester:
        return 'Mein Semester';
    }
  }

  String _missingProfileMessage(QaFeedFilter filter) {
    switch (filter) {
      case QaFeedFilter.myUniversity:
        return 'Bitte ergänze deine Universität im Profil (Profil → Einstellungen), um diesen Filter zu nutzen.';
      case QaFeedFilter.mySemester:
        return 'Bitte ergänze dein Semester im Profil (Profil → Einstellungen), um diesen Filter zu nutzen.';
      case QaFeedFilter.general:
        return 'Bitte ergänze deine Profilangaben, um personalisierte Ergebnisse zu erhalten.';
    }
  }

  Widget _buildIndexErrorBanner(String? createIndexUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          title: const Text(
            'Teil des Q&A konnte nicht geladen werden (Index fehlt).',
          ),
          subtitle: const Text(
            'In der Firebase-Konsole kann der erforderliche Index erstellt werden.',
          ),
          trailing: (createIndexUrl != null && kDebugMode)
              ? TextButton(
                  onPressed: () async {
                    await launchUrlString(createIndexUrl);
                  },
                  child: const Text('Index anlegen'),
                )
              : null,
        ),
      ),
    );
  }
}

class _TopPostsErrorBanner extends StatelessWidget {
  const _TopPostsErrorBanner({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    String? indexUrl;
    if (error is FirebaseException &&
        (error as FirebaseException).code == 'failed-precondition') {
      indexUrl = _extractIndexUrl((error as FirebaseException).message);
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          title: const Text('Top Q&A des Monats konnte nicht geladen werden.'),
          subtitle: indexUrl != null
              ? const Text(
                  'Lege den erforderlichen Index in der Firebase-Konsole an.',
                )
              : null,
          trailing: (indexUrl != null && kDebugMode)
              ? TextButton(
                  onPressed: () async {
                    await launchUrlString(indexUrl!);
                  },
                  child: const Text('Index anlegen'),
                )
              : null,
        ),
      ),
    );
  }
}

String? _extractIndexUrl(String? message) {
  if (message == null) return null;
  final regex = RegExp(
    r'https://console\.firebase\.google\.com/[^\s]*create_composite=[^\s]*',
  );
  final match = regex.firstMatch(message);
  return match?.group(0);
}

class _TopPostsCarousel extends StatelessWidget {
  const _TopPostsCarousel({required this.posts});

  final List<PostModel> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Top Q&A des Monats',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return SizedBox(
                width: 280,
                child: CommunityPostCard(
                  post: post,
                  dense: true,
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.postDetail,
                    arguments: {'postId': post.id},
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = query.isEmpty
        ? 'Noch keine Fragen. Stelle die erste Frage!'
        : 'Keine Ergebnisse für "$query".';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
