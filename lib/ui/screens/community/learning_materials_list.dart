import 'dart:async';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/features/community/providers.dart';

import 'learning_materials_detail_screen.dart';
import 'learning_materials_model.dart';
import 'learning_materials_types.dart';
import 'learning_materials_upload_screen.dart';

typedef AnimatedCustomDropdown<T> = CustomDropdown<T>;

class LearningMaterialsListScreen extends ConsumerStatefulWidget {
  const LearningMaterialsListScreen({super.key, required this.type});

  final LearningMaterialTypeData type;

  @override
  LearningMaterialsListScreenState createState() =>
      LearningMaterialsListScreenState();
}

class LearningMaterialsListScreenState
    extends ConsumerState<LearningMaterialsListScreen> {
  static const _pageSize = 20;
  static const _searchDebounce = Duration(milliseconds: 250);
  static const _recentDuration = Duration(days: 30);
  static const List<String> _semesterItems = <String>[
    'Alle',
    'S1',
    'S2',
    'S3',
    'S4',
    'S5',
    'S6',
    'S7',
    'S8',
    'S9',
    'S10',
    'S11',
    'S12',
  ];

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<LearningMaterial> _materials = <LearningMaterial>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _newOnly = false;
  String? _selectedSemester;
  String _searchTerm = '';
  String? _errorMessage;

  late final CommunityUserContext _userContext = ref.read(
    communityUserContextProvider,
  );

  @override
  void initState() {
    super.initState();
    if (_userContext.semester.isNotEmpty &&
        _semesterItems.contains(_userContext.semester)) {
      _selectedSemester = _userContext.semester;
    }
    _searchCtrl.addListener(_handleSearchTextChange);
    _scrollCtrl.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_handleSearchTextChange);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _handleSearchTextChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool resetScroll = false}) async {
    if (_isLoading) return;
    _debounce?.cancel();
    if (resetScroll && _scrollCtrl.hasClients) {
      await _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _materials.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final snapshot = await _buildQuery().limit(_pageSize).get();
      final docs = snapshot.docs.map(LearningMaterial.fromDoc).toList();
      if (!mounted) return;
      setState(() {
        _materials.addAll(docs);
        _hasMore = docs.length == _pageSize;
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      });
    } on FirebaseException catch (err) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            err.message ?? 'Materialien konnten nicht geladen werden.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Materialien konnten nicht geladen werden.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDoc == null) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _buildQuery()
          .limit(_pageSize)
          .startAfterDocument(_lastDoc!)
          .get();
      final docs = snapshot.docs.map(LearningMaterial.fromDoc).toList();
      if (!mounted) return;
      setState(() {
        _materials.addAll(docs);
        _hasMore = docs.length == _pageSize;
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      });
    } on FirebaseException catch (err) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            err.message ?? 'Weitere Materialien konnten nicht geladen werden.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = 'Weitere Materialien konnten nicht geladen werden.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    var query = FirebaseFirestore.instance
        .collection('materials')
        .where('universityCode', isEqualTo: _userContext.universityCode)
        .where('type', isEqualTo: widget.type.value)
        .orderBy('createdAt', descending: true);

    final semester = _selectedSemester;
    if (semester != null && semester.isNotEmpty) {
      query = query.where('semester', isEqualTo: semester);
    }

    if (_newOnly) {
      final cutoff = DateTime.now().subtract(_recentDuration);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
      );
    }

    return query;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      if (_searchTerm.isNotEmpty) {
        setState(() => _searchTerm = '');
      }
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _searchTerm = normalized);
    });
  }

  List<LearningMaterial> get _visibleMaterials {
    if (_searchTerm.isEmpty)
      return List<LearningMaterial>.unmodifiable(_materials);
    return _materials
        .where((material) {
          final title = material.title.toLowerCase();
          final description = material.description.toLowerCase();
          return title.contains(_searchTerm) ||
              description.contains(_searchTerm);
        })
        .toList(growable: false);
  }

  void _selectSemester(String? semester) {
    final normalized = semester == null || semester == 'Alle' ? null : semester;
    if (normalized == _selectedSemester) return;
    setState(() => _selectedSemester = normalized);
    _loadInitial(resetScroll: true);
  }

  void _toggleNewOnly(bool value) {
    if (value == _newOnly) return;
    setState(() => _newOnly = value);
    _loadInitial(resetScroll: true);
  }

  Future<void> _openUpload() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningMaterialUploadScreen(defaultType: widget.type),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hochgeladen')),
      );
      _loadInitial(resetScroll: true);
    }
  }

  Future<void> _openDetail(LearningMaterial material) async {
    final updated = await Navigator.of(context).push<LearningMaterial>(
      MaterialPageRoute(
        builder: (_) => LearningMaterialDetailScreen(
          materialId: material.id,
          initialMaterial: material,
        ),
      ),
    );
    if (updated != null && mounted) {
      final originalIndex = _materials.indexWhere(
        (item) => item.id == updated.id,
      );
      if (originalIndex != -1) {
        setState(() {
          _materials[originalIndex] = updated;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _visibleMaterials;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.label),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Hochladen'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadInitial(resetScroll: true),
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Titel oder Beschreibung suchen…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FilterRow(
                        selectedSemester: _selectedSemester,
                        semesterItems: _semesterItems,
                        onSemesterChanged: _selectSemester,
                        newOnly: _newOnly,
                        onToggleNew: _toggleNewOnly,
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Material(
                      color: theme.colorScheme.errorContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isLoading && _materials.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyMaterialsState(onUpload: _openUpload),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= items.length) {
                        return const SizedBox.shrink();
                      }
                      final material = items[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          index == 0 ? 0 : 8,
                          16,
                          8,
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            onTap: () => _openDetail(material),
                            leading: _MaterialAvatar(material: material),
                            title: Text(
                              material.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${material.uploaderOrFallback} | ${material.views} Aufrufe',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded),
                              onPressed: () => _openDetail(material),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedSemester,
    required this.semesterItems,
    required this.onSemesterChanged,
    required this.newOnly,
    required this.onToggleNew,
  });

  final String? selectedSemester;
  final List<String> semesterItems;
  final ValueChanged<String?> onSemesterChanged;
  final bool newOnly;
  final ValueChanged<bool> onToggleNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final dropdownWidth = isCompact ? constraints.maxWidth : 220.0;

        final dropdown = SizedBox(
          width: dropdownWidth,
          child: AnimatedCustomDropdown<String>(
            hintText: 'Semester',
            items: semesterItems,
            initialItem: selectedSemester ?? 'Alle',
            onChanged: onSemesterChanged,
            decoration: CustomDropdownDecoration(
              closedFillColor: theme.colorScheme.surface,
              closedBorder: Border.all(color: theme.dividerColor),
              expandedBorder: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.4),
                width: 1.5,
              ),
              closedBorderRadius: BorderRadius.circular(16),
              expandedBorderRadius: BorderRadius.circular(16),
              closedSuffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              expandedSuffixIcon: const Icon(Icons.keyboard_arrow_up_rounded),
              hintStyle: theme.textTheme.bodyMedium,
            ),
          ),
        );

        final toggle = FilterChip(
          label: const Text('Neu (30 Tage)'),
          selected: newOnly,
          onSelected: onToggleNew,
        );

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [dropdown, toggle],
        );
      },
    );
  }
}

class _EmptyMaterialsState extends StatelessWidget {
  const _EmptyMaterialsState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 96,
            color: theme.colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Materialien vorhanden.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Starte mit dem ersten Upload für deine Kommiliton:innen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Hochladen'),
          ),
        ],
      ),
    );
  }
}

class _MaterialAvatar extends StatelessWidget {
  const _MaterialAvatar({required this.material});

  final LearningMaterial material;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary.withOpacity(0.12);
    final textColor = theme.colorScheme.primary;

    if (material.thumbnailUrl != null && material.thumbnailUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(material.thumbnailUrl!),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        material.initials,
        style: theme.textTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
