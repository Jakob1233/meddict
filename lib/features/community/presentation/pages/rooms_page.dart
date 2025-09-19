// COMMUNITY UI
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../data/models/room_model.dart'; // COMMUNITY UI
import '../widgets/app_loader.dart';
import '../widgets/app_error.dart';
import 'create_room_page.dart'; // COMMUNITY 3.0
import 'room_detail_page.dart'; // COMMUNITY 3.0

class RoomsPage extends ConsumerStatefulWidget {
  // COMMUNITY UI
  const RoomsPage({super.key});

  @override
  ConsumerState<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends ConsumerState<RoomsPage> {
  // COMMUNITY UI
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static const demoRooms = <String>[
    // COMMUNITY UI
    'Famulatur',
    'Clerkship',
    'Pharma',
    'Innere',
    'Graz',
    'Floridsdorf',
    'Radiologie',
    'Notfall',
  ];

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
    final roomsAsync = ref.watch(roomsProvider); // COMMUNITY UI

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Rooms', style: theme.textTheme.titleLarge),
                ), // COMMUNITY 3.0
                IconButton(
                  tooltip: 'Create Room',
                  onPressed: _openCreateRoom, // COMMUNITY 3.0
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search rooms…', // COMMUNITY UI
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
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
          const SizedBox(height: 12),
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                // COMMUNITY UI: Fallback demo rooms if collection empty
                final items = rooms.isEmpty
                    ? demoRooms.map((n) => (_RoomItem(id: n, name: n))).toList()
                    : rooms
                          .map(
                            (r) => _RoomItem(
                              id: r.id,
                              name: r.name,
                              imageAsset: r.imageAsset,
                            ),
                          )
                          .toList();

                final filtered = _query.isEmpty
                    ? items
                    : items
                          .where((it) => it.name.toLowerCase().contains(_query))
                          .toList();

                if (filtered.isEmpty) {
                  return _EmptyRooms(
                    onCreate: _openCreateRoom,
                  ); // COMMUNITY 3.0
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final room = filtered[i];
                    return _RoomCard(
                      // COMMUNITY UI
                      title: room.name,
                      index: i,
                      imageAsset: room.imageAsset,
                      onTap: () {
                        Navigator.of(context).push(
                          RoomDetailPage.route(roomId: room.id),
                        ); // COMMUNITY 3.0
                      },
                    );
                  },
                );
              },
              loading: () => const AppLoader(), // COMMUNITY UI
              error: (e, st) => AppError(
                message: 'Failed to load rooms.\n$e',
                onRetry: () => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomItem {
  // COMMUNITY UI
  const _RoomItem({required this.id, required this.name, this.imageAsset});
  final String id;
  final String name;
  final String? imageAsset; // COMMUNITY 3.0
}

class _RoomCard extends StatelessWidget {
  // COMMUNITY UI
  const _RoomCard({
    required this.title,
    required this.index,
    required this.onTap,
    this.imageAsset,
  });
  final String title;
  final int index;
  final VoidCallback onTap;
  final String? imageAsset; // COMMUNITY 3.0

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final gradients = [
      [cs.primary, cs.tertiary],
      [cs.secondary, cs.primaryContainer],
      [cs.tertiary, cs.secondaryContainer],
    ];
    final colors = gradients[index % gradients.length];

    final icons = [
      Icons.local_hospital,
      Icons.school,
      Icons.science,
      Icons.biotech,
      Icons.medical_services,
    ];
    final icon = icons[index % icons.length];

    final hasAsset =
        imageAsset != null &&
        imageAsset!.startsWith('assets/'); // COMMUNITY 3.0
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: !hasAsset
              ? LinearGradient(colors: colors)
              : null, // COMMUNITY 3.0
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          image: hasAsset
              ? DecorationImage(
                  image: AssetImage(imageAsset!),
                  fit: BoxFit.cover,
                )
              : null, // COMMUNITY 3.0
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // COMMUNITY UI: subtle decorative wave
            Positioned(
              right: -40,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onPrimary.withOpacity(
                    hasAsset ? 0.12 : 0.08,
                  ), // COMMUNITY 3.0
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  Icon(icon, color: cs.onPrimary.withOpacity(0.9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  // COMMUNITY UI
  const _EmptyRooms({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No rooms yet. Create one',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onCreate,
                child: const Text('Create room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _RoomsPageState {
  // COMMUNITY 3.0: open page to create room
  Future<void> _openCreateRoom() async {
    await Navigator.of(context).push(CreateRoomPage.route());
  }
}
