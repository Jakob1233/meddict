import 'package:flutterquiz/core/constants/constants.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProfileManagementLocalDataSource {
  Box<dynamic> get _box => Hive.box<dynamic>(userDetailsBox);

  String getName() => _box.get(nameBoxKey, defaultValue: '') as String;

  String getUserUID() => _box.get(userUIdBoxKey, defaultValue: '') as String;

  String getEmail() => _box.get(emailBoxKey, defaultValue: '') as String;

  String getMobileNumber() =>
      _box.get(mobileNumberBoxKey, defaultValue: '') as String;

  String getRank() => _box.get(rankBoxKey, defaultValue: '') as String;

  String getCoins() => _box.get(coinsBoxKey, defaultValue: '') as String;

  String getScore() => _box.get(scoreBoxKey, defaultValue: '') as String;

  String getProfileUrl() =>
      _box.get(profileUrlBoxKey, defaultValue: '') as String;

  String getFirebaseId() =>
      _box.get(firebaseIdBoxKey, defaultValue: '') as String;

  String getUsername() => _box.get(usernameBoxKey, defaultValue: '') as String;

  String getStudyProgram() =>
      _box.get(studyProgramBoxKey, defaultValue: '') as String;

  String getSpecialization() =>
      _box.get(specializationBoxKey, defaultValue: '') as String;

  String getSemester() =>
      _box.get(semesterBoxKey, defaultValue: '') as String;

  String getUniversityName() =>
      _box.get(universityNameBoxKey, defaultValue: '') as String;

  String getUniversityCode() =>
      _box.get(universityCodeBoxKey, defaultValue: '') as String;

  bool getFirstLoginComplete() {
    final value = _box.get(firstLoginCompleteBoxKey, defaultValue: false);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  String getStatus() => _box.get(statusBoxKey, defaultValue: '1') as String;

  String getReferCode() =>
      _box.get(referCodeBoxKey, defaultValue: '') as String;

  String getFCMToken() => _box.get(fcmTokenBoxKey, defaultValue: '') as String;

  Future<void> setEmail(String email) async {
    await _box.put(emailBoxKey, email);
  }

  Future<void> setUserUId(String userId) async {
    await _box.put(userUIdBoxKey, userId);
  }

  Future<void> setName(String name) async {
    await _box.put(nameBoxKey, name);
  }

  Future<void> serProfileUrl(String profileUrl) async {
    await _box.put(profileUrlBoxKey, profileUrl);
  }

  Future<void> setRank(String rank) async {
    await _box.put(rankBoxKey, rank);
  }

  Future<void> setCoins(String coins) async {
    await _box.put(coinsBoxKey, coins);
  }

  Future<void> setMobileNumber(String mobileNumber) async {
    await _box.put(mobileNumberBoxKey, mobileNumber);
  }

  Future<void> setScore(String score) async {
    await _box.put(scoreBoxKey, score);
  }

  Future<void> setStatus(String status) async {
    await _box.put(statusBoxKey, status);
  }

  Future<void> setFirebaseId(String firebaseId) async {
    await _box.put(firebaseIdBoxKey, firebaseId);
  }

  Future<void> setReferCode(String referCode) async {
    await _box.put(referCodeBoxKey, referCode);
  }

  Future<void> setUsername(String username) async {
    await _box.put(usernameBoxKey, username);
  }

  Future<void> setStudyProgram(String studyProgram) async {
    await _box.put(studyProgramBoxKey, studyProgram);
  }

  Future<void> setSpecialization(String specialization) async {
    await _box.put(specializationBoxKey, specialization);
  }

  Future<void> setSemester(String semester) async {
    await _box.put(semesterBoxKey, semester);
  }

  Future<void> setUniversityName(String universityName) async {
    await _box.put(universityNameBoxKey, universityName);
  }

  Future<void> setUniversityCode(String universityCode) async {
    await _box.put(universityCodeBoxKey, universityCode);
  }

  Future<void> setFirstLoginComplete(bool value) async {
    await _box.put(firstLoginCompleteBoxKey, value);
  }

  Future<void> setFCMToken(String fcmToken) async {
    await _box.put(fcmTokenBoxKey, fcmToken);
  }

  Future<void> updateReversedCoins(int coins) async {
    await _box.put('reversedCoins', coins);
  }

  Future<int> getUpdateReversedCoins() async {
    return _box.get('reversedCoins') as int? ?? 0;
  }
}
