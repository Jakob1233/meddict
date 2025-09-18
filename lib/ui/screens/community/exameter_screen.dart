import 'dart:async';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/data/repositories/exams_repository.dart';
import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/models/exam.dart';
import 'package:flutterquiz/ui/community/exameter/widgets/exam_icon.dart';

typedef AnimatedCustomDropdown<T> = CustomDropdown<T>;

class ExameterScreen extends ConsumerStatefulWidget {
  const ExameterScreen({super.key});

  static Route<ExameterScreen> route() =>
      MaterialPageRoute(builder: (_) => const ExameterScreen());

  @override
  ExameterScreenState createState() => ExameterScreenState();
}

class ExameterScreenState extends ConsumerState<ExameterScreen> {
  static const List<String> _semesterOptions = <String>[
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

  static const int _pageSize = 20;
  static const double _loadMoreThreshold = 160;

  final ScrollController _scrollController = ScrollController();
  final List<Exam> _exams = <Exam>[];

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialLoadCompleted = false;
  String? _errorMessage;
  String? _selectedSemester;

  late final CommunityUserContext _userContext = ref.read(communityUserContextProvider);

  @override
  void initState() {
    super.initState();
    if (_userContext.semester.isNotEmpty && _semesterOptions.contains(_userContext.semester)) {
      _selectedSemester = _userContext.semester;
    }
    _scrollController.addListener(_handleScroll);
    scheduleMicrotask(() => _loadInitial(reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(communityUserContextProvider);
    if (!userContext.hasUniversity) {
      return const _MissingProfileState();
    }

    return Column(
      children: [
        _FilterBar(
          currentSemester: _selectedSemester ?? 'Alle',
          onChanged: _onSemesterChanged,
        ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && !_initialLoadCompleted) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_errorMessage != null && _exams.isEmpty) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: () => _loadInitial(reset: true),
      );
    }

    if (_exams.isEmpty) {
      return _EmptyState(onRefresh: () => _loadInitial(reset: true));
    }

    return RefreshIndicator(
      onRefresh: () => _loadInitial(reset: true),
      color: Theme.of(context).colorScheme.primary,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _exams.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index >= _exams.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          final exam = _exams[index];
          return _ExamListItem(
            exam: exam,
            onTap: () {
              Navigator.of(context).pushNamed(
                Routes.exameterDetail,
                arguments: <String, dynamic>{
                  'examId': exam.id,
                  'exam': exam,
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadInitial({bool reset = false}) async {
    if (_isLoading) return;
    if (_userContext.universityCode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (reset) {
        _exams.clear();
        _lastDocument = null;
        _hasMore = true;
        _initialLoadCompleted = false;
      }
    });

    try {
      final repo = ref.read(examsRepositoryProvider);
      final page = await repo.fetchExamsPage(
        universityCode: _userContext.universityCode,
        semesterFilter: _selectedSemester,
        ordering: ExamsListOrdering.createdAt,
        startAfter: null,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _exams
          ..clear()
          ..addAll(page.exams);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _initialLoadCompleted = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _errorMessage = err.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    if (_lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final repo = ref.read(examsRepositoryProvider);
      final page = await repo.fetchExamsPage(
        universityCode: _userContext.universityCode,
        semesterFilter: _selectedSemester,
        ordering: ExamsListOrdering.createdAt,
        startAfter: _lastDocument,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _exams.addAll(page.exams);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _errorMessage = err.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _handleScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _onSemesterChanged(String? value) {
    final normalized = (value == null || value == 'Alle') ? null : value;
    if (normalized == _selectedSemester) return;
    setState(() => _selectedSemester = normalized);
    _loadInitial(reset: true);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.currentSemester, required this.onChanged});

  final String currentSemester;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropdown = SizedBox(
      width: 200,
      child: AnimatedCustomDropdown<String>(
        hintText: 'Semester',
        items: ExameterScreenState._semesterOptions,
        initialItem: currentSemester,
        onChanged: onChanged,
        decoration: CustomDropdownDecoration(
          closedFillColor: theme.colorScheme.surface,
          closedBorder: Border.all(color: theme.dividerColor.withOpacity(0.4)),
          expandedBorder: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5),
          closedBorderRadius: BorderRadius.circular(18),
          expandedBorderRadius: BorderRadius.circular(18),
          closedSuffixIcon: const Icon(CupertinoIcons.chevron_down),
          expandedSuffixIcon: const Icon(CupertinoIcons.chevron_up),
          hintStyle: theme.textTheme.bodyMedium,
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Exameter',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            dropdown,
          ],
        ),
      ),
    );
  }
}

class _ExamListItem extends StatelessWidget {
  const _ExamListItem({required this.exam, required this.onTap});

  final Exam exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.colorScheme.surface;
    final shadowColor = theme.shadowColor.withOpacity(isDark ? 0.22 : 0.12);

    final semesterLabel = exam.semester.isEmpty ? 'Semester unbekannt' : exam.semester;
    final ratingsLabel = exam.ratingsCount == 0
        ? 'Noch keine Bewertungen'
        : '${exam.ratingsCount} ${exam.ratingsCount == 1 ? 'Bewertung' : 'Bewertungen'}';

    final track = exam.track.toLowerCase();
    final isDent = track.contains('zahn') || track.contains('dent');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildExamIcon(context, exam.title, isDent: isDent),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title.isEmpty ? 'Unbenannte Prüfung' : exam.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$semesterLabel · $ratingsLabel',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Pill(
                          label: 'Score ${exam.compositeScore.round()}',
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          textColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Icon(CupertinoIcons.chat_bubble_text, size: 16, color: theme.iconTheme.color?.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          '${exam.notesCount}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                CupertinoIcons.chevron_forward,
                color: theme.iconTheme.color?.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.textColor});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
      children: [
        Icon(CupertinoIcons.search, size: 64, color: theme.iconTheme.color?.withOpacity(0.35)),
        const SizedBox(height: 20),
        Text(
          'Noch keine Prüfungen in diesem Semester.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Starte mit deiner ersten Bewertung und hilf deiner Community.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 28),
        CupertinoButton.filled(
          onPressed: onRefresh,
          child: const Text('Aktualisieren'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 56, color: theme.colorScheme.error.withOpacity(0.8)),
            const SizedBox(height: 16),
            Text(
              'Exameter konnte nicht geladen werden.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingProfileState extends StatelessWidget {
  const _MissingProfileState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_crop_circle_badge_exclam, size: 72, color: theme.iconTheme.color?.withOpacity(0.45)),
            const SizedBox(height: 18),
            Text(
              'Profil unvollständig',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Bitte wähle deine Uni und dein Semester im Profil, um Exameter zu nutzen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
