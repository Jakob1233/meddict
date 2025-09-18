import 'package:cloud_firestore/cloud_firestore.dart';

enum ExamNoteType { comment, tip }

class ExamNote {
  ExamNote({
    required this.id,
    required this.examId,
    required this.userId,
    required this.type,
    required this.body,
    required this.createdAt,
    required this.upvotes,
    required this.snapshot,
  });

  final String id;
  final String examId;
  final String userId;
  final ExamNoteType type;
  final String body;
  final DateTime createdAt;
  final int upvotes;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  bool get isComment => type == ExamNoteType.comment;
  bool get isTip => type == ExamNoteType.tip;

  factory ExamNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
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

    ExamNoteType parseType(dynamic value) {
      if (value is String) {
        switch (value.toLowerCase()) {
          case 'tip':
            return ExamNoteType.tip;
          case 'comment':
          default:
            return ExamNoteType.comment;
        }
      }
      return ExamNoteType.comment;
    }

    return ExamNote(
      id: doc.id,
      examId: doc.reference.parent.parent?.id ?? '',
      userId: (data['userId'] as String? ?? '').trim(),
      type: parseType(data['type']),
      body: (data['body'] as String? ?? '').trim(),
      createdAt: parseDate(data['createdAt']),
      upvotes: parseInt(data['upvotes']),
      snapshot: doc,
    );
  }
}
