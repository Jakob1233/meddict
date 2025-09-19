import 'package:flutter/material.dart';

import 'package:flutterquiz/core/routes/routes.dart';
import 'package:flutterquiz/models/exam.dart';

import 'exam_icon.dart';

class ExamListTile extends StatelessWidget {
  const ExamListTile({super.key, required this.exam, this.onTap});

  final Exam exam;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final track = exam.track.toLowerCase();
    final isDent = track.contains('zahn') || track.contains('dent');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: buildExamIcon(context, exam.title, isDent: isDent),
      title: Text(
        exam.title.isEmpty ? 'Unbenannte Prüfung' : exam.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        exam.semester.isEmpty ? 'Semester unbekannt' : exam.semester,
      ),
      onTap:
          onTap ??
          () {
            Navigator.of(context).pushNamed(
              Routes.exameterDetail,
              arguments: <String, dynamic>{
                'examId': exam.id,
                'exam': exam,
              },
            );
          },
    );
  }
}
