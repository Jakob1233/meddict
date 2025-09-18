// COMMUNITY INTEGRATION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

import '../../../community/providers.dart';

class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  static Route<PostDetailPage> route({required String postId}) =>
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final postAsync = ref.watch(postProvider(postId));
    final commentsAsync = ref.watch(commentsProvider(postId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Post', style: theme.textTheme.titleLarge)),
      body: postAsync.when(
        data: (post) {
          if (post == null) {
            return Center(child: Text('Post deleted', style: theme.textTheme.bodyMedium));
          }

          final isUp = post.upvoters.contains(userId);
          final isDown = post.downvoters.contains(userId);

          // Keep answersCount in sync (lazy create / update)
          commentsAsync.whenData((list) {
            if (list.length != post.answersCount) {
              ref.read(postRepositoryProvider).updateAnswersCount(postId, list.length);
            }
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(post.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              if (post.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post.imageUrl!, fit: BoxFit.cover),
                ),
              if (post.imageUrl != null) const SizedBox(height: 12),
              Text(post.body, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: post.tags.map((t) => Chip(label: Text('#$t'))).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward, color: isUp ? theme.colorScheme.primary : null),
                    onPressed: userId == null
                        ? null
                        : () => ref.read(postRepositoryProvider).toggleVote(postId: post.id, userId: userId, isUpvote: true),
                  ),
                  Text('${post.upvotes}'),
                  IconButton(
                    icon: Icon(Icons.arrow_downward, color: isDown ? theme.colorScheme.primary : null),
                    onPressed: userId == null
                        ? null
                        : () => ref.read(postRepositoryProvider).toggleVote(postId: post.id, userId: userId, isUpvote: false),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(CommentsPage.route(postId: post.id));
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: commentsAsync.maybeWhen(
                      data: (c) => Text('${c.length} comments'),
                      orElse: () => const Text('Comments'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressContainer()),
        error: (e, st) => Center(child: Text('Error: $e', style: theme.textTheme.bodyMedium)),
      ),
    );
  }
}

class CommentsPage extends ConsumerStatefulWidget {
  const CommentsPage({super.key, required this.postId});
  final String postId;

  static Route<CommentsPage> route({required String postId}) =>
      MaterialPageRoute(builder: (_) => CommentsPage(postId: postId));

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Comments', style: theme.textTheme.titleLarge)),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text('Be the first to comment', style: theme.textTheme.bodyMedium));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final c = items[i];
                    final isUp = c.upvoters.contains(userId);
                    final isDown = c.downvoters.contains(userId);
                    final score = c.upvoters.length - c.downvoters.length;
                    return ListTile(
                      title: Text(c.body),
                      subtitle: Text(c.createdAt.toDate().toLocal().toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_upward, color: isUp ? theme.colorScheme.primary : null),
                            onPressed: userId == null
                                ? null
                                : () => ref.read(commentRepositoryProvider).toggleVote(commentId: c.id, userId: userId, isUpvote: true),
                          ),
                          Text('$score'),
                          IconButton(
                            icon: Icon(Icons.arrow_downward, color: isDown ? theme.colorScheme.primary : null),
                            onPressed: userId == null
                                ? null
                                : () => ref.read(commentRepositoryProvider).toggleVote(commentId: c.id, userId: userId, isUpvote: false),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressContainer()),
              error: (e, st) => Center(child: Text('Error: $e', style: theme.textTheme.bodyMedium)),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Add a comment...'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: userId == null
                        ? null
                        : () async {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            await ref.read(commentRepositoryProvider).addComment(
                                  postId: widget.postId,
                                  body: text,
                                  createdBy: userId,
                                );
                            _controller.clear();
                          },
                    child: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
