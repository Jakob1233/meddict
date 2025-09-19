// COMMUNITY 3.0
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

import '../../providers.dart'; // COMMUNITY 3.0

class CreateRoomPage extends ConsumerStatefulWidget {
  // COMMUNITY 3.0
  const CreateRoomPage({super.key});

  static Route<CreateRoomPage> route() =>
      MaterialPageRoute(builder: (_) => const CreateRoomPage());

  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  // COMMUNITY 3.0
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _imageAsset;
  String? _semester;
  String? _topic;
  bool _saving = false;

  static const List<String> kRoomAssets = [
    'assets/images/rooms/room_01.png',
    'assets/images/rooms/room_02.png',
    'assets/images/rooms/room_03.png',
    'assets/images/rooms/room_04.png',
    'assets/images/rooms/room_05.png',
    'assets/images/rooms/room_06.png',
    'assets/images/rooms/room_07.png',
    'assets/images/rooms/room_08.png',
    'assets/images/rooms/room_09.png',
    'assets/images/rooms/room_10.png',
  ];

  static final List<String> kSemesters = [
    'unspezifisch',
    ...List.generate(12, (i) => 'S${i + 1}'),
  ];

  static const List<(String value, String label)> kTopics = [
    ('prüfung', 'Prüfung'),
    ('allgemein', 'Allgemein'),
    ('klassengruppe', 'Klassengruppe'),
    ('clerkship', 'Clerkship'),
    ('famulatur', 'Famulatur'),
    ('innere', 'Innere'),
    ('chirurgie', 'Chirurgie'),
    ('pharma', 'Pharma'),
    ('radiologie', 'Radiologie'),
    ('notfall', 'Notfall'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Room',
          style: theme.textTheme.titleLarge,
        ), // COMMUNITY 3.0
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name*'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name erforderlich' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('Bild auswählen*', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kRoomAssets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (_, i) {
                final asset = kRoomAssets[i];
                final selected = _imageAsset == asset;
                return InkWell(
                  onTap: () => setState(() => _imageAsset = asset),
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(asset),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: selected ? cs.primary : cs.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Icon(Icons.check_circle, color: cs.primary),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Semester*',
              hintText: 'Semester wählen…',
              items: kSemesters,
              itemLabel: (s) => s,
              value: _semester,
              onChanged: (v) => setState(() => _semester = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Bitte wählen' : null,
              borderRadius: 16,
            ),
            const SizedBox(height: 12),
            AppDropdown<String>(
              label: 'Topic*',
              hintText: 'Topic wählen…',
              items: kTopics.map((t) => t.$1).toList(),
              itemLabel: (value) => kTopics
                  .firstWhere((t) => t.$1 == value, orElse: () => kTopics.first)
                  .$2,
              value: _topic,
              onChanged: (v) => setState(() => _topic = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Bitte wählen' : null,
              borderRadius: 16,
            ),
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
    if (!_formKey.currentState!.validate() || _imageAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Pflichtfelder ausfüllen')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      final id = await ref
          .read(roomRepositoryProvider)
          .createRoom(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            createdBy: uid,
            imageAsset: _imageAsset!,
            semester: _semester!,
            topic: _topic!,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Room erstellt')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
