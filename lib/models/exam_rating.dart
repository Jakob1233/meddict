import 'package:cloud_firestore/cloud_firestore.dart';

class ExamRating {
  ExamRating({
    required this.userId,
    required this.mass,
    required this.difficulty,
    required this.pastQ,
    required this.createdAt,
    required this.updatedAt,
    required this.snapshot,
  });

  final String userId;
  final int mass;
  final int difficulty;
  final int pastQ;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  double get massNormalized => _normalize(mass);
  double get difficultyNormalized => _normalize(difficulty);
  double get pastQNormalized => _normalize(pastQ);

  factory ExamRating.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    int readMass() => parseInt(data['mass'] ?? data['effort']);

    int readDifficulty() {
      final difficulty = data['difficulty'];
      if (difficulty != null) {
        return parseInt(difficulty);
      }
      final legacyPrepWeeks = parseInt(data['prepWeeks']);
      if (legacyPrepWeeks == 0) return 0;
      final mapped = ((legacyPrepWeeks.clamp(1, 10) - 1) / 9 * 4 + 1).round();
      return mapped;
    }

    int readPastQ() => parseInt(data['pastQ'] ?? data['pastQuestions']);

    return ExamRating(
      userId: (data['userId'] as String? ?? '').trim(),
      mass: readMass(),
      difficulty: readDifficulty(),
      pastQ: readPastQ(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      snapshot: doc,
    );
  }

  static double _normalize(int value) {
    final clamped = value.clamp(1, 5);
    return (clamped * 25 - 25).toDouble();
  }
}
