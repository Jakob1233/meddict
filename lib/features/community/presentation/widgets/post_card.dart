// COMMUNITY 3.0 — Unified Post Card UI
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/post_model.dart';
import '../../providers.dart';

const _brandBlue = Color(0xFF2563FF);

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final PostModel post;
  final VoidCallback? onTap;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _bookmarked = false; // UI-only toggle (no backend)

  String _monogram(String name) {
    final parts = name.trim().split(RegExp(r"\s+"));
    final first = parts.isNotEmpty ? parts.first : '';
    final second = parts.length > 1 ? parts[1] : '';
    final letters =
        (first.isNotEmpty ? first[0] : '') +
        (second.isNotEmpty ? second[0] : '');
    return letters.toUpperCase();
  }

  String _handleFromName(String name) {
    final base = name.isEmpty
        ? 'user'
        : name.toLowerCase().split(RegExp(r"\s+"))[0];
    return '@$base';
  }

  String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n < 1000000) return '${(n / 1000).floor()}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final post = widget.post;

    final userMap = ref.watch(userCacheProvider);
    ref.read(userCacheProvider.notifier).ensure(post.createdBy);
    final appUser = userMap[post.createdBy];
    final displayName = post.authorName ?? appUser?.displayName ?? 'User';
    final avatarUrl = post.authorAvatarUrl ?? appUser?.photoURL;
    final handle = post.authorHandle ?? _handleFromName(displayName);

    final currentUserId = ref.watch(currentUserIdProvider);
    final isLiked = (post.upvoters).contains(currentUserId);
    final likeCount = post.upvotes;
    final commentCount = post.answersCount;
    final isPhoto = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasDoc = post.fileUrl != null && post.fileUrl!.isNotEmpty;

    // Reddit-style voting state
    final isUp = post.upvoters.contains(currentUserId);
    final isDown = post.downvoters.contains(currentUserId);
    final score = post.score;

    final radius = isPhoto ? 24.0 : 16.0;

    Widget avatar() {
      final bg = cs.primary.withOpacity(0.1);
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(avatarUrl),
          backgroundColor: bg,
        );
      }
      // fallback to monogram of actual displayName (no generic dummy avatar)
      final monogram = _monogram(displayName);
      return CircleAvatar(
        radius: 16,
        backgroundColor: bg,
        child: Text(
          monogram.isNotEmpty ? monogram : 'U',
          style: theme.textTheme.labelSmall,
        ),
      );
    }

    Future<void> onLike() async {
      if (currentUserId == null) return; // keep disabled behavior
      if (isLiked) return; // prevent accidental downvote toggle
      await ref
          .read(postRepositoryProvider)
          .toggleVote(postId: post.id, userId: currentUserId, isUpvote: true);
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _brandBlue, width: 1),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Author Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mehr',
                      onPressed: () => _showMoreMenu(
                        context,
                        cs,
                        currentUserId,
                        post.id,
                        isOwner: currentUserId == post.createdBy,
                      ),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),

                // Title (mostly for photo card)
                if (isPhoto && (post.title).trim().isNotEmpty)
                  const SizedBox(height: 12),
                if (isPhoto && (post.title).trim().isNotEmpty)
                  Text(
                    post.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),

                // Body text (text-only card shows body, photo card shows if present before photo)
                if ((post.body).trim().isNotEmpty) const SizedBox(height: 12),
                if ((post.body).trim().isNotEmpty)
                  Text(
                    post.body,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),

                // Photo (if any)
                if (isPhoto) const SizedBox(height: 12),
                if (isPhoto)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = math.min(420.0, w * 1.1);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: h,
                          loadingBuilder: (context, child, evt) {
                            if (evt == null) return child;
                            final expected = evt.expectedTotalBytes;
                            final progress = expected != null && expected > 0
                                ? (evt.cumulativeBytesLoaded / expected)
                                : null;
                            return Container(
                              color: cs.surfaceVariant,
                              width: double.infinity,
                              height: h,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(value: progress),
                            );
                          },
                        ),
                      );
                    },
                  ),

                // Document chip (if any)
                if (hasDoc) ...[
                  const SizedBox(height: 12),
                  _DocChip(
                    fileName: post.fileName ?? 'Anhang',
                    onTap: () async {
                      final url = post.fileUrl!;
                      if (await canLaunchUrlString(url)) {
                        await launchUrlString(url);
                      }
                    },
                  ),
                ],

                // Action Row
                const SizedBox(height: 12),
                Row(
                  children: [
                    _VoteGroup(
                      isUp: isUp,
                      isDown: isDown,
                      score: score,
                      onUp: currentUserId == null
                          ? null
                          : () => ref
                                .read(postRepositoryProvider)
                                .voteOnPost(
                                  postId: post.id,
                                  userId: currentUserId!,
                                  isUpvote: true,
                                ),
                      onDown: currentUserId == null
                          ? null
                          : () => ref
                                .read(postRepositoryProvider)
                                .voteOnPost(
                                  postId: post.id,
                                  userId: currentUserId!,
                                  isUpvote: false,
                                ),
                    ),
                    const SizedBox(width: 20),
                    _CommentChip(
                      cs: cs,
                      theme: theme,
                      commentCount: commentCount,
                      onTap: widget.onTap,
                    ),
                    const SizedBox(width: 20),
                    _LikeChip(
                      isLiked: isLiked,
                      likeCount: likeCount,
                      cs: cs,
                      theme: theme,
                      onTap: currentUserId == null
                          ? null
                          : () async {
                              if (isLiked) {
                                await ref
                                    .read(postRepositoryProvider)
                                    .removeVote(
                                      postId: post.id,
                                      userId: currentUserId,
                                    );
                              } else {
                                await onLike();
                              }
                            },
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Lesezeichen',
                      onPressed: () =>
                          setState(() => _bookmarked = !_bookmarked),
                      iconSize: 20,
                      icon: Icon(
                        _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(
    BuildContext context,
    ColorScheme cs,
    String? currentUserId,
    String postId, {
    required bool isOwner,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Teilen'),
                onTap: () async {
                  Navigator.of(context).pop();
                  // If you have a deep link, replace with it
                  final shareText = 'Schau dir diesen Beitrag an (ID: $postId)';
                  await Share.share(shareText, subject: 'Beitrag teilen');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Melden'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final reason = await _pickReportReason(context);
                  if (reason == null) return;
                  try {
                    final fs = ref.read(firestoreProvider);
                    await fs.collection('reports').add({
                      'type': 'post',
                      'postId': postId,
                      'reason': reason.reason,
                      'message': reason.message,
                      'createdBy': currentUserId,
                      'createdAt': DateTime.now(),
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meldung gesendet. Danke!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim Melden: $e')),
                      );
                    }
                  }
                },
              ),
              if (isOwner)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Löschen',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Beitrag löschen?'),
                        content: const Text(
                          'Dieser Vorgang kann nicht rückgängig gemacht werden.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Löschen'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await ref
                            .read(postRepositoryProvider)
                            .deletePost(postId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Beitrag gelöscht')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<_ReportResult?> _pickReportReason(BuildContext context) async {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    String selected = 'Spam';
    final result = await showDialog<_ReportResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Beitrag melden'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<String>(
                      value: 'Spam',
                      groupValue: selected,
                      onChanged: (v) => setState(() => selected = v ?? 'Spam'),
                      title: const Text('Spam'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'Anstößiger Inhalt',
                      groupValue: selected,
                      onChanged: (v) =>
                          setState(() => selected = v ?? 'Anstößiger Inhalt'),
                      title: const Text('Anstößiger Inhalt'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'Sonstiges',
                      groupValue: selected,
                      onChanged: (v) =>
                          setState(() => selected = v ?? 'Sonstiges'),
                      title: const Text('Sonstiges'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Zusätzliche Informationen (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    ctx,
                  ).pop(_ReportResult(selected, controller.text.trim())),
                  child: const Text('Senden'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }
}

class _CommentChip extends StatelessWidget {
  const _CommentChip({
    required this.cs,
    required this.theme,
    required this.commentCount,
    this.onTap,
  });
  final ColorScheme cs;
  final ThemeData theme;
  final int commentCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const Icon(
              Icons.mode_comment_outlined,
              size: 20,
              color: _brandBlue,
            ),
            const SizedBox(width: 8),
            Text(
              // simple formatting to match parent helpers not accessible here
              commentCount < 1000
                  ? '$commentCount'
                  : '${(commentCount / 1000).toStringAsFixed(1)}k',
              style: theme.textTheme.labelMedium?.copyWith(color: _brandBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeChip extends StatelessWidget {
  const _LikeChip({
    required this.isLiked,
    required this.likeCount,
    required this.cs,
    required this.theme,
    this.onTap,
  });
  final bool isLiked;
  final int likeCount;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isLiked ? _brandBlue : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              likeCount < 1000
                  ? '$likeCount'
                  : '${(likeCount / 1000).toStringAsFixed(1)}k',
              style: theme.textTheme.labelMedium?.copyWith(color: _brandBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportResult {
  _ReportResult(this.reason, this.message);
  final String reason;
  final String message;
}

class _DocChip extends StatelessWidget {
  const _DocChip({required this.fileName, this.onTap});
  final String fileName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _brandBlue, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 18,
              color: _brandBlue,
            ),
            const SizedBox(width: 8),
            Text(
              fileName,
              style: const TextStyle(fontSize: 13, color: _brandBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteGroup extends StatelessWidget {
  const _VoteGroup({
    required this.isUp,
    required this.isDown,
    required this.score,
    this.onUp,
    this.onDown,
  });

  final bool isUp;
  final bool isDown;
  final int score;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _brandBlue, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onUp,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: isUp ? _brandBlue : cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: TextStyle(
              color: isUp ? _brandBlue : (isDown ? cs.error : cs.onSurface),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 20,
                color: isDown ? cs.error : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
