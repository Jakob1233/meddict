import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/features/community/data/models/post_model.dart';

class CommunityPostCard extends ConsumerWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onOpenReference,
    this.dense = false,
  });

  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onOpenReference;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentUserId = ref.watch(currentUserIdProvider);
    final repo = ref.read(postRepositoryProvider);
    final userMap = ref.watch(userCacheProvider);
    ref.read(userCacheProvider.notifier).ensure(post.createdBy);
    final appUser = userMap[post.createdBy];
    final authorName = post.authorName ?? appUser?.displayName ?? 'Anonym';
    final avatarUrl = post.authorAvatarUrl ?? appUser?.photoURL;
    final isUpvoted = post.upvoters.contains(currentUserId);
    final createdAt = post.createdAt.toDate();

    Future<void> handleUpvote() async {
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte logge dich ein, um zu upvoten.')),
        );
        return;
      }
      await repo.toggleVote(postId: post.id, userId: currentUserId, isUpvote: true);
    }

    void handleShare() {
      final subject = '[Elite Quiz] ${post.title}'.trim();
      final buffer = StringBuffer()
        ..writeln(post.title)
        ..writeln()
        ..writeln(post.body.trim());
      Share.share(buffer.toString(), subject: subject);
    }

    Widget buildAvatar() {
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        return CircleAvatar(radius: dense ? 16 : 20, backgroundImage: NetworkImage(avatarUrl));
      }
      final initials = _initials(authorName);
      return CircleAvatar(
        radius: dense ? 16 : 20,
        backgroundColor: cs.primary.withOpacity(0.15),
        child: Text(initials, style: theme.textTheme.labelMedium?.copyWith(color: cs.primary)),
      );
    }

    final category = post.category ?? 'Divers';
    final semester = post.semester;
    final type = post.type;
    final hasReference = post.refId != null && post.refId!.isNotEmpty;
    final meta = post.meta ?? const {};

    final bodySnippet = post.body.trim();
    final metaSection = _buildMetaSection(type, meta, theme, cs);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: dense ? 0 : 12, vertical: dense ? 8 : 12),
        padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 20, vertical: dense ? 16 : 20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: cs.primary.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_relativeTime(createdAt), style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: handleShare,
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Teilen',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (bodySnippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                bodySnippet,
                maxLines: dense ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (metaSection != null) ...[
              const SizedBox(height: 12),
              metaSection,
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Badge(label: category, color: cs.primary),
                if (semester != null && semester.isNotEmpty) _Badge(label: semester, color: cs.secondary),
                _Badge(label: _mapTypeLabel(type), color: cs.tertiaryContainer, textColor: cs.onTertiaryContainer),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ActionChip(
                  icon: Icons.thumb_up_alt_outlined,
                  activeIcon: Icons.thumb_up_alt,
                  label: post.upvotesCount.toString(),
                  active: isUpvoted,
                  onTap: handleUpvote,
                ),
                const SizedBox(width: 12),
                _ActionChip(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: post.commentsCount.toString(),
                  onTap: onTap,
                ),
                const Spacer(),
                if (hasReference)
                  TextButton.icon(
                    onPressed: onOpenReference ?? () => _openReference(context, post),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Zur Frage/Karte'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _openReference(BuildContext context, PostModel post) {
    final refId = post.refId;
    if (refId == null || refId.isEmpty) return;
    final refType = post.refType;
    if (refType == 'quiz') {
      Navigator.of(context).pushNamed(Routes.quiz, arguments: {'quizId': refId});
    } else if (refType == 'flashcard') {
      Navigator.of(context).pushNamed('/flashcards', arguments: {'deckId': refId});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verknüpfung nicht verfügbar.')),
      );
    }
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'U';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  static String _mapTypeLabel(String type) {
    switch (type) {
      case 'exam_tip':
        return 'Examens-Tipp';
      case 'experience':
        return 'Erfahrung';
      case 'question':
      default:
        return 'Frage';
    }
  }

  Widget? _buildMetaSection(String type, Map<String, dynamic> meta, ThemeData theme, ColorScheme cs) {
    if (type == 'exam_tip') {
      final bullets = (meta['bullets'] as List?)?.cast<String>() ?? const [];
      if (bullets.isEmpty) return null;
      final subset = bullets.take(dense ? 3 : bullets.length).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta['examKind'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Prüfung: ${meta['examKind']}',
                style: theme.textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ...subset.map((tip) => _BulletRow(text: tip)).toList(),
        ],
      );
    }

    if (type == 'experience') {
      final institution = (meta['institution'] ?? '').toString();
      final location = (meta['location'] ?? '').toString();
      final duration = (meta['duration'] ?? meta['zeitraum'] ?? '').toString();
      final lessons = (meta['lessonLearned'] ?? meta['whatINeeded'] ?? '').toString();
      final tips = (meta['tips'] as List?)?.cast<String>().where((t) => t.trim().isNotEmpty).toList() ?? const [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (institution.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                institution,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          if (location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(location, style: theme.textTheme.labelMedium)),
                ],
              ),
            ),
          if (duration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(duration, style: theme.textTheme.labelMedium)),
                ],
              ),
            ),
          if (tips.isNotEmpty)
            ...tips.take(dense ? 2 : tips.length).map((tip) => _BulletRow(text: tip)).toList(),
          if (lessons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Was ich gern früher gewusst hätte:\n$lessons',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      );
    }

    return null;
  }

  static String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w';
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.textColor});

  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor ?? color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = active ? cs.primary.withOpacity(0.12) : cs.surfaceVariant.withOpacity(0.5);
    final iconColor = active ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: iconColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('•', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
