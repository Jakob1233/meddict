import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/features/community/application/paged_posts_controller.dart';
import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/features/onboarding/data/onboarding_repository.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

const _categories = [
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

const _semesterOptions = [
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
const _scopeOptions = [
  'Semester-spezifisch',
  'Uni-spezifisch',
  'Alle',
];

class _UniversityOption {
  const _UniversityOption({required this.name, required this.code});

  final String name;
  final String code;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _UniversityOption && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}

Future<void> showQuestionComposer(
  BuildContext context,
  WidgetRef ref, {
  String? initialCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComposerSheet(
      child: QuestionComposer(initialCategory: initialCategory),
    ),
  );
}

Future<void> showExamTipComposer(
  BuildContext context,
  WidgetRef ref, {
  String? initialCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComposerSheet(
      child: ExamTipComposer(initialCategory: initialCategory),
    ),
  );
}

Future<void> showExperienceComposer(
  BuildContext context,
  WidgetRef ref, {
  String? initialCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComposerSheet(
      child: ExperienceComposer(initialCategory: initialCategory),
    ),
  );
}

class _ComposerSheet extends StatelessWidget {
  const _ComposerSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: child,
        );
      },
    );
  }
}

class QuestionComposer extends ConsumerStatefulWidget {
  const QuestionComposer({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  QuestionComposerState createState() => QuestionComposerState();
}

class QuestionComposerState extends ConsumerState<QuestionComposer> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.initialCategory ?? _categories.last;
  String _selectedScope = _scopeOptions.last;
  String? _semester;
  _UniversityOption? _selectedUniversity;
  late final List<_UniversityOption> _universityOptions;
  late final bool _hasSelectableUniversity;
  late final bool _isUniversitySearchable;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _linkToResource = false;
  String? _refType;
  final _refIdCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final context = ref.read(communityUserContextProvider);
    _universityOptions = _buildUniversityOptions(context);
    _hasSelectableUniversity = _universityOptions.any(
      (option) => option.code.isNotEmpty,
    );
    _isUniversitySearchable =
        _hasSelectableUniversity && _universityOptions.length > 6;
    if (_universityOptions.isNotEmpty) {
      final initial = _universityOptions.firstWhere(
        (option) => option.code.isNotEmpty,
        orElse: () => _universityOptions.first,
      );
      if (initial.code.isNotEmpty) {
        _selectedUniversity = initial;
      }
    }
    if (context.semester.isNotEmpty) {
      _semester = context.semester;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagsCtrl.dispose();
    _refIdCtrl.dispose();
    super.dispose();
  }

  List<_UniversityOption> _buildUniversityOptions(
    CommunityUserContext context,
  ) {
    final options = <_UniversityOption>[];
    final seenCodes = <String>{};

    void addOption(String name, String code) {
      final trimmedCode = code.trim();
      if (trimmedCode.isEmpty || seenCodes.contains(trimmedCode)) return;
      options.add(_UniversityOption(name: name, code: trimmedCode));
      seenCodes.add(trimmedCode);
    }

    if (context.universityName.isNotEmpty &&
        context.universityCode.isNotEmpty) {
      addOption(context.universityName, context.universityCode);
    }

    for (final entry in FirstLoginOnboardingController.universities.entries) {
      final code = entry.value['code'] ?? '';
      addOption(entry.key, code);
    }

    if (options.isEmpty) {
      options.add(
        const _UniversityOption(name: 'Keine Universität hinterlegt', code: ''),
      );
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Frage stellen',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Bezieht sich auf *',
                  items: _scopeOptions,
                  value: _selectedScope,
                  itemLabel: (value) => value,
                  searchable: false,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedScope = value;
                      if (value != 'Semester-spezifisch') {
                        _semester = null;
                      }
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Bitte Auswahl treffen' : null,
                ),
                const SizedBox(height: 16),
                AppDropdown<_UniversityOption>(
                  label: 'Universität *',
                  items: _universityOptions,
                  value: _selectedUniversity,
                  itemLabel: (value) => value.name,
                  hintText: _hasSelectableUniversity
                      ? 'Universität wählen'
                      : 'Keine Universität verfügbar',
                  searchable: _isUniversitySearchable,
                  onChanged: _hasSelectableUniversity
                      ? (value) => setState(() => _selectedUniversity = value)
                      : null,
                  validator: (value) {
                    if (_selectedScope == 'Uni-spezifisch' ||
                        _selectedScope == 'Semester-spezifisch') {
                      if (value == null || value.code.isEmpty) {
                        return 'Bitte Universität wählen';
                      }
                    }
                    return null;
                  },
                  enabled: _hasSelectableUniversity,
                ),
                if (_selectedScope == 'Semester-spezifisch') ...[
                  const SizedBox(height: 16),
                  AppDropdown<String>(
                    label: 'Semester *',
                    items: _semesterOptions,
                    value: _semester,
                    itemLabel: (value) => value,
                    onChanged: (value) => setState(() => _semester = value),
                    validator: (value) {
                      if (_selectedScope == 'Semester-spezifisch' &&
                          (value == null || value.isEmpty)) {
                        return 'Bitte Semester wählen';
                      }
                      return null;
                    },
                  ),
                ],
                if ((_selectedScope == 'Uni-spezifisch' ||
                        _selectedScope == 'Semester-spezifisch') &&
                    !_hasSelectableUniversity)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Hinweis: Ergänze dein Profil (Profil → Einstellungen), um diese Auswahl zu nutzen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Fachgebiet',
                  items: _categories,
                  value: _category,
                  itemLabel: (value) => value,
                  onChanged: (value) =>
                      setState(() => _category = value ?? _categories.last),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Titel *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Titel erforderlich'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung (Markdown erlaubt) *',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                      ? 'Bitte gib mindestens 10 Zeichen an.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (durch Komma getrennt)',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _linkToResource,
                  title: const Text('Bezieht sich auf Quiz/Flashcard'),
                  onChanged: (value) => setState(() => _linkToResource = value),
                ),
                if (_linkToResource) ...[
                  AppDropdown<String>(
                    label: 'Referenztyp',
                    items: const ['quiz', 'flashcard'],
                    value: _refType,
                    itemLabel: (value) =>
                        value == 'quiz' ? 'Quiz' : 'Flashcard',
                    onChanged: (value) => setState(() => _refType = value),
                    validator: (value) =>
                        value == null ? 'Bitte Typ wählen' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _refIdCtrl,
                    decoration: const InputDecoration(labelText: 'Referenz-ID'),
                    validator: (value) {
                      if (!_linkToResource) return null;
                      if (value == null || value.trim().isEmpty)
                        return 'Referenz-ID erforderlich';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(context),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Frage veröffentlichen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    String scope;
    String? scopedSemester;
    String? scopeUniversityCode;
    final selectedUniversityCode = _selectedUniversity?.code ?? '';

    switch (_selectedScope) {
      case 'Semester-spezifisch':
        if (selectedUniversityCode.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bitte Universität wählen.')),
          );
          return;
        }
        if (_semester == null || _semester!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bitte Semester wählen.')),
          );
          return;
        }
        scope = 'semester';
        scopedSemester = _semester;
        scopeUniversityCode = selectedUniversityCode;
        break;
      case 'Uni-spezifisch':
        if (selectedUniversityCode.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bitte Universität wählen.')),
          );
          return;
        }
        scope = 'uni';
        scopeUniversityCode = selectedUniversityCode;
        break;
      case 'Alle':
      default:
        scope = 'community';
        break;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte logge dich ein.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.createQuestionPost(
        createdBy: userId,
        category: _category,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        scope: scope,
        semester: scopedSemester,
        universityCode: scopeUniversityCode,
        tags: _tagsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        refType: _linkToResource ? _refType : null,
        refId: _linkToResource ? _refIdCtrl.text.trim() : null,
      );
      final ctx = ref.read(communityUserContextProvider);
      const sorts = [PostSort.newest, PostSort.upvotes];
      for (final sort in sorts) {
        ref.invalidate(
          pagedPostsProvider(
            PagedPostsArgs(
              limit: 20,
              sort: sort,
              type: 'question',
              scope: 'community',
            ),
          ),
        );
        if (ctx.hasSemester) {
          ref.invalidate(
            pagedPostsProvider(
              PagedPostsArgs(
                limit: 20,
                sort: sort,
                type: 'question',
                scope: 'semester',
                semester: ctx.semester,
                universityCode: ctx.universityCode,
              ),
            ),
          );
        }
        if (ctx.hasUniversity) {
          ref.invalidate(
            pagedPostsProvider(
              PagedPostsArgs(
                limit: 20,
                sort: sort,
                type: 'question',
                scope: 'uni',
                universityCode: ctx.universityCode,
              ),
            ),
          );
        }
        if (_category.isNotEmpty) {
          ref.invalidate(
            pagedPostsProvider(
              PagedPostsArgs(
                category: _category,
                type: 'question',
                limit: 20,
                sort: sort,
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Frage veröffentlicht.')),
      );
    } catch (err) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $err')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class ExamTipComposer extends ConsumerStatefulWidget {
  const ExamTipComposer({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ExamTipComposerState createState() => ExamTipComposerState();
}

class ExamTipComposerState extends ConsumerState<ExamTipComposer> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.initialCategory ?? _categories.last;
  String? _semester;
  String? _examKind;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final List<TextEditingController> _bullets = List.generate(
    3,
    (_) => TextEditingController(),
  );
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    for (final ctrl in _bullets) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Examens-Tipp posten',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Fachgebiet',
                  items: _categories,
                  value: _category,
                  itemLabel: (value) => value,
                  onChanged: (value) =>
                      setState(() => _category = value ?? _categories.last),
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Semester',
                  items: _semesterOptions,
                  value: _semester,
                  hintText: 'optional',
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _semester = value),
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Prüfungstyp',
                  items: const ['OSCE', 'MC', 'mdl'],
                  value: _examKind,
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _examKind = value),
                  validator: (value) =>
                      value == null ? 'Bitte Prüfungstyp wählen' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Titel *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Titel erforderlich'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  maxLength: 600,
                  decoration: const InputDecoration(
                    labelText: 'Kurzbeschreibung *',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                      ? 'Mindestens 10 Zeichen angeben'
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tipps (mindestens einer)*',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ..._bullets.map(
                  (ctrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: ctrl,
                      decoration: const InputDecoration(labelText: 'Bullet'),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _bullets.length >= 5
                        ? null
                        : () => setState(
                            () => _bullets.add(TextEditingController()),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Bullet hinzufügen'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(context),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tipp veröffentlichen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final bullets = _bullets
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (bullets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens einen Tipp eintragen.')),
      );
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte logge dich ein.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.createExamTipPost(
        createdBy: userId,
        category: _category,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        bullets: bullets,
        semester: _semester,
        examKind: _examKind,
      );
      ref.invalidate(pagedPostsProvider(const PagedPostsArgs(limit: 20)));
      ref.invalidate(
        pagedPostsProvider(const PagedPostsArgs(limit: 20, type: 'exam_tip')),
      );
      ref.invalidate(
        pagedPostsProvider(
          PagedPostsArgs(category: _category, type: 'exam_tip'),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Examens-Tipp veröffentlicht.')),
      );
    } catch (err) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $err')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class ExperienceComposer extends ConsumerStatefulWidget {
  const ExperienceComposer({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ExperienceComposerState createState() => ExperienceComposerState();
}

class ExperienceComposerState extends ConsumerState<ExperienceComposer> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.initialCategory ?? 'Divers';
  String? _semester;
  final _titleCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _lessonCtrl = TextEditingController();
  final List<TextEditingController> _tips = List.generate(
    3,
    (_) => TextEditingController(),
  );
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _institutionCtrl.dispose();
    _locationCtrl.dispose();
    _durationCtrl.dispose();
    _summaryCtrl.dispose();
    _lessonCtrl.dispose();
    for (final ctrl in _tips) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Erfahrung teilen',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Kategorie',
                  items: _categories,
                  value: _category,
                  itemLabel: (value) => value,
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Semester',
                  items: _semesterOptions,
                  value: _semester,
                  hintText: 'optional',
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _semester = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Titel *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Titel erforderlich'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _institutionCtrl,
                  decoration: const InputDecoration(labelText: 'Einrichtung *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Einrichtung angeben'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Ort *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ort angeben'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationCtrl,
                  decoration: const InputDecoration(labelText: 'Zeitraum'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryCtrl,
                  maxLines: 4,
                  maxLength: 800,
                  decoration: const InputDecoration(
                    labelText: 'Zusammenfassung *',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                      ? 'Bitte mind. 10 Zeichen angeben'
                      : null,
                ),
                const SizedBox(height: 12),
                Text('Tipps', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                ..._tips.map(
                  (ctrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: ctrl,
                      decoration: const InputDecoration(labelText: 'Tipp'),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _tips.length >= 5
                        ? null
                        : () => setState(
                            () => _tips.add(TextEditingController()),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Weiteren Tipp hinzufügen'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lessonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Was hätte ich früher wissen sollen?',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(context),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Erfahrung veröffentlichen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte logge dich ein.')));
      return;
    }

    final tips = _tips
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final template = {
      'institution': _institutionCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'duration': _durationCtrl.text.trim(),
      if (tips.isNotEmpty) 'tips': tips,
      if (_lessonCtrl.text.trim().isNotEmpty)
        'lessonLearned': _lessonCtrl.text.trim(),
    };

    setState(() => _submitting = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.createExperiencePost(
        createdBy: userId,
        title: _titleCtrl.text.trim(),
        body: _summaryCtrl.text.trim(),
        category: _category,
        semester: _semester,
        template: template,
      );
      ref.invalidate(pagedPostsProvider(const PagedPostsArgs(limit: 20)));
      ref.invalidate(
        pagedPostsProvider(const PagedPostsArgs(type: 'experience', limit: 20)),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erfahrung gespeichert.')));
    } catch (err) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $err')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
