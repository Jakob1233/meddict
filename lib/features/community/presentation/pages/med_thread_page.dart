// COMMUNITY 2.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

import '../../providers.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_error.dart';
import '../widgets/post_card.dart';
import 'create_post_page.dart';
import 'post_detail_page.dart';

// Sorting option for community lists
enum SortOption { newest, upvotes }

class MedThreadPage extends ConsumerStatefulWidget {
  // COMMUNITY UI
  const MedThreadPage({super.key});

  static Route<MedThreadPage> route() =>
      MaterialPageRoute(builder: (_) => const MedThreadPage());

  @override
  MedThreadPageState createState() => MedThreadPageState();
}

class MedThreadPageState extends ConsumerState<MedThreadPage> {
  final _controller = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  SortOption _sort = SortOption.newest;
  String _searchText = '';

  void onTapTab() {
    if (_controller.hasClients) {
      _controller.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(medThreadProvider); // COMMUNITY UI
    final userId = ref.watch(currentUserIdProvider);

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text('MedThread', style: theme.textTheme.titleLarge)), // COMMUNITY UI
                // Sort dropdown (top-right)
                _SortMenu(
                  value: _sort,
                  onChanged: (v) {
                    setState(() => _sort = v);
                    // Scroll to top on sort change
                    if (_controller.hasClients) {
                      _controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Create Post',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: userId == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(CreatePostPage.route());
                        },
                ),
              ],
            ),
          ),
          // Search field under dropdown/title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                          if (_controller.hasClients) {
                            _controller.animateTo(0, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
                          }
                        },
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: feedAsync.when(
              data: (posts) {
                // Sort first (query delivers newest by default; apply in-memory for upvotes)
                final sorted = [...posts];
                if (_sort == SortOption.upvotes) {
                  sorted.sort((a, b) {
                    final c = b.upvotes.compareTo(a.upvotes);
                    if (c != 0) return c;
                    return b.createdAt.toDate().compareTo(a.createdAt.toDate());
                  });
                } else {
                  // Ensure newest first as safety
                  sorted.sort((a, b) => b.createdAt.toDate().compareTo(a.createdAt.toDate()));
                }

                // Then filter in-memory if search active
                final query = _searchText.toLowerCase();
                final filtered = query.isEmpty
                    ? sorted
                    : sorted.where((p) {
                        final t = (p.title).toLowerCase();
                        final b = (p.body).toLowerCase();
                        return t.contains(query) || b.contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No posts yet', style: theme.textTheme.bodyMedium),
                  );
                }
                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () async {
                    await Future<void>.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.separated(
                    controller: _controller,
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(bottom: 96, left: 12, right: 12),
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => PostCard(
                      post: filtered[i],
                      onTap: () => Navigator.of(context).push(PostDetailPage.route(postId: filtered[i].id)),
                    ),
                  ),
                );
              },
              loading: () => const AppLoader(), // COMMUNITY UI
              error: (e, st) => AppError(message: 'Failed to load feed.\n$e'), // COMMUNITY UI
            ),
          ),
        ],
      ),
    );
  }
}

// Lightweight popup sort menu to match existing style
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});
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
