import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/community/application/paged_posts_controller.dart';
import 'package:flutterquiz/features/community/data/models/post_model.dart';
import 'package:flutterquiz/features/community/providers.dart';

import 'widgets/community_post_card.dart';

class TopicChannelScreen extends ConsumerStatefulWidget {
  const TopicChannelScreen({super.key, required this.category});

  final String category;

  @override
  TopicChannelScreenState createState() => TopicChannelScreenState();
}

class TopicChannelScreenState extends ConsumerState<TopicChannelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.category;

    return Scaffold(
      appBar: AppBar(
        title: Text(category, style: theme.textTheme.titleLarge),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Fragen'),
            Tab(text: 'Examens-Tipps'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TopicPostsList(category: category, type: 'question'),
          _TopicPostsList(category: category, type: 'exam_tip'),
        ],
      ),
    );
  }
}

class _TopicPostsList extends ConsumerStatefulWidget {
  const _TopicPostsList({required this.category, required this.type});

  final String category;
  final String type;

  @override
  ConsumerState<_TopicPostsList> createState() => _TopicPostsListState();
}

class _TopicPostsListState extends ConsumerState<_TopicPostsList> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  PostSort _sort = PostSort.newest;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 240) {
      ref.read(pagedPostsProvider(_args).notifier).loadMore();
    }
  }

  PagedPostsArgs get _args => PagedPostsArgs(
    category: widget.category,
    type: widget.type,
    sort: _sort,
    limit: 20,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = _args;
    final state = ref.watch(pagedPostsProvider(args));
    final posts = _filter(state.posts);

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
                    hintText: 'Suchen…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<PostSort>(
                value: _sort,
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
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sort = value);
                  ref.read(pagedPostsProvider(_args).notifier).refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(pagedPostsProvider(_args).notifier).refresh(),
            child: state.isLoadingInitial
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? _EmptyState(type: widget.type)
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 120, top: 8),
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
                        onTap: () => Navigator.of(context).pushNamed(
                          Routes.postDetail,
                          arguments: {'postId': post.id},
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemCount: posts.length + (state.isLoadingMore ? 1 : 0),
                  ),
          ),
        ),
      ],
    );
  }

  List<PostModel> _filter(List<PostModel> items) {
    if (_query.isEmpty) return items;
    final lower = _query.toLowerCase();
    return items.where((post) {
      return post.title.toLowerCase().contains(lower) ||
          post.body.toLowerCase().contains(lower);
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = type == 'exam_tip'
        ? 'Noch keine Examens-Tipps in diesem Fach. Teile deinen ersten Tipp!'
        : 'Noch keine Fragen in diesem Fach. Stelle die erste Frage!';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
