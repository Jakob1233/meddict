import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/data/repositories/exams_repository.dart';
import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/models/exam.dart';
import 'package:flutterquiz/models/exam_note.dart';
import 'package:flutterquiz/models/exam_rating.dart';
import 'package:flutterquiz/ui/widgets/charts/gauge_effort_chart.dart';
import 'package:flutterquiz/ui/widgets/charts/ring_triplet_chart.dart';

class ExameterDetailScreen extends ConsumerStatefulWidget {
  const ExameterDetailScreen({super.key, required this.examId, this.initialExam});

  final String examId;
  final Exam? initialExam;

  static Route<ExameterDetailScreen> route({required String examId, Exam? initialExam}) {
    return MaterialPageRoute(
      builder: (_) => ExameterDetailScreen(examId: examId, initialExam: initialExam),
    );
  }

  @override
  ExameterDetailScreenState createState() => ExameterDetailScreenState();
}

class ExameterDetailScreenState extends ConsumerState<ExameterDetailScreen> {
  final TextEditingController _noteCtrl = TextEditingController();

  ExamNoteType _currentTab = ExamNoteType.comment;
  int _massValue = 3;
  int _difficultyValue = 3;
  int _pastQValue = 3;

  bool _isSavingRating = false;
  bool _isSendingNote = false;

  @override
  void initState() {
    super.initState();
    final initialRating = ref.read(examUserRatingProvider(widget.examId));
    initialRating.whenOrNull(data: (rating) {
      if (rating == null) return;
      _syncRatingValues(rating);
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ExamRating?>>(
      examUserRatingProvider(widget.examId),
      (previous, next) {
        next.whenOrNull(data: (rating) {
          if (rating == null) return;
          _syncRatingValues(rating, notifyListeners: true);
        });
      },
    );

    final examAsync = ref.watch(examProvider(widget.examId));
    final notesAsync = ref.watch(
      examNotesProvider(ExamNotesArgs(examId: widget.examId, type: _currentTab)),
    );
    final userContext = ref.watch(communityUserContextProvider);
    final bool showComposer = examAsync.maybeWhen(
          data: (exam) => (exam ?? widget.initialExam) != null,
          orElse: () => widget.initialExam != null,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exameter'),
        elevation: 0,
        centerTitle: true,
      ),
      body: examAsync.when(
        data: (exam) {
          final resolvedExam = exam ?? widget.initialExam;
          if (resolvedExam == null) {
            return const _ExamMissing();
          }
          return _buildContent(context, resolvedExam, notesAsync, userContext);
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, stack) => _ExamError(
          message: err.toString(),
          onRetry: () => ref.refresh(examProvider(widget.examId).future),
        ),
      ),
      bottomNavigationBar: showComposer
          ? _NoteComposer(
              controller: _noteCtrl,
              currentTab: _currentTab,
              isSending: _isSendingNote,
              onSend: _submitNote,
            )
          : null,
    );
  }

  void _syncRatingValues(ExamRating rating, {bool notifyListeners = false}) {
    final mass = rating.mass.clamp(1, 5);
    final difficulty = rating.difficulty.clamp(1, 5);
    final pastQ = rating.pastQ.clamp(1, 5);

    final hasChanged =
        _massValue != mass || _difficultyValue != difficulty || _pastQValue != pastQ;
    if (!hasChanged) {
      return;
    }

    if (notifyListeners) {
      if (!mounted) return;
      setState(() {
        _massValue = mass;
        _difficultyValue = difficulty;
        _pastQValue = pastQ;
      });
    } else {
      _massValue = mass;
      _difficultyValue = difficulty;
      _pastQValue = pastQ;
    }
  }

  Widget _buildContent(
    BuildContext context,
    Exam exam,
    AsyncValue<List<ExamNote>> notesAsync,
    CommunityUserContext userContext,
  ) {
    final theme = Theme.of(context);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _Header(exam: exam, universityName: userContext.universityName),
        const SizedBox(height: 20),
        GaugeEffortChart(
          score: exam.compositeScore,
          updatedAt: exam.lastAggregateAt,
        ),
        const SizedBox(height: 16),
        _AggregateSummary(exam: exam),
        const SizedBox(height: 24),
        _RatingSection(
          massValue: _massValue,
          difficultyValue: _difficultyValue,
          pastQValue: _pastQValue,
          onMassChanged: (value) => setState(() => _massValue = value),
          onDifficultyChanged: (value) => setState(() => _difficultyValue = value),
          onPastQChanged: (value) => setState(() => _pastQValue = value),
          onSave: _submitRating,
          isSaving: _isSavingRating,
        ),
        const SizedBox(height: 24),
        Text(
          'Deine Stimme überschreibt deine frühere.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 28),
        _NotesSection(
          currentTab: _currentTab,
          onTabChanged: (tab) => setState(() => _currentTab = tab),
          notesAsync: notesAsync,
        ),
      ],
    );
  }

  Future<void> _submitRating() async {
    if (_isSavingRating) return;

    setState(() => _isSavingRating = true);
    try {
      await ref.read(examsRepositoryProvider).upsertRating(
            widget.examId,
            mass: _massValue,
            difficulty: _difficultyValue,
            pastQ: _pastQValue,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deine Bewertung wurde gespeichert.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bewertung konnte nicht gespeichert werden: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingRating = false);
      }
    }
  }

  Future<void> _submitNote() async {
    if (_isSendingNote) return;
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Text ein.')),
      );
      return;
    }

    setState(() => _isSendingNote = true);
    try {
      await ref.read(examsRepositoryProvider).addNote(
            widget.examId,
            text,
            _currentTab,
          );
      if (!mounted) return;
      _noteCtrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentTab == ExamNoteType.comment
                ? 'Kommentar veröffentlicht.'
                : 'Tipp veröffentlicht.',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beitrag konnte nicht gesendet werden: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingNote = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exam, required this.universityName});

  final Exam exam;
  final String universityName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exam.title.isEmpty ? 'Unbenannte Prüfung' : exam.title,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeaderPill(icon: CupertinoIcons.book_fill, label: exam.semester.isEmpty ? 'Semester unbekannt' : exam.semester),
            _HeaderPill(
              icon: CupertinoIcons.building_2_fill,
              label: universityName.isEmpty ? exam.universityCode.toUpperCase() : universityName,
            ),
            _HeaderPill(
              icon: CupertinoIcons.calendar,
              label: _formatDate(exam.createdAt),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.iconTheme.color?.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _AggregateSummary extends StatelessWidget {
  const _AggregateSummary({required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.18 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          RingTripletChart(
            size: 92,
            mass: exam.ratingsAvgMass,
            difficulty: exam.ratingsAvgDifficulty,
            pastQ: exam.ratingsAvgPastQ,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricRow(label: 'Stoffmenge', value: exam.ratingsAvgMass),
                const SizedBox(height: 10),
                _MetricRow(label: 'Stoffschwierigkeit', value: exam.ratingsAvgDifficulty),
                const SizedBox(height: 10),
                _MetricRow(label: 'Altfragenlastigkeit', value: exam.ratingsAvgPastQ),
                const SizedBox(height: 14),
                Text(
                  '${exam.ratingsCount} ${exam.ratingsCount == 1 ? 'Bewertung' : 'Bewertungen'} · ${exam.notesCount} Beiträge',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Text('${value.round()}%', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.massValue,
    required this.difficultyValue,
    required this.pastQValue,
    required this.onMassChanged,
    required this.onDifficultyChanged,
    required this.onPastQChanged,
    required this.onSave,
    required this.isSaving,
  });

  final int massValue;
  final int difficultyValue;
  final int pastQValue;
  final ValueChanged<int> onMassChanged;
  final ValueChanged<int> onDifficultyChanged;
  final ValueChanged<int> onPastQChanged;
  final Future<void> Function() onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deine Bewertung', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _RatingSelector(
          label: 'Stoffmenge',
          value: massValue,
          onChanged: onMassChanged,
          color: _summerBlue,
        ),
        const SizedBox(height: 18),
        _RatingSelector(
          label: 'Stoffschwierigkeit',
          value: difficultyValue,
          onChanged: onDifficultyChanged,
          color: _summerPink,
        ),
        const SizedBox(height: 18),
        _RatingSelector(
          label: 'Altfragenlastigkeit',
          value: pastQValue,
          onChanged: onPastQChanged,
          color: _summerYellow,
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: isSaving ? null : onSave,
            child: isSaving
                ? const CupertinoActivityIndicator()
                : const Text('Bewertung speichern'),
          ),
        ),
      ],
    );
  }
}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 1; i <= 5; i++)
              _RatingChip(
                label: '$i',
                isSelected: value == i,
                color: color,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTextColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.75) ??
        (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87);
    final borderFallback = theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.28);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label von 5',
      value: isSelected ? 'Ausgewählt' : 'Nicht ausgewählt',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? color.withOpacity(0.14) : Colors.transparent,
              border: Border.all(color: isSelected ? color : borderFallback, width: 1.5),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : baseTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.currentTab,
    required this.onTabChanged,
    required this.notesAsync,
  });

  final ExamNoteType currentTab;
  final ValueChanged<ExamNoteType> onTabChanged;
  final AsyncValue<List<ExamNote>> notesAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSlidingSegmentedControl<ExamNoteType>(
          groupValue: currentTab,
          padding: const EdgeInsets.all(4),
          children: const {
            ExamNoteType.comment: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Kommentare'),
            ),
            ExamNoteType.tip: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Tipps'),
            ),
          },
          onValueChanged: (value) {
            if (value != null) onTabChanged(value);
          },
        ),
        const SizedBox(height: 20),
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return _EmptyNotesState(tab: currentTab);
            }
            return Column(
              children: notes
                  .map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _NoteCard(note: note),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (err, _) => _NotesError(message: err.toString()),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final ExamNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                note.isTip ? 'Tipp' : 'Kommentar',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.labelSmall?.color?.withOpacity(0.7),
                ),
              ),
              Text(
                _relativeTime(note.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.labelSmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState({required this.tab});

  final ExamNoteType tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComment = tab == ExamNoteType.comment;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            isComment ? CupertinoIcons.chat_bubble_2 : CupertinoIcons.lightbulb,
            size: 42,
            color: theme.iconTheme.color?.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isComment ? 'Noch keine Kommentare.' : 'Noch keine Tipps.',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            isComment
                ? 'Teile deine Erfahrung mit anderen Studierenden.'
                : 'Gib einen hilfreichen Tipp weiter.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesError extends StatelessWidget {
  const _NotesError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteComposer extends StatelessWidget {
  const _NoteComposer({
    required this.controller,
    required this.currentTab,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final ExamNoteType currentTab;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = currentTab == ExamNoteType.comment
        ? 'Kommentar schreiben…'
        : 'Hilfreichen Tipp teilen…';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.24 : 0.16),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                placeholder: placeholder,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton.filled(
              onPressed: isSending ? null : onSend,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: isSending
                  ? const CupertinoActivityIndicator()
                  : const Icon(CupertinoIcons.paperplane_fill, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamMissing extends StatelessWidget {
  const _ExamMissing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search, size: 64, color: theme.iconTheme.color?.withOpacity(0.35)),
            const SizedBox(height: 18),
            Text(
              'Diese Prüfung ist nicht mehr verfügbar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamError extends StatelessWidget {
  const _ExamError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
            Icon(CupertinoIcons.exclamationmark_triangle, size: 68, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Exameter konnte nicht geladen werden.',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
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
