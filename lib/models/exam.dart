import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.universityCode,
    required this.semester,
    required this.track,
    required this.createdAt,
    this.ratingsCount = 0,
    this.ratingsAvgMass = 0,
    this.ratingsAvgDifficulty = 0,
    this.ratingsAvgPastQ = 0,
    this.compositeScore = 0,
    this.lastAggregateAt,
    this.notesCount = 0,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String universityCode;
  final String semester;
  final String track;
  final DateTime createdAt;
  final int ratingsCount;
  final double ratingsAvgMass;
  final double ratingsAvgDifficulty;
  final double ratingsAvgPastQ;
  final double compositeScore;
  final DateTime? lastAggregateAt;
  final int notesCount;
  final List<String> tags;

  bool get hasRatings => ratingsCount > 0;
  int get commentsCount => notesCount;

  Map<String, dynamic> toJson() => {
        'title': title,
        'universityCode': universityCode,
        'semester': semester,
        'track': track,
        'createdAt': createdAt,
        'ratingsCount': ratingsCount,
        'ratingsAvgMass': ratingsAvgMass,
        'ratingsAvgDifficulty': ratingsAvgDifficulty,
        'ratingsAvgPastQ': ratingsAvgPastQ,
        'compositeScore': compositeScore,
      };

  factory Exam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Exam.fromSnap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static Exam fromSnap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return fallback ?? DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      return 0;
    }

    double parseNormalized(dynamic primary, [dynamic legacy]) {
      final primaryValue = parseDouble(primary);
      if (primaryValue > 0) return _clamp(primaryValue);

      final legacyValue = parseDouble(legacy);
      if (legacyValue <= 0) return 0;
      if (legacyValue <= 5) {
        return _clamp(legacyValue * 25 - 25);
      }
      return _clamp(legacyValue);
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    List<String> parseTags(dynamic value) {
      if (value is List) {
        return value
            .whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return Exam(
      id: id,
      title: (data['title'] as String? ?? '').trim(),
      universityCode: (data['universityCode'] as String? ?? '').trim(),
      semester: (data['semester'] as String? ?? '').trim(),
      track: (data['track'] as String? ?? 'human').trim().toLowerCase(),
      createdAt: parseDate(data['createdAt']),
      ratingsCount: parseInt(data['ratingsCount']),
      ratingsAvgMass: parseNormalized(data['ratingsAvgMass'], data['ratingsAvgEffort']),
      ratingsAvgDifficulty: parseNormalized(data['ratingsAvgDifficulty'], data['ratingsAvgPrepWeeks']),
      ratingsAvgPastQ: parseNormalized(data['ratingsAvgPastQ'], data['ratingsAvgPastQuestions']),
      compositeScore: _clamp(parseDouble(data['compositeScore'])),
      lastAggregateAt: data['lastAggregateAt'] == null
          ? null
          : parseDate(data['lastAggregateAt'], fallback: null),
      notesCount: parseInt(data['notesCount'] ?? data['commentsCount']),
      tags: parseTags(data['tags']),
    );
  }

  static double _clamp(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value < 0) return 0;
    if (value > 100) return 100;
    return double.parse(value.toStringAsFixed(2));
  }
}
