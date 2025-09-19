import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/core/constants/assets_constants.dart';
import 'package:flutterquiz/core/navigation/navigation_extension.dart';
import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/onboarding/data/onboarding_repository.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';

enum _StudyProgram { humani, zahnimaus }

const _semesters = <String>[
  'Erstie',
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

const _universities = <String>[
  'MedUni Wien',
  'SFU Wien',
  'Karl Landsteiner',
];

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const OnboardingFlow());
  }

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _onboardingController = FirstLoginOnboardingController();
  _StudyProgram? _selectedProgram;
  String? _selectedSemester;
  String? _selectedUniversity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cachedProgram = _onboardingController.cachedStudyProgram;
    if (cachedProgram.isNotEmpty) {
      _selectedProgram = _stringToProgram(cachedProgram);
    }
    final cachedSemester = FirstLoginOnboardingController.displaySemester(
      _onboardingController.cachedSemester,
    );
    if (cachedSemester.isNotEmpty) {
      _selectedSemester = cachedSemester;
    }
    final cachedUniversity = _onboardingController.cachedUniversityName;
    if (cachedUniversity.isNotEmpty &&
        _universities.contains(cachedUniversity)) {
      _selectedUniversity = cachedUniversity;
    }
  }

  _StudyProgram? _stringToProgram(String? value) {
    final normalized = value?.toLowerCase().trim();
    return switch (normalized) {
      'humani' => _StudyProgram.humani,
      'zahnimaus' => _StudyProgram.zahnimaus,
      'zahni' => _StudyProgram.zahnimaus,
      _ => null,
    };
  }

  String _programLabel(_StudyProgram program) {
    return switch (program) {
      _StudyProgram.humani => 'Humani',
      _StudyProgram.zahnimaus => 'Zahnimaus',
    };
  }

  Future<void> _submit() async {
    if (_selectedProgram == null ||
        _selectedSemester == null ||
        _selectedUniversity == null ||
        _isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
    });

    final authCubit = context.read<AuthCubit>();
    final uid = authCubit.firebaseId;
    if (uid == null || uid.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Benutzeranmeldung fehlgeschlagen.')),
      );
      return;
    }

    final studyProgram = _programStorageValue(_selectedProgram!);
    final semester = _semesterStorageValue(_selectedSemester!);
    final universityName = _selectedUniversity!;
    final universityMeta =
        FirstLoginOnboardingController.universities[universityName];
    final universityCode = universityMeta?['code'] ?? '';
    if (universityCode.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Universität unbekannt. Bitte erneut wählen.'),
        ),
      );
      return;
    }

    final userDetailsCubit = context.read<UserDetailsCubit>();

    try {
      await _onboardingController.markCompleted(
        uid: uid,
        studyProgram: studyProgram,
        semester: semester,
        universityName: universityName,
        universityCode: universityCode,
      );

      userDetailsCubit.updateUserProfile(
        studyProgram: studyProgram,
        specialization: studyProgram,
        semester: semester,
        universityName: universityName,
        universityCode: universityCode,
        firstLoginComplete: true,
      );

      if (!mounted) {
        return;
      }

      await context.pushNamedAndRemoveUntil(
        Routes.home,
        predicate: (_) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speichern fehlgeschlagen. Bitte versuche es erneut.'),
        ),
      );
    }
  }

  String _programStorageValue(_StudyProgram program) {
    return program == _StudyProgram.humani
        ? FirstLoginOnboardingController.normalizeProgram('humani')
        : FirstLoginOnboardingController.normalizeProgram('zahni');
  }

  String _semesterStorageValue(String value) {
    return FirstLoginOnboardingController.normalizeSemester(value);
  }

  bool get _isFinishEnabled =>
      _selectedProgram != null &&
      _selectedSemester != null &&
      _selectedUniversity != null &&
      !_isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildProgramStep(context)),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramStep(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < 520;
        final cardWidth = isCompact ? maxWidth - 32 : (maxWidth - 48) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bitte wähle',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth.clamp(160.0, 320.0).toDouble(),
                        child: _programCard(
                          context,
                          program: _StudyProgram.humani,
                          asset: Assets.onboardingHumani,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth.clamp(160.0, 320.0).toDouble(),
                        child: _programCard(
                          context,
                          program: _StudyProgram.zahnimaus,
                          asset: Assets.onboardingZahni,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailsForm(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _programCard(
    BuildContext context, {
    required _StudyProgram program,
    required String asset,
  }) {
    final selected = _selectedProgram == program;
    final theme = Theme.of(context);
    final borderColor = selected ? theme.primaryColor : Colors.transparent;
    final labelColor = selected ? theme.primaryColor : Colors.black54;

    return Semantics(
      label: _programLabel(program),
      button: true,
      selected: selected,
      child: InkWell(
        onTap: _isSaving
            ? null
            : () {
                setState(() {
                  _selectedProgram = program;
                });
              },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                blurRadius: selected ? 12 : 6,
                offset: const Offset(0, 4),
                color: selected
                    ? theme.primaryColor.withOpacity(0.25)
                    : Colors.black12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(asset, height: 96),
              const SizedBox(height: 12),
              Text(
                _programLabel(program),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Semester auswählen',
          child: AppDropdown<String>(
            label: 'Semester',
            hintText: 'Semester wählen',
            items: _semesters,
            itemLabel: (value) => value,
            value: _selectedSemester,
            onChanged: (value) => setState(() => _selectedSemester = value),
            enabled: !_isSaving,
            borderRadius: 16,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Universität auswählen',
          child: AppDropdown<String>(
            label: 'Universität',
            hintText: 'Universität wählen',
            items: _universities,
            itemLabel: (value) => value,
            value: _selectedUniversity,
            onChanged: (value) => setState(() => _selectedUniversity = value),
            enabled: !_isSaving,
            borderRadius: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = _selectionCardWidth(constraints.maxWidth);
          final backgroundResolver = MaterialStateProperty.resolveWith<Color?>((
            states,
          ) {
            if (states.contains(MaterialState.disabled)) {
              return const Color(0xFFE3E3E8);
            }
            return theme.primaryColor;
          });
          final foregroundResolver = MaterialStateProperty.resolveWith<Color?>((
            states,
          ) {
            if (states.contains(MaterialState.disabled)) {
              return const Color(0xFF7A7A85);
            }
            return Colors.white;
          });

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(
              child: SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: backgroundResolver,
                    foregroundColor: foregroundResolver,
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  onPressed: _isFinishEnabled ? _submit : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Fertig'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _selectionCardWidth(double maxWidth) {
    final isCompact = maxWidth < 520;
    final cardWidth = isCompact ? maxWidth - 32 : (maxWidth - 48) / 2;
    return cardWidth.clamp(160.0, 320.0);
  }
}
