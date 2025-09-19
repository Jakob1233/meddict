import 'package:flutter/material.dart';

import '../topic_channel_screen.dart';

class CommunitySubjectsTab extends StatelessWidget {
  const CommunitySubjectsTab({super.key});

  static const List<String> _categories = [
    'Anatomie',
    'Physiologie',
    'Biochemie',
    'Pathologie',
    'Pharmakologie',
    'Innere Medizin',
    'Kardiologie',
    'Gastroenterologie',
    'Pneumologie',
    'Neurologie',
    'Chirurgie',
    'Gynäkologie',
    'Pädiatrie',
    'Psychiatrie',
    'Radiologie',
    'Allgemeinmedizin',
    'Divers',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: _categories
            .map(
              (category) => _SubjectTile(
                label: category,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TopicChannelScreen(category: category),
                    ),
                  );
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withOpacity(0.9), cs.primary.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Öffne Fach-Threads & Tipps',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onPrimary.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
