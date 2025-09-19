import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutterquiz/models/exam.dart';
import 'package:flutterquiz/models/exam_note.dart';
import 'package:flutterquiz/models/exam_rating.dart';

enum ExamsListOrdering { createdAt, compositeScore }

class ExamsPage {
  ExamsPage({required this.exams, required this.lastDocument});

  final List<Exam> exams;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  bool get hasMore => lastDocument != null;
}

class ExamsRepository {
  ExamsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int _defaultLimit = 20;

  Future<ExamsPage> fetchExamsPage({
    required String universityCode,
    String? semesterFilter,
    ExamsListOrdering ordering = ExamsListOrdering.createdAt,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = _defaultLimit,
  }) async {
    if (universityCode.isEmpty) {
      return ExamsPage(exams: const [], lastDocument: null);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('exams')
        .where('universityCode', isEqualTo: universityCode);

    if (!_isAllSemester(semesterFilter)) {
      query = query.where('semester', isEqualTo: semesterFilter);
    }

    switch (ordering) {
      case ExamsListOrdering.compositeScore:
        query = query
            .orderBy('compositeScore', descending: true)
            .orderBy('createdAt', descending: true);
        break;
      case ExamsListOrdering.createdAt:
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();
    final docs = snapshot.docs;
    final exams = docs.map(Exam.fromDoc).toList();
    final lastDoc = docs.isEmpty ? null : docs.last;

    return ExamsPage(exams: exams, lastDocument: lastDoc);
  }

  Stream<Exam?> watchExam(String examId) {
    return _firestore.collection('exams').doc(examId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Exam.fromDoc(snapshot);
    });
  }

  Future<ExamRating?> fetchUserRating(String examId, {String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;

    final doc = await _firestore.collection('exams').doc(examId).collection('ratings').doc(uid).get();
    if (!doc.exists) return null;
    return ExamRating.fromDoc(doc);
  }

  Stream<ExamRating?> watchUserRating(String examId, {String? userId}) {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream<ExamRating?>.empty();
    }
    return _firestore
        .collection('exams')
        .doc(examId)
        .collection('ratings')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists ? ExamRating.fromDoc(snapshot) : null);
  }

