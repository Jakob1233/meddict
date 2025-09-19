import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutterquiz/features/profile_management/profile_management_local_data_source.dart';

class OnboardingProfile {
  OnboardingProfile({
    this.studyProgram,
    this.semester,
    this.universityName,
    this.universityCode,
    this.onboardingCompleted,
  });

  factory OnboardingProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return OnboardingProfile();
    return OnboardingProfile(
      studyProgram: data['studyProgram'] as String?,
      semester: data['semester'] as String?,
      universityName: data['universityName'] as String?,
      universityCode: data['universityCode'] as String?,
      onboardingCompleted: data['onboardingCompleted'] as bool?,
    );
  }

  final String? studyProgram;
  final String? semester;
  final String? universityName;
  final String? universityCode;
  final bool? onboardingCompleted;

  bool get hasRequiredData =>
      (studyProgram?.isNotEmpty ?? false) &&
      (semester?.isNotEmpty ?? false) &&
      (universityName?.isNotEmpty ?? false) &&
      (universityCode?.isNotEmpty ?? false);
  bool get isComplete => (onboardingCompleted ?? false) && hasRequiredData;
}

class OnboardingProfileRepository {
  OnboardingProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('profiles');

  Future<OnboardingProfile?> getProfile(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return OnboardingProfile.fromDoc(doc);
  }

  Future<void> upsertProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _collection.doc(uid).set(data, SetOptions(merge: true));
  }

  Stream<OnboardingProfile?> watchProfile(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OnboardingProfile.fromDoc(doc);
    });
  }
}

class FirstLoginOnboardingController {
  FirstLoginOnboardingController({
    OnboardingProfileRepository? repository,
    ProfileManagementLocalDataSource? localDataSource,
  }) : _repository = repository ?? OnboardingProfileRepository(),
       _localDataSource = localDataSource ?? ProfileManagementLocalDataSource();

  final OnboardingProfileRepository _repository;
  final ProfileManagementLocalDataSource _localDataSource;

  static const _programHumani = 'humani';
  static const _programZahni = 'zahni';

  static const Map<String, Map<String, String>> universities = {
    'MedUni Wien': {'code': 'meduni'},
    'SFU Wien': {'code': 'sfu'},
    'Karl Landsteiner': {'code': 'klu'},
  };

  static String normalizeProgram(String? value) {
    if (value == null) return '';
    final lower = value.toLowerCase();
    if (lower.contains('humani')) return _programHumani;
    if (lower.contains('zahni')) return _programZahni;
    return lower;
  }

  static String normalizeSemester(String? value) {
    if (value == null) return '';
    final upper = value.toUpperCase();
    if (upper == 'ERSTIE') return 'S1';
    if (upper.startsWith('S') && upper.length <= 3) {
      return upper;
    }
    return upper;
  }

  static String displaySemester(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.toUpperCase() == 'S1' ? 'Erstie' : value.toUpperCase();
  }

  Future<bool> shouldShowOnboarding(String uid) async {
    if (_localDataSource.getFirstLoginComplete()) {
      final cachedProgram = normalizeProgram(
        _localDataSource.getStudyProgram(),
      );
      final cachedSemester = normalizeSemester(_localDataSource.getSemester());
      final cachedUniversityName = _localDataSource.getUniversityName();
      final cachedUniversityCode = _localDataSource.getUniversityCode();
      final hasAllLocal =
          cachedProgram.isNotEmpty &&
          cachedSemester.isNotEmpty &&
          cachedUniversityName.isNotEmpty &&
          cachedUniversityCode.isNotEmpty;
      if (hasAllLocal) {
        return false;
      }
    }

    OnboardingProfile? profile;
    try {
      profile = await _repository.getProfile(uid);
    } on Exception {
      return true;
    }
    if (profile == null) {
      return true;
    }

    final studyProgram = normalizeProgram(profile.studyProgram);
    final semester = normalizeSemester(profile.semester);
    final universityName = profile.universityName ?? '';
    final universityCode = profile.universityCode ?? '';

    if (profile.isComplete ||
        (profile.hasRequiredData &&
            studyProgram.isNotEmpty &&
            semester.isNotEmpty &&
            universityName.isNotEmpty &&
            universityCode.isNotEmpty)) {
      await _persistLocal(
        studyProgram: studyProgram,
        specialization: studyProgram,
        semester: semester,
        universityName: universityName,
        universityCode: universityCode,
        completed: true,
      );

      if (!(profile.onboardingCompleted ?? false) &&
          studyProgram.isNotEmpty &&
          semester.isNotEmpty &&
          universityName.isNotEmpty &&
          universityCode.isNotEmpty) {
        await _repository.upsertProfile(
          uid: uid,
          data: {
            'onboardingCompleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      return false;
    }

    return true;
  }

  Future<void> markCompleted({
    required String uid,
    required String studyProgram,
    required String semester,
    required String universityName,
    required String universityCode,
  }) async {
    await _repository.upsertProfile(
      uid: uid,
      data: {
        'studyProgram': studyProgram,
        'specialization': studyProgram,
        'semester': semester,
        'universityName': universityName,
        'universityCode': universityCode,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _persistLocal(
      studyProgram: studyProgram,
      specialization: studyProgram,
      semester: semester,
      universityName: universityName,
      universityCode: universityCode,
      completed: true,
    );
  }

  Future<void> _persistLocal({
    required String studyProgram,
    required String specialization,
    required String semester,
    required String universityName,
    required String universityCode,
    required bool completed,
  }) async {
    if (studyProgram.isNotEmpty) {
      await _localDataSource.setStudyProgram(studyProgram);
    }
    if (specialization.isNotEmpty) {
      await _localDataSource.setSpecialization(specialization);
    }
    if (semester.isNotEmpty) {
      await _localDataSource.setSemester(semester);
    }
    if (universityName.isNotEmpty) {
      await _localDataSource.setUniversityName(universityName);
    }
    if (universityCode.isNotEmpty) {
      await _localDataSource.setUniversityCode(universityCode);
    }
    await _localDataSource.setFirstLoginComplete(completed);
  }

  String get cachedStudyProgram =>
      normalizeProgram(_localDataSource.getStudyProgram());
  String get cachedSemester =>
      normalizeSemester(_localDataSource.getSemester());
  String get cachedUniversityName => _localDataSource.getUniversityName();
  String get cachedUniversityCode => _localDataSource.getUniversityCode();
}
