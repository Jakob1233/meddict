// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../community/providers.dart';
import '../../../community/data/models/community_model.dart';

class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});

  static Route<CreateCommunityPage> route() =>
      MaterialPageRoute(builder: (_) => const CreateCommunityPage());

  @override
  ConsumerState<CreateCommunityPage> createState() =>
      _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Community', style: theme.textTheme.titleLarge),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: userId == null
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final repo = ref.read(communityRepositoryProvider);
                      await repo.createCommunity(
                        CommunityModel(
                          id: '',
                          name: _nameCtrl.text.trim(),
                          description: _descCtrl.text.trim(),
                          createdBy: userId,
                          createdAt: Timestamp.now(),
                          members: [userId],
                          moderators: [userId],
                        ),
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
