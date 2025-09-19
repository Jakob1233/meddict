// COMMUNITY INTEGRATION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

import '../../../community/providers.dart';

class CommunityProfilePage extends ConsumerWidget {
  const CommunityProfilePage({super.key, required this.communityId});
  final String communityId;

  static Route<CommunityProfilePage> route(RouteSettings rs) {
    final args = rs.arguments as Map<String, dynamic>?;
    final id = args?['communityId'] as String?;
    return MaterialPageRoute(
      builder: (_) => CommunityProfilePage(communityId: id ?? ''),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(communityRepositoryProvider);
    final userId = ref.watch(currentUserIdProvider);
    final postList = ref.watch(communityPostsProvider(communityId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Community', style: theme.textTheme.titleLarge),
      ),
      body: Column(
        children: [
          // Header (basic)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    communityId.isNotEmpty ? communityId[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(communityId, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: userId == null
                      ? null
                      : () async {
                          // toggle membership (simple)
                          // Fetch current community membership once
                          final sub = repo.communityStream(communityId).listen((
                            c,
                          ) async {
                            if (c == null || userId == null) return;
                            final isMember = c.members.contains(userId);
                            if (isMember) {
                              await repo.leave(communityId, userId);
                            } else {
                              await repo.join(communityId, userId);
                            }
                          });
                          await Future<void>.delayed(
                            const Duration(milliseconds: 100),
                          );
                          await sub.cancel();
                        },
                  child: const Text('Join/Leave'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: postList.when(
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('No posts'));
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(items[i].title),
                    subtitle: Text(
                      items[i].body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressContainer()),
              error: (e, st) => Center(
                child: Text('Error: $e', style: theme.textTheme.bodyMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
