// COMMUNITY UI
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../data/models/uni_event.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_error.dart';
import 'create_event_page.dart'; // COMMUNITY 3.0

class EventsPage extends ConsumerStatefulWidget {
  // COMMUNITY UI
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  // COMMUNITY UI
  bool upcoming = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final eventsAsync = ref.watch(
      upcoming ? eventsUpcomingProvider : eventsPastProvider,
    ); // COMMUNITY UI
    final userId = ref.watch(currentUserIdProvider);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Events',
                  style: theme.textTheme.titleLarge,
                ), // COMMUNITY UI
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search events…', // COMMUNITY UI
                    suffixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegButton(
                        // COMMUNITY UI
                        active: upcoming,
                        text: 'Upcoming',
                        onTap: () => setState(() => upcoming = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegButton(
                        active: !upcoming,
                        text: 'Past',
                        onTap: () => setState(() => upcoming = false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: eventsAsync.when(
                  data: (items) {
                    final filtered = _query.isEmpty
                        ? items
                        : items
                              .where(
                                (e) =>
                                    e.title.toLowerCase().contains(_query) ||
                                    (e.location ?? '').toLowerCase().contains(
                                      _query,
                                    ),
                              )
                              .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'Keine Events',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) =>
                          EventCard(e: filtered[i]), // COMMUNITY UI
                    );
                  },
                  loading: () => const AppLoader(),
                  error: (e, st) =>
                      AppError(message: 'Fehler beim Laden der Events.\n$e'),
                ),
              ),
            ],
          ),
          if (userId != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => Navigator.of(
                  context,
                ).push(CreateEventPage.route()), // COMMUNITY 3.0
                icon: const Icon(Icons.add),
                label: const Text('Add event'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCreateEvent(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    DateTime? startAt;
    DateTime? endAt;
    File? image;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Neues Event', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Titel'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung',
                      ),
                      maxLines: 3,
                    ),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(labelText: 'Ort'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 5),
                                initialDate: now,
                              );
                              if (picked != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  startAt = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  setState(() {});
                                }
                              }
                            },
                            child: Text(
                              startAt == null
                                  ? 'Start wählen'
                                  : DateFormat(
                                      'EEE, dd.MM. HH:mm',
                                    ).format(startAt!),
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
                              if (startAt == null) return;
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: startAt!,
                                lastDate: DateTime(startAt!.year + 5),
                                initialDate: startAt!,
                              );
                              if (picked != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  endAt = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  setState(() {});
                                }
                              }
                            },
                            child: Text(
                              endAt == null
                                  ? 'Ende (optional)'
                                  : DateFormat(
                                      'EEE, dd.MM. HH:mm',
                                    ).format(endAt!),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final uid = ref.read(currentUserIdProvider);
                        if (uid == null) return;
                        if (titleCtrl.text.trim().isEmpty || startAt == null)
                          return;
                        await ref
                            .read(eventRepositoryProvider)
                            .create(
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              startAt: startAt!,
                              endAt: endAt,
                              location: locCtrl.text.trim().isEmpty
                                  ? null
                                  : locCtrl.text.trim(),
                              createdBy: uid,
                              image: image,
                            );
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Event hinzufügen'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SegButton extends StatelessWidget {
  // COMMUNITY UI
  const _SegButton({
    required this.active,
    required this.text,
    required this.onTap,
  });
  final bool active;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: active ? cs.primary : cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: active ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  // COMMUNITY UI
  final UniEvent e;
  const EventCard({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: cs.onPrimary,
    );
    final dateStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onPrimary,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        image: e.imageUrl != null
            ? DecorationImage(
                image: NetworkImage(e.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
        gradient: e.imageUrl == null
            ? LinearGradient(
                colors: [cs.primaryContainer, cs.secondaryContainer],
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Overlay for readability on images
          if (e.imageUrl != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.scrim.withOpacity(0.25),
                ), // COMMUNITY UI
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEE, dd.MM. HH:mm').format(e.startAt),
                  style: dateStyle,
                ),
                if ((e.location ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: cs.onPrimary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          e.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dateStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
