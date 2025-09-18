import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/community/application/paged_posts_controller.dart';
import 'package:flutterquiz/features/community/data/models/post_model.dart';
import 'package:flutterquiz/features/community/providers.dart';

import '../widgets/community_post_card.dart';

class CommunityExamTipsTab extends ConsumerStatefulWidget {
  const CommunityExamTipsTab({super.key});

  @override
  CommunityExamTipsTabState createState() => CommunityExamTipsTabState();
}

class CommunityExamTipsTabState extends ConsumerState<CommunityExamTipsTab> {
  static const _categories = [
    'Alle',
    'Anatomie',
    'Physiologie',
    'Biochemie',
    'Pathologie',
    'Pharmakologie',
    'Innere Medizin',
    'Kardiologie',
    'Gastroenterologie',
    'Pneumologie',
    'Neurologie',
    'Chirurgie',
    'Gynäkologie',
    'Pädiatrie',
    'Psychiatrie',
    'Radiologie',
    'Allgemeinmedizin',
    'Divers',
  ];

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'Alle';
  Timer? _debounce;

  PagedPostsArgs get _args => PagedPostsArgs(
        category: _category == 'Alle' ? null : _category,
        type: 'exam_tip',
        limit: 20,
      );

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 240) {
      ref.read(pagedPostsProvider(_args).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pagedPostsProvider(_args));
    final posts = _filtered(state.posts);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final value = _categories[index];
              final selected = value == _category;
              return ChoiceChip(
                label: Text(value),
                selected: selected,
                onSelected: (v) {
                  if (!v) return;
                  setState(() => _category = value);
                  ref.read(pagedPostsProvider(_args).notifier).refresh();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _handleSearch,
            decoration: InputDecoration(
              hintText: 'Tipps durchsuchen…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(pagedPostsProvider(_args).notifier).refresh(),
            child: state.isLoadingInitial
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? const _EmptyExamTips()
                    : ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemBuilder: (context, index) {
                          if (index >= posts.length) {
                            if (state.isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          final post = posts[index];
                          return CommunityPostCard(
                            post: post,
                            onTap: () => Navigator.of(context)
                                .pushNamed(Routes.postDetail, arguments: {'postId': post.id}),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: posts.length + (state.isLoadingMore ? 1 : 0),
                      ),
          ),
        ),
      ],
    );
  }

  List<PostModel> _filtered(List<PostModel> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((post) {
      final text = '${post.title} ${post.body}'.toLowerCase();
      final bullets = (post.meta?['bullets'] as List?)?.cast<String>() ?? const [];
      final matchBullets = bullets.any((b) => b.toLowerCase().contains(q));
      return text.contains(q) || matchBullets;
    }).toList();
  }

  void _handleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }
}

class _EmptyExamTips extends StatelessWidget {
  const _EmptyExamTips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Keine Examens-Tipps gefunden. Teile deine bewährten Strategien mit der Community!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
