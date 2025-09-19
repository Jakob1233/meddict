import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/data/repositories/post_repository.dart';
import 'package:flutterquiz/features/community/presentation/community_hub/community_composer_sheets.dart';
import 'package:flutterquiz/features/onboarding/data/onboarding_repository.dart';
import 'package:flutterquiz/features/profile_management/profile_management_local_data_source.dart';
import 'package:flutterquiz/models/post.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

enum QaFilter { allgemein, uni, semester }

const _filterOptions = [QaFilter.allgemein, QaFilter.uni, QaFilter.semester];
const _pageSize = 20;
const _emptyIllustration = 'assets/images/onboarding_c.svg';

class QaScreen extends ConsumerStatefulWidget {
  const QaScreen({super.key});

  static const routeName = '/community/qa';

  @override
  QaScreenState createState() => QaScreenState();
}

class QaScreenState extends ConsumerState<QaScreen> {
  final _repo = PostRepository();
  final _profileLocal = ProfileManagementLocalDataSource();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Timer? _debounce;
  QaFilter _filter = QaFilter.allgemein;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _missingProfile = false;
  String? _errorMessage;
  bool _showIndexBanner = false;
  String? _indexUrl;
  String _query = '';

  List<Post> _posts = const [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  String _semester = '';
  String _universityCode = '';
  String _universityName = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_filter == QaFilter.allgemein || !_hasMore || _isLoadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _syncProfileContext() {
    _semester = FirstLoginOnboardingController.normalizeSemester(
      _profileLocal.getSemester(),
    );
    _universityCode = _profileLocal.getUniversityCode();
    _universityName = _profileLocal.getUniversityName();
  }

  Future<void> _loadInitial() async {
    _syncProfileContext();
    _debounce?.cancel();
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _missingProfile = false;
      _showIndexBanner = false;
      _indexUrl = null;
      _lastDoc = null;
      _hasMore = false;
    });

    try {
      List<Post> result = const [];
      switch (_filter) {
        case QaFilter.allgemein:
          if (_universityCode.isEmpty) {
            result = await _repo.fetchCommunity(sort: QaSort.newest);
          } else {
            result = await _repo.fetchAllgemein(
              uni: _universityCode,
              sort: QaSort.newest,
            );
          }
          _hasMore = false;
          break;
        case QaFilter.uni:
          if (_universityCode.isEmpty || _universityName.isEmpty) {
            setState(() {
              _missingProfile = true;
              _isInitialLoading = false;
              _posts = const [];
            });
            return;
          }
          result = await _repo.fetchUni(
            uni: _universityCode,
            sort: QaSort.newest,
          );
          _hasMore = result.length == _pageSize;
          _lastDoc = result.isNotEmpty ? result.last.snapshot : null;
          break;
        case QaFilter.semester:
          if (_semester.isEmpty) {
            setState(() {
              _missingProfile = true;
              _isInitialLoading = false;
              _posts = const [];
            });
            return;
          }
          result = await _repo.fetchSemester(
            sem: _semester,
            sort: QaSort.newest,
          );
          _hasMore = result.length == _pageSize;
          _lastDoc = result.isNotEmpty ? result.last.snapshot : null;
          break;
      }

      if (!mounted) return;
      setState(() {
        _posts = _sortPosts(result);
        _isInitialLoading = false;
      });
    } on FirebaseException catch (err) {
      if (!mounted) return;
      if (err.code == 'failed-precondition') {
        setState(() {
          _showIndexBanner = true;
          _indexUrl ??= extractCreateIndexUrl(err.message);
          _errorMessage ??=
              'Teil des Q&A konnte nicht geladen werden (Index fehlt).';
          _isInitialLoading = false;
        });
        debugPrint('[Q&A] TODO: Missing Firestore index. ${err.message}');
      } else {
        setState(() {
          _errorMessage = 'Q&A konnte nicht vollständig geladen werden.';
          _isInitialLoading = false;
        });
      }
    } catch (err) {
      debugPrint('[Q&A] Fehler beim Laden: $err');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Q&A konnte nicht vollständig geladen werden.';
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_filter == QaFilter.allgemein || !_hasMore || _isLoadingMore) return;
    final startAfter = _lastDoc;
    if (startAfter == null) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      List<Post> result;
      if (_filter == QaFilter.uni) {
        result = await _repo.fetchUni(
          uni: _universityCode,
          sort: QaSort.newest,
          startAfter: startAfter,
        );
      } else {
        result = await _repo.fetchSemester(
          sem: _semester,
          sort: QaSort.newest,
          startAfter: startAfter,
        );
      }

      if (!mounted) return;
      setState(() {
        if (result.isEmpty) {
          _hasMore = false;
        } else {
          _posts = _mergeAndSort(_posts, result);
          _lastDoc = result.last.snapshot;
          _hasMore = result.length == _pageSize;
        }
        _isLoadingMore = false;
      });
    } on FirebaseException catch (err) {
      if (!mounted) return;
      if (err.code == 'failed-precondition') {
        setState(() {
          _showIndexBanner = true;
          _indexUrl ??= extractCreateIndexUrl(err.message);
          _errorMessage ??= 'Q&A konnte nicht vollständig geladen werden.';
          _isLoadingMore = false;
        });
        debugPrint('[Q&A] TODO: Missing Firestore index. ${err.message}');
      } else {
        setState(() {
          _errorMessage = 'Weitere Q&A-Beiträge konnten nicht geladen werden.';
          _isLoadingMore = false;
        });
      }
    } catch (err) {
      debugPrint('[Q&A] Fehler beim Nachladen: $err');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Weitere Q&A-Beiträge konnten nicht geladen werden.';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitial();
  }

  List<Post> _mergeAndSort(List<Post> current, List<Post> incoming) {
    final map = <String, Post>{
      for (final post in current) post.id: post,
    };
    for (final post in incoming) {
      map[post.id] = post;
    }
    final merged = map.values.toList();
    merged.sort(_comparePosts);
    return merged;
  }

  List<Post> _sortPosts(List<Post> items) {
    final list = List<Post>.from(items);
    list.sort(_comparePosts);
    return list;
  }

  int _comparePosts(Post a, Post b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  List<Post> get _visiblePosts {
    if (_query.isEmpty) return _posts;
    final term = _query.toLowerCase();
    return _posts.where((post) {
      final title = post.title.toLowerCase();
      final body = post.body.toLowerCase();
      final category = post.category?.toLowerCase() ?? '';
      return title.contains(term) ||
          body.contains(term) ||
          category.contains(term);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  String _filterLabel(QaFilter filter) {
    switch (filter) {
      case QaFilter.allgemein:
        return 'Alle';
      case QaFilter.uni:
        return 'Meine Uni';
      case QaFilter.semester:
        return 'Mein Semester';
    }
  }

  String _missingProfileMessage() {
    switch (_filter) {
      case QaFilter.uni:
        return 'Bitte ergänze deine Universität im Profil (Profil → Einstellungen), um diesen Filter zu nutzen.';
      case QaFilter.semester:
        return 'Bitte ergänze dein Semester im Profil (Profil → Einstellungen), um diesen Filter zu nutzen.';
      case QaFilter.allgemein:
        return 'Bitte ergänze dein Profil, um personalisierte Ergebnisse zu erhalten.';
    }
  }

  void _onFilterChanged(QaFilter? value) {
    if (value == null || value == _filter) return;
    setState(() {
      _filter = value;
      _query = '';
      _searchCtrl.clear();
    });
    _loadInitial();
  }

  void _openPost(Post post) {
    Navigator.of(context).pushNamed(
      Routes.postDetail,
      arguments: {'postId': post.id},
    );
  }

  Future<void> _onAskQuestion() async {
    if (!mounted) return;
    await showQuestionComposer(context, ref);
  }

  String _scopeLabel(Post post) {
    switch (post.scope) {
      case 'semester':
        return post.semester != null && post.semester!.isNotEmpty
            ? 'Semester ${post.semester}'
            : 'Semester';
      case 'uni':
        if (_universityName.isNotEmpty) return _universityName;
        return 'Uni';
      case 'community':
      default:
        return 'Community';
    }
  }

  Widget _buildIndexBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.amber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: const Text(
            'Teil des Q&A konnte nicht geladen werden (Index fehlt).',
          ),
          subtitle: const Text(
            'Lege den erforderlichen Index in der Firebase-Konsole an.',
          ),
          trailing: (_indexUrl != null && kDebugMode)
              ? TextButton(
                  onPressed: () async {
                    final url = _indexUrl;
                    if (url != null && await canLaunchUrlString(url)) {
                      await launchUrlString(url);
                    }
                  },
                  child: const Text('Index anlegen'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _query.isEmpty
        ? 'Noch keine Fragen. Stelle die erste Frage!'
        : 'Keine Ergebnisse für "$_query".';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(_emptyIllustration, height: 180),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _visiblePosts;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Community Q&A'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAskQuestion,
        icon: const Icon(Icons.question_answer_outlined),
        label: const Text('Frage stellen'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: AppDropdown<QaFilter>(
                  label: 'Filter',
                  items: _filterOptions,
                  value: _filter,
                  itemLabel: _filterLabel,
                  searchable: false,
                  onChanged: _onFilterChanged,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_showIndexBanner)
                      SliverToBoxAdapter(child: _buildIndexBanner()),
                    if (_errorMessage != null)
                      SliverToBoxAdapter(
                        child: _buildErrorBanner(_errorMessage!),
                      ),
                    if (_missingProfile)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _missingProfileMessage(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      )
                    else if (_isInitialLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= posts.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final post = posts[index];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: QaPostCard(
                                post: post,
                                scopeLabel: _scopeLabel(post),
                                dateLabel: _dateFormat.format(post.createdAt),
                                onTap: () => _openPost(post),
                              ),
                            );
                          },
                          childCount: posts.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: bottomInset),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QaPostCard extends StatelessWidget {
  const QaPostCard({
    super.key,
    required this.post,
    required this.scopeLabel,
    required this.dateLabel,
    this.onTap,
  });

  final Post post;
  final String scopeLabel;
  final String dateLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(scopeLabel),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(dateLabel, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title.isEmpty ? '(Ohne Titel)' : post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (post.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(post.upvotesCount.toString()),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 6),
                  Text(post.answersCount.toString()),
                  const Spacer(),
                  if (post.authorName != null && post.authorName!.isNotEmpty)
                    Text(
                      post.authorName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
