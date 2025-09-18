part of 'multi_match_fetch_questions_cubit.dart';

sealed class MultiMatchFetchQuestionsState {
  const MultiMatchFetchQuestionsState();
}

final class MultiMatchFetchQuestionsInitial
    extends MultiMatchFetchQuestionsState {
  const MultiMatchFetchQuestionsInitial();
}

final class MultiMatchFetchQuestionsInProgress
    extends MultiMatchFetchQuestionsState {
  const MultiMatchFetchQuestionsInProgress();
}

final class MultiMatchQuestionsSuccess extends MultiMatchFetchQuestionsState {
  const MultiMatchQuestionsSuccess({
    required this.questions,
    required this.currentScore,
  });

  final List<MultiMatchQuestion> questions;
  final int currentScore;

  List<String> submittedAnswers(int idx) => questions[idx].submittedIds;

  MultiMatchQuestionsSuccess copyWith({
    List<MultiMatchQuestion>? questions,
    int? currentScore,
  }) {
    return MultiMatchQuestionsSuccess(
      questions: questions ?? this.questions,
      currentScore: currentScore ?? this.currentScore,
    );
  }
}

final class MultiMatchFetchQuestionsFailure
    extends MultiMatchFetchQuestionsState {
  const MultiMatchFetchQuestionsFailure({required this.error});

  final String error;
}