  Stream<List<ExamNote>> watchNotes(String examId, ExamNoteType type) {
    return _firestore
        .collection('exams')
        .doc(examId)
        .collection('notes')
        .where('type', isEqualTo: type.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ExamNote.fromDoc).toList());
  }

  Future<void> upsertRating(
    String examId, {
    required int mass,
    required int difficulty,
    required int pastQ,
    String? userId,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Eine gültige Anmeldung ist erforderlich, um eine Bewertung zu speichern.');
    }

    final clampedMass = max(1, min(5, mass));
    final clampedDifficulty = max(1, min(5, difficulty));
    final clampedPastQ = max(1, min(5, pastQ));

    final examRef = _firestore.collection('exams').doc(examId);
    final ratingRef = examRef.collection('ratings').doc(uid);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final examSnap = await transaction.get(examRef);
      if (!examSnap.exists) {
        throw StateError('Exam not found');
      }

      final ratingSnap = await transaction.get(ratingRef);
      ExamRating? existing;
      if (ratingSnap.exists) {
        existing = ExamRating.fromDoc(ratingSnap);
      }

      final data = examSnap.data() ?? <String, dynamic>{};
      final currentCount = max(0, _asInt(data['ratingsCount']));
      final currentAvgMass = _asDouble(data['ratingsAvgMass']);
      final currentAvgDifficulty = _asDouble(data['ratingsAvgDifficulty']);
      final currentAvgPastQ = _asDouble(data['ratingsAvgPastQ']);

      final newCount = existing == null ? currentCount + 1 : max(currentCount, 1);

      double totalMass = currentAvgMass * currentCount;
      double totalDifficulty = currentAvgDifficulty * currentCount;
      double totalPastQ = currentAvgPastQ * currentCount;

      if (existing != null) {
        totalMass -= existing.massNormalized;
        totalDifficulty -= existing.difficultyNormalized;
        totalPastQ -= existing.pastQNormalized;
      }

      final newMass = _normalizeRating(clampedMass);
      final newDifficulty = _normalizeRating(clampedDifficulty);
      final newPastQ = _normalizeRating(clampedPastQ);

      totalMass += newMass;
      totalDifficulty += newDifficulty;
      totalPastQ += newPastQ;

      if (totalMass < 0) totalMass = 0;
      if (totalDifficulty < 0) totalDifficulty = 0;
      if (totalPastQ < 0) totalPastQ = 0;

      final denominator = newCount <= 0 ? 1 : newCount;
      final nextAvgMass = _round(totalMass / denominator);
      final nextAvgDifficulty = _round(totalDifficulty / denominator);
      final nextAvgPastQ = _round(totalPastQ / denominator);
      final compositeScore = _computeComposite(
        mass: nextAvgMass,
        difficulty: nextAvgDifficulty,
        pastQ: nextAvgPastQ,
      );

      final ratingPayload = <String, dynamic>{
        'userId': uid,
        'mass': clampedMass,
        'difficulty': clampedDifficulty,
        'pastQ': clampedPastQ,
        'updatedAt': now,
      };

      if (existing == null) {
        ratingPayload['createdAt'] = now;
      } else {
        ratingPayload['createdAt'] = existing.createdAt;
      }

      transaction.set(ratingRef, ratingPayload);

      transaction.update(examRef, <String, dynamic>{
        'ratingsCount': newCount,
        'ratingsAvgMass': nextAvgMass,
        'ratingsAvgDifficulty': nextAvgDifficulty,
        'ratingsAvgPastQ': nextAvgPastQ,
        'compositeScore': compositeScore,
        'lastAggregateAt': now,
      });
    });
  }

  Future<void> addNote(
    String examId,
    String body,
    ExamNoteType type, {
    String? userId,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid;
    final trimmed = body.trim();
    if (uid == null || uid.isEmpty) {
      throw StateError('Eine gültige Anmeldung ist erforderlich, um eine Notiz zu schreiben.');
    }
    if (trimmed.isEmpty) {
      throw ArgumentError('Notiz darf nicht leer sein.');
    }

    final examRef = _firestore.collection('exams').doc(examId);
    final noteRef = examRef.collection('notes').doc();
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final examSnap = await transaction.get(examRef);
      if (!examSnap.exists) {
        throw StateError('Exam not found');
      }

      transaction.set(noteRef, {
        'userId': uid,
        'type': type.name,
        'body': trimmed,
        'createdAt': now,
        'upvotes': 0,
      });

      final currentNotes = max(0, _asInt(examSnap.data()?['notesCount'] ?? examSnap.data()?['commentsCount']));
      transaction.update(examRef, {
        'notesCount': currentNotes + 1,
        'commentsCount': currentNotes + 1,
        'updatedAt': now,
      });
    });
  }

  Future<void> addExam({
    required String title,
    required String universityCode,
    required String semester,
    required String track,
  }) async {
    await _firestore.collection('exams').add({
      'title': title,
      'universityCode': universityCode,
      'semester': semester,
      'track': track,
      'createdAt': FieldValue.serverTimestamp(),
      'ratingsCount': 0,
      'ratingsAvgMass': 0,
      'ratingsAvgDifficulty': 0,
      'ratingsAvgPastQ': 0,
      'compositeScore': 0,
    });
  }

  Future<int> addMany(List<Map<String, String>> rows) async {
    if (rows.isEmpty) return 0;

    final batch = _firestore.batch();
    final examsCol = _firestore.collection('exams');

    for (final row in rows) {
      final doc = examsCol.doc();
      batch.set(doc, {
        'title': row['title'],
        'universityCode': row['universityCode'],
        'semester': row['semester'],
        'track': row['track'],
        'createdAt': FieldValue.serverTimestamp(),
        'ratingsCount': 0,
        'ratingsAvgMass': 0,
        'ratingsAvgDifficulty': 0,
        'ratingsAvgPastQ': 0,
        'compositeScore': 0,
      });
    }

    await batch.commit();
    return rows.length;
  }

  bool _isAllSemester(String? value) {
    if (value == null) return true;
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    return normalized.toLowerCase() == 'alle';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0;
  }

  double _normalizeRating(int value) => (value.clamp(1, 5) * 25 - 25).toDouble();

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  int _computeComposite({
    required double mass,
    required double difficulty,
    required double pastQ,
  }) {
    const double effortWeight = 0.4;
    const double contentWeight = 0.4;
    const double pastExamsWeight = 0.2;

    final adjustedPast = 100 - pastQ.clamp(0, 100);
    final raw = (effortWeight * mass.clamp(0, 100)) +
        (contentWeight * difficulty.clamp(0, 100)) +
        (pastExamsWeight * adjustedPast);
    final normalized = raw / (effortWeight + contentWeight + pastExamsWeight);
    return normalized.round().clamp(0, 100);
  }
}
