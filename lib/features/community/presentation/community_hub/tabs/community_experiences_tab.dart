import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/community/application/paged_posts_controller.dart';
import 'package:flutterquiz/features/community/data/models/post_model.dart';
import 'package:flutterquiz/features/community/providers.dart';

import '../widgets/community_post_card.dart';

class CommunityExperiencesTab extends ConsumerStatefulWidget {
  const CommunityExperiencesTab({super.key});

  @override
  CommunityExperiencesTabState createState() => CommunityExperiencesTabState();
}

class CommunityExperiencesTabState extends ConsumerState<CommunityExperiencesTab> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  PagedPostsArgs get _args => const PagedPostsArgs(type: 'experience', limit: 20);

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
    final theme = Theme.of(context);
    final state = ref.watch(pagedPostsProvider(_args));
    final posts = _filtered(state.posts);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _handleSearch,
                  decoration: InputDecoration(
                    hintText: 'Ort oder Einrichtung suchen…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Composer über den großen Button unten verfügbar.')),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Erfahrung teilen'),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(pagedPostsProvider(_args).notifier).refresh(),
            child: state.isLoadingInitial
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? const _EmptyExperiences()
                    : ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: posts.length + (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      final meta = post.meta ?? const {};
      final institution = (meta['institution'] ?? '').toString().toLowerCase();
      final location = (meta['location'] ?? '').toString().toLowerCase();
      return institution.contains(q) || location.contains(q) || post.title.toLowerCase().contains(q);
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

class _EmptyExperiences extends StatelessWidget {
  const _EmptyExperiences();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Noch keine Erfahrungsberichte vorhanden. Teile deine Famulatur oder Klinik-Erfahrung!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
