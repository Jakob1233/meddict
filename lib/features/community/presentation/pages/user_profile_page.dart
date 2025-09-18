// COMMUNITY 2.0
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class UserProfilePage extends ConsumerWidget {
  // COMMUNITY 2.0
  const UserProfilePage({super.key, required this.userId});

  final String userId;

  static Route<UserProfilePage> route(String uid) {
    return MaterialPageRoute(builder: (_) => UserProfilePage(userId: uid));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.read(userCacheProvider.notifier).ensure(userId);
    final user = ref.watch(userCacheProvider)[userId];
    return Scaffold(
      appBar: AppBar(title: Text(user?.displayName ?? 'Profil', style: theme.textTheme.titleLarge)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? Text((user?.displayName ?? 'U')[0].toUpperCase()) : null,
            ),
            const SizedBox(height: 12),
            Text(user?.displayName ?? 'User', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

