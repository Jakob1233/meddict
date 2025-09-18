import 'exam_icon.dart'; // Pfad anpassen

class ExamListTile extends StatelessWidget {
  final Exam exam; // dein Model

  const ExamListTile({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    final isDent = (exam.track?.toLowerCase() == 'zahn') || (exam.category?.toLowerCase() == 'zahn');
    return ListTile(
      leading: buildExamIcon(context, exam.title ?? '—', isDent: isDent),
      title: Text(exam.title ?? 'Unbenannte Prüfung'),
      subtitle: Text(exam.subtitle ?? ''),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: exam.id)),
        );
      },
    );
  }
}