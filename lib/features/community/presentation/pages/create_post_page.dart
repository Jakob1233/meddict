// COMMUNITY INTEGRATION
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../../community/providers.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  static Route<CreatePostPage> route() =>
      MaterialPageRoute(builder: (_) => const CreatePostPage());

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _type = 'post';
  File? _image;

  static const Map<String, String> _typeLabels = {
    'post': 'Post',
    'qa': 'Q&A',
    'exam': 'Exam',
    'clerkship': 'Clerkship',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post', style: theme.textTheme.titleLarge),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(labelText: 'Body'),
              minLines: 5,
              maxLines: 10,
            ),
            const SizedBox(height: 12),
            AppDropdown<String>(
              label: 'Type',
              hintText: 'Type auswählen…',
              items: _typeLabels.keys.toList(),
              itemLabel: (value) => _typeLabels[value] ?? value,
              value: _type,
              onChanged: (v) => setState(() => _type = v ?? 'post'),
              searchable: false,
              borderRadius: 16,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 160, fit: BoxFit.cover),
              ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Add Photo'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    try {
                      await ref.read(
                        createPostProvider((
                          title: _titleCtrl.text.trim(),
                          body: _bodyCtrl.text.trim(),
                          tags: _tagsCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          type: _type,
                          communityId: null,
                          imageFile: _image,
                        )).future,
                      );
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
