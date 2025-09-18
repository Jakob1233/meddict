bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    final numeric = num.tryParse(value);
    return numeric != null && numeric != 0;
  }
  return null;
}

class UserProfile {
  UserProfile({
    this.email,
    this.fcmToken,
    this.referCode,
    this.firebaseId,
    this.mobileNumber,
    this.name,
    this.profileUrl,
    this.userId,
    this.allTimeRank,
    this.allTimeScore,
    this.coins,
    this.registeredDate,
    this.status,
    this.adsRemovedForUser,
    this.isDailyAdsAvailable,
    this.appLanguage = '',
    this.username,
    this.studyProgram,
    this.specialization,
    this.semester,
    this.universityName,
    this.universityCode,
    this.firstLoginComplete,
  });

  UserProfile.fromJson(Map<String, dynamic> json)
    : allTimeRank = json['all_time_rank'] as String? ?? '',
      mobileNumber = json['mobile'] as String? ?? '',
      name = json['name'] as String? ?? '',
      profileUrl = json['profile'] as String? ?? '',
      registeredDate = json['date_registered'] as String? ?? '',
      status = json['status'] as String? ?? '',
      userId = json['id'] as String? ?? '',
      firebaseId = json['firebase_id'] as String? ?? '',
      allTimeScore = json['all_time_score'] as String? ?? '',
      coins = json['coins'] as String? ?? '',
      referCode = json['refer_code'] as String? ?? '',
      fcmToken = json['fcm_id'] as String? ?? '',
      email = json['email'] as String? ?? '',
      isDailyAdsAvailable = (json['daily_ads_available'] as int? ?? 1) == 1,
      adsRemovedForUser = json['remove_ads'] as String? ?? '0',
      appLanguage = json['app_language'] as String? ?? '',
      username = json['username'] as String? ?? '',
      studyProgram = json['study_program'] as String? ?? '',
      specialization =
          (json['specialization'] as String?) ??
          (json['study_program'] as String?) ??
          '',
      semester = json['semester'] as String? ?? '',
      universityName = json['university_name'] as String? ?? '',
      universityCode = json['university_code'] as String? ?? '',
      firstLoginComplete = _parseBool(json['first_login_complete']) ?? false;

  final String? name;
  final String? userId;
  final String? firebaseId;
  final String? profileUrl;
  final String? email;
  final String? mobileNumber;
  final String? status;
  final String? allTimeScore;
  final String? allTimeRank;
  final String? coins;
  final String? registeredDate;
  final String? referCode;
  final String? adsRemovedForUser;
  final String? fcmToken;
  final bool? isDailyAdsAvailable;
  final String appLanguage;
  final String? username;
  final String? studyProgram;
  final String? specialization;
  final String? semester;
  final String? universityName;
  final String? universityCode;
  final bool? firstLoginComplete;

  UserProfile copyWith({
    String? profileUrl,
    String? name,
    String? allTimeRank,
    String? allTimeScore,
    String? coins,
    String? status,
    String? mobile,
    String? email,
    String? adsRemovedForUser,
    String? appLanguage,
    String? username,
    String? studyProgram,
    String? specialization,
    String? semester,
    String? universityName,
    String? universityCode,
    bool? firstLoginComplete,
  }) {
    return UserProfile(
      fcmToken: fcmToken,
      userId: userId,
      profileUrl: profileUrl ?? this.profileUrl,
      email: email ?? this.email,
      name: name ?? this.name,
      firebaseId: firebaseId,
      referCode: referCode,
      allTimeRank: allTimeRank ?? this.allTimeRank,
      allTimeScore: allTimeScore ?? this.allTimeScore,
      coins: coins ?? this.coins,
      mobileNumber: mobile ?? mobileNumber,
      registeredDate: registeredDate,
      status: status ?? this.status,
      adsRemovedForUser: adsRemovedForUser ?? this.adsRemovedForUser,
      appLanguage: appLanguage ?? this.appLanguage,
      username: username ?? this.username,
      studyProgram: studyProgram ?? this.studyProgram,
      specialization: specialization ?? this.specialization,
      semester: semester ?? this.semester,
      universityName: universityName ?? this.universityName,
      universityCode: universityCode ?? this.universityCode,
      firstLoginComplete: firstLoginComplete ?? this.firstLoginComplete,
    );
  }

  UserProfile copyWithProfileData(String? name, String? mobile, String? email) {
    return UserProfile(
      fcmToken: fcmToken,
      referCode: referCode,
      userId: userId,
      profileUrl: profileUrl,
      email: email,
      name: name,
      firebaseId: firebaseId,
      allTimeRank: allTimeRank,
      allTimeScore: allTimeScore,
      coins: coins,
      mobileNumber: mobile,
      registeredDate: registeredDate,
      status: status,
      adsRemovedForUser: adsRemovedForUser,
      isDailyAdsAvailable: isDailyAdsAvailable,
      appLanguage: appLanguage,
      username: username,
      studyProgram: studyProgram,
      specialization: specialization,
      semester: semester,
      universityName: universityName,
      universityCode: universityCode,
      firstLoginComplete: firstLoginComplete,
    );
  }

  @override
  String toString() => 'RemoveAds: $adsRemovedForUser';
}
