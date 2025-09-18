// COMMUNITY 3.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

import '../../providers.dart';
import '../../data/models/room_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_error.dart';
import '../widgets/post_card.dart';
import 'post_detail_page.dart';

// Sorting option for community lists
enum SortOption { newest, upvotes }

class RoomDetailPage extends ConsumerStatefulWidget {
  // COMMUNITY 3.0
  const RoomDetailPage({super.key, required this.roomId});

  final String roomId;

  static Route<RoomDetailPage> route({required String roomId}) =>
      MaterialPageRoute(builder: (_) => RoomDetailPage(roomId: roomId));

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  // COMMUNITY 3.0
  final TextEditingController _composerCtrl = TextEditingController();
  bool _posting = false;

  // Sorting & search state (per screen instance)
  final ScrollController _feedCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  SortOption _sort = SortOption.newest;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    // Rebuild UI when the composer text changes so the Post button enables/disables correctly
    _composerCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    _feedCtrl.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomAsync = ref.watch(roomProvider(widget.roomId)); // COMMUNITY 3.0
    final postsAsync = ref.watch(roomFeedProvider(widget.roomId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: roomAsync.when(
          data: (r) => Text(r?.name ?? 'Room', style: theme.textTheme.titleLarge),
          loading: () => Text('Room', style: theme.textTheme.titleLarge),
          error: (e, _) => Text('Room', style: theme.textTheme.titleLarge),
        ),
        actions: [
          _SortMenuRoom(
            value: _sort,
            onChanged: (v) {
              setState(() => _sort = v);
              if (_feedCtrl.hasClients) {
                _feedCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header with image
              roomAsync.when(
                data: (room) => _RoomHeader(room: room),
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              // Search field under dropdown/appbar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (txt) {
                    // Update UI immediately for clear icon visibility
                    setState(() {});
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      setState(() => _searchText = txt.trim());
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Stichwort suchen…',
                    isDense: true,
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchText = '');
                              if (_feedCtrl.hasClients) {
                                _feedCtrl.animateTo(0, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
                              }
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear',
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              // Feed
              Expanded(
                child: postsAsync.when(
                  data: (posts) {
                    // Sort first (query provides newest by default; upvotes in-memory)
                    final sorted = [...posts];
                    if (_sort == SortOption.upvotes) {
                      sorted.sort((a, b) {
                        final c = b.upvotes.compareTo(a.upvotes);
                        if (c != 0) return c;
                        return b.createdAt.toDate().compareTo(a.createdAt.toDate());
                      });
                    } else {
                      sorted.sort((a, b) => b.createdAt.toDate().compareTo(a.createdAt.toDate()));
                    }

                    // Then filter by search text
                    final q = _searchText.toLowerCase();
                    final filtered = q.isEmpty
                        ? sorted
                        : sorted.where((p) {
                            final t = (p.title).toLowerCase();
                            final b = (p.body).toLowerCase();
                            return t.contains(q) || b.contains(q);
                          }).toList();

                    if (filtered.isEmpty) {
                      return Center(child: Text('Noch keine Posts', style: theme.textTheme.bodyMedium));
                    }
                    return ListView.separated(
                      controller: _feedCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => PostCard(
                        post: filtered[i],
                        onTap: () => Navigator.of(context).push(PostDetailPage.route(postId: filtered[i].id)),
                      ),
                    );
                  },
                  loading: () => const AppLoader(),
                  error: (e, st) => AppError(message: 'Fehler beim Laden der Posts.\n$e'),
                ),
              ),
            ],
          ),

          // Bottom pinned composer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: RoomComposerBar(
                  controller: _composerCtrl,
                  enabled: userId != null && !_posting,
                  onPost: (String? localImagePath, String? localFilePath) async {
                    if (userId == null || _posting) return;
                    final text = _composerCtrl.text.trim();
                    if (text.isEmpty && (localImagePath == null && localFilePath == null)) {
                      return; // nothing to post
                    }
                    setState(() => _posting = true);
                    try {
                      await ref.read(postRepositoryProvider).createRoomPost(
                            roomId: widget.roomId,
                            createdBy: userId,
                            body: text,
                            localImagePath: localImagePath,
                            localFilePath: localFilePath,
                          );
                      _composerCtrl.clear();
                    } finally {
                      if (mounted) setState(() => _posting = false);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenuRoom extends StatelessWidget {
  const _SortMenuRoom({required this.value, required this.onChanged});
  final SortOption value;
  final ValueChanged<SortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: SizedBox(
        width: 156,
        child: AppDropdown<SortOption>(
          hintText: 'Sortieren…',
          items: const [SortOption.newest, SortOption.upvotes],
          itemLabel: (option) => option == SortOption.newest ? 'Neueste' : 'Upvotes',
          value: value,
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
          searchable: false,
          borderRadius: 16,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  // COMMUNITY 3.0
  const _RoomHeader({required this.room});
  final Room? room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (room == null) return const SizedBox.shrink();
    final hasAsset = room!.imageAsset.startsWith('assets/'); // COMMUNITY 3.0
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.shadowColor, blurRadius: 8, offset: const Offset(0, 4))],
        image: hasAsset
            ? DecorationImage(image: AssetImage(room!.imageAsset), fit: BoxFit.cover)
            : null, // COMMUNITY 3.0
        gradient: hasAsset ? null : LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer]), // COMMUNITY 3.0
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: cs.scrim.withOpacity(0.15)))),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room!.name, style: theme.textTheme.titleLarge?.copyWith(color: cs.onPrimary)),
                const SizedBox(height: 4),
                Text('${room!.topic} • ${room!.semester}', style: theme.textTheme.labelLarge?.copyWith(color: cs.onPrimary)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _ComposerCard extends ConsumerWidget {
  const _ComposerCard({
    required this.isPosting,
    required this.userId,
    required this.controller,
    required this.onPost,
    required this.onChanged,
  });

  final bool isPosting;
  final String? userId;
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = controller.text.trim();

    CircleAvatar avatarWidget() {
      final userMap = ref.watch(userCacheProvider);
      if (userId != null) ref.read(userCacheProvider.notifier).ensure(userId!);
      final user = userId != null ? userMap[userId!] : null;
      final display = user?.displayName ?? 'U';
      final initials = display.trim().isNotEmpty ? display.trim()[0].toUpperCase() : 'U';
      final photo = user?.photoURL;
      final bg = cs.primary.withOpacity(0.1);
      if (photo != null && photo.isNotEmpty) {
        return CircleAvatar(radius: 16, backgroundImage: NetworkImage(photo), backgroundColor: bg);
      }
      return CircleAvatar(radius: 16, backgroundColor: bg, child: Text(initials, style: theme.textTheme.labelSmall));
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.12), width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatarWidget(),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: "What's Happening?", border: InputBorder.none),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Left icons
              _OutlinedIconButton(icon: Icons.image_outlined, tooltip: 'Bild hinzufügen', onTap: () {}),
              _GifChip(),

              const Spacer(),

              // Right Post button
              FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: userId == null || isPosting || text.isEmpty ? null : onPost,
                child: const Text('Posten'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GifChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(6),
            color: cs.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('GIF', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _OutlinedIconButton extends StatelessWidget {
  const _OutlinedIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(6),
              color: cs.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class RoomComposerBar extends StatefulWidget {
  const RoomComposerBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPost,
  });

  final TextEditingController controller;
  final bool enabled;
  final Future<void> Function(String? localImagePath, String? localFilePath) onPost;

  @override
  State<RoomComposerBar> createState() => _RoomComposerBarState();
}

class _RoomComposerBarState extends State<RoomComposerBar> {
  String? _localImagePath;
  String? _localFilePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2563FF), width: 1),
          boxShadow: [
            const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            BoxShadow(color: const Color(0xFF2563FF).withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Anhang',
              icon: const Icon(Icons.attach_file, color: Color(0xFF2563FF)),
              onPressed: () => _pickAttachment(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: (_) {
                  setState(() {});
                },
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Was möchtest du teilen?',
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_localImagePath != null || _localFilePath != null)
              _AttachmentPreview(
                imagePath: _localImagePath,
                filePath: _localFilePath,
                onClear: () => setState(() {
                  _localImagePath = null;
                  _localFilePath = null;
                }),
              ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.enabled &&
                      ((widget.controller.text.trim().isNotEmpty) || _localImagePath != null || _localFilePath != null)
                  ? () async {
                      final img = _localImagePath;
                      final file = _localFilePath;
                      await widget.onPost(img, file);
                      if (mounted) {
                        setState(() {
                          _localImagePath = null;
                          _localFilePath = null;
                        });
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: const Color(0xFF2563FF),
              ),
              child: const Text('Posten'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAttachment(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Foto auswählen'),
              onTap: () => Navigator.of(ctx).pop('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.gif_box_outlined),
              title: const Text('GIF auswählen'),
              onTap: () => Navigator.of(ctx).pop('gif'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Dokument auswählen'),
              onTap: () => Navigator.of(ctx).pop('doc'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'photo') {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file != null) {
        setState(() {
          _localImagePath = file.path;
          _localFilePath = null;
        });
      }
    } else if (choice == 'gif' || choice == 'doc') {
      final result = await FilePicker.platform.pickFiles(
        type: choice == 'gif' ? FileType.custom : FileType.any,
        allowedExtensions: choice == 'gif' ? ['gif'] : null,
      );
      if (result != null && result.files.single.path != null) {
        final p = result.files.single.path!;
        setState(() {
          if (choice == 'gif') {
            _localImagePath = p; // treat GIF as image
            _localFilePath = null;
          } else {
            _localFilePath = p;
            _localImagePath = null;
          }
        });
      }
    }
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({this.imagePath, this.filePath, required this.onClear});
  final String? imagePath;
  final String? filePath;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isImage = imagePath != null;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2563FF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 16, color: const Color(0xFF2563FF)),
        const SizedBox(width: 6),
        Text(isImage ? 'Bild ausgewählt' : (filePath?.split('/').last ?? 'Dokument'), style: const TextStyle(fontSize: 12, color: Color(0xFF2563FF))),
        const SizedBox(width: 6),
        GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 14, color: Color(0xFF2563FF))),
      ]),
    );
  }
}
