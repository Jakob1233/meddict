// COMMUNITY 3.0
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

import '../../providers.dart'; // COMMUNITY 3.0

class CreateEventPage extends ConsumerStatefulWidget {
  // COMMUNITY 3.0
  const CreateEventPage({super.key});

  static Route<CreateEventPage> route() =>
      MaterialPageRoute(builder: (_) => const CreateEventPage());

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  // COMMUNITY 3.0
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  XFile? _image;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Event',
          style: theme.textTheme.titleLarge,
        ), // COMMUNITY 3.0
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titel*'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titel erforderlich' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locCtrl,
              decoration: const InputDecoration(labelText: 'Ort'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 5),
                        initialDate: now,
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          setState(
                            () => _startAt = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      _startAt == null
                          ? 'Start wählen*'
                          : DateFormat('EEE, dd.MM. HH:mm').format(_startAt!),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (_startAt == null) return;
                      final d = await showDatePicker(
                        context: context,
                        firstDate: _startAt!,
                        lastDate: DateTime(_startAt!.year + 5),
                        initialDate: _startAt!,
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          setState(
                            () => _endAt = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      _endAt == null
                          ? 'Ende (optional)'
                          : DateFormat('EEE, dd.MM. HH:mm').format(_endAt!),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (img != null) setState(() => _image = img);
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Bild wählen'),
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Entfernen',
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_image!.path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressContainer(size: 18),
                    )
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _startAt == null) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      await ref
          .read(eventRepositoryProvider)
          .createEvent(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            startAt: _startAt!,
            endAt: _endAt,
            location: _locCtrl.text.trim().isEmpty
                ? null
                : _locCtrl.text.trim(),
            createdBy: uid,
            imageFile: _image,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event erstellt')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
