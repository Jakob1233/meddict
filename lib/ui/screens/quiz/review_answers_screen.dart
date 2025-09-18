import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/bookmark/bookmark_repository.dart';
import 'package:flutterquiz/features/bookmark/cubits/audio_question_bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/guess_the_word_bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/update_bookmark_cubit.dart';
import 'package:flutterquiz/features/music_player/music_player_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/quiz/models/answer_option.dart';
import 'package:flutterquiz/features/quiz/models/guess_the_word_question.dart';
import 'package:flutterquiz/features/quiz/models/question.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/features/quiz/utils/quiz_utils.dart';
import 'package:flutterquiz/features/report_question/report_question_cubit.dart';
import 'package:flutterquiz/features/report_question/report_question_repository.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/screens/quiz/widgets/music_player_container.dart';
import 'package:flutterquiz/ui/screens/quiz/widgets/question_container.dart';
import 'package:flutterquiz/ui/screens/quiz/widgets/report_question_bottom_sheet.dart';
import 'package:flutterquiz/ui/widgets/already_logged_in_dialog.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/utils/answer_encryption.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

final class ReviewAnswersScreenArgs extends RouteArgs {
  const ReviewAnswersScreenArgs({
    required this.quizType,
    this.questions = const [],
    this.guessTheWordQuestions = const [],
  });

  final QuizTypes quizType;
  final List<Question> questions;
  final List<GuessTheWordQuestion> guessTheWordQuestions;
}

class ReviewAnswersScreen extends StatefulWidget {
  const ReviewAnswersScreen({required this.args, super.key});

  final ReviewAnswersScreenArgs args;

  static Route<dynamic> route(RouteSettings routeSettings) {
    final args = routeSettings.args<ReviewAnswersScreenArgs>();

    return CupertinoPageRoute(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<UpdateBookmarkCubit>(
            create: (context) => UpdateBookmarkCubit(BookmarkRepository()),
          ),
          BlocProvider<ReportQuestionCubit>(
            create: (_) => ReportQuestionCubit(ReportQuestionRepository()),
          ),
        ],
        child: ReviewAnswersScreen(args: args),
      ),
    );
  }

  @override
  State<ReviewAnswersScreen> createState() => _ReviewAnswersScreenState();
}

class _ReviewAnswersScreenState extends State<ReviewAnswersScreen> {
  late final _pageController = PageController();
  int _currQueIdx = 0;

  late final String _firebaseId = context
      .read<UserDetailsCubit>()
      .getUserFirebaseId();

  late final _isGuessTheWord = widget.args.quizType == QuizTypes.guessTheWord;
  late final _isAudioQuestions =
      widget.args.quizType == QuizTypes.audioQuestions;

  late final int questionsLength = _isGuessTheWord
      ? widget.args.guessTheWordQuestions.length
      : widget.args.questions.length;

  late final List<GlobalKey<MusicPlayerContainerState>> _musicPlayerKeys =
      List.generate(
        widget.args.questions.length,
        (_) => GlobalKey<MusicPlayerContainerState>(),
        growable: false,
      );
  late final List<String> _correctAnswerIds = List.generate(
    widget.args.questions.length,
    (i) => AnswerEncryption.decryptCorrectAnswer(
      rawKey: _firebaseId,
      correctAnswer: widget.args.questions[i].correctAnswer!,
    ),
    growable: false,
  );

  late final bool isLatex = context.read<SystemConfigCubit>().isLatexEnabled(
    widget.args.quizType,
  );

  void _onTapReportQuestion() {
    showReportQuestionBottomSheet(
      context: context,
      questionId: _isGuessTheWord
          ? widget.args.guessTheWordQuestions[_currQueIdx].id
          : widget.args.questions[_currQueIdx].id!,
      reportQuestionCubit: context.read<ReportQuestionCubit>(),
      quizType: widget.args.quizType,
    );
  }

  void _onPageChanged(int idx) {
    if (_isAudioQuestions) {
      _musicPlayerKeys[_currQueIdx].currentState?.stopAudio();
      _musicPlayerKeys[idx].currentState?.playAudio();
    }
    setState(() => _currQueIdx = idx);
  }

  Color _optionBackgroundColor(String? optionId) {
    if (optionId == _correctAnswerIds[_currQueIdx]) {
      return kCorrectAnswerColor;
    }

    if (optionId == widget.args.questions[_currQueIdx].submittedAnswerId) {
      return kWrongAnswerColor;
    }

    return Theme.of(context).colorScheme.surface;
  }

  Color _optionTextColor(String? optionId) {
    final correctAnswerId = _correctAnswerIds[_currQueIdx];
    final submittedAnswerId =
        widget.args.questions[_currQueIdx].submittedAnswerId;

    return optionId == correctAnswerId || optionId == submittedAnswerId
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.onTertiary;
  }

  Widget _buildBottomMenu() {
    final colorScheme = Theme.of(context).colorScheme;

    void onTapPageChange({required bool flipLeft}) {
      if (_currQueIdx != (flipLeft ? 0 : questionsLength - 1)) {
        final idx = _currQueIdx + (flipLeft ? -1 : 1);
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: context.width * UiUtils.hzMarginPct,
      ),
      height: context.height * UiUtils.bottomMenuPercentage,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.onTertiary.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.only(
              top: 5,
              left: 8,
              right: 2,
              bottom: 5,
            ),
            child: GestureDetector(
              onTap: () => onTapPageChange(flipLeft: true),
              child: Icon(Icons.arrow_back_ios, color: colorScheme.onTertiary),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.onTertiary.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: Text(
              '${_currQueIdx + 1} / $questionsLength',
              style: TextStyle(color: colorScheme.onTertiary, fontSize: 18),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.onTertiary.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: GestureDetector(
              onTap: () => onTapPageChange(flipLeft: false),
              child: Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //to build option of given question
  Widget _buildOption(AnswerOption option) {
    return isLatex
        ? TeXView(
            child: TeXViewDocument(option.title!),
            style: TeXViewStyle(
              contentColor: _optionTextColor(option.id),
              backgroundColor: _optionBackgroundColor(option.id),
              sizeUnit: TeXViewSizeUnit.pixels,
              textAlign: TeXViewTextAlign.center,
              fontStyle: TeXViewFontStyle(
                fontSize: 18,
                sizeUnit: TeXViewSizeUnit.pt,
              ),
              margin: const TeXViewMargin.only(top: 15),
              padding: const TeXViewPadding.only(
                left: 20,
                right: 20,
                bottom: 15,
                top: 15,
              ),
              borderRadius: const TeXViewBorderRadius.all(10),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _optionBackgroundColor(option.id),
            ),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Text(
              option.title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _optionTextColor(option.id),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          );
  }

  // TODO(J): Latex Options List
  // Sizing issues with Latex Options Lists.
  Widget _buildOptions() => Column(
    children: widget.args.questions[_currQueIdx].answerOptions!
        .map(_buildOption)
        .toList(),
  );

  Widget _buildGuessTheWordOptionAndAnswer(
    GuessTheWordQuestion guessTheWordQuestion,
  ) {
    final isCorrect =
        QuizUtils.buildGuessTheWordQuestionAnswer(
          guessTheWordQuestion.submittedAnswer,
        ) ==
        guessTheWordQuestion.answer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Padding(
          padding: EdgeInsets.zero,
          child: Text(
            "${context.tr("yourAnsLbl")!} : ${QuizUtils.buildGuessTheWordQuestionAnswer(guessTheWordQuestion.submittedAnswer)}",
            style: TextStyle(
              fontSize: 18,
              color: isCorrect
                  ? kCorrectAnswerColor
                  : Theme.of(context).colorScheme.onTertiary,
            ),
          ),
        ),
        if (!isCorrect) ...[
          Padding(
            padding: EdgeInsetsDirectional.zero,
            child: Text(
              "${context.tr("correctAndLbl")!}: ${guessTheWordQuestion.answer}",
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotes(String notes) {
    if (notes.isEmpty) return const SizedBox.shrink();

    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: context.width * 0.8,
      margin: const EdgeInsets.only(top: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(notesKey)!,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),

          ///
          if (isLatex)
            TeXView(
              child: TeXViewDocument(notes),
              style: TeXViewStyle(
                contentColor: primaryColor,
                sizeUnit: TeXViewSizeUnit.pixels,
                textAlign: TeXViewTextAlign.center,
              ),
            )
          else
            Text(notes, style: TextStyle(color: primaryColor)),
        ],
      ),
    );
  }

  Widget _buildQuestionAndOptions(Question question, int index) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuestionContainer(
            isMathQuestion: isLatex,
            question: question,
            questionColor: Theme.of(context).colorScheme.onTertiary,
          ),
          if (_isAudioQuestions)
            BlocProvider<MusicPlayerCubit>(
              create: (_) => MusicPlayerCubit(),
              child: MusicPlayerContainer(
                currentIndex: _currQueIdx,
                index: index,
                url: question.audio!,
                key: _musicPlayerKeys[index],
              ),
            )
          else
            const SizedBox(),

          //build options
          _buildOptions(),
          _buildNotes(question.note!),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildGuessTheWordQuestionAndOptions(GuessTheWordQuestion question) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          QuestionContainer(
            isMathQuestion: false,
            questionColor: Theme.of(context).colorScheme.onTertiary,
            question: Question(
              marks: '',
              id: question.id,
              question: question.question,
              imageUrl: question.image,
            ),
          ),
          //build options
          _buildGuessTheWordOptionAndAnswer(question),
        ],
      ),
    );
  }

  Widget _buildQuestions() {
    return SizedBox(
      height: context.height * 0.85,
      child: PageView.builder(
        onPageChanged: _onPageChanged,
        controller: _pageController,
        itemCount: questionsLength,
        itemBuilder: (_, idx) => Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.height * UiUtils.vtMarginPct,
            horizontal: context.width * UiUtils.hzMarginPct,
          ),
          child: _isGuessTheWord
              ? _buildGuessTheWordQuestionAndOptions(
                  widget.args.guessTheWordQuestions[idx],
                )
              : _buildQuestionAndOptions(widget.args.questions[idx], idx),
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return IconButton(
      onPressed: _onTapReportQuestion,
      icon: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildBookmarkButton() {
    if (widget.args.quizType == QuizTypes.quizZone) {
      final bookmarkCubit = context.read<BookmarkCubit>();
      final updateBookmarkCubit = context.read<UpdateBookmarkCubit>();
      return BlocListener<UpdateBookmarkCubit, UpdateBookmarkState>(
        bloc: updateBookmarkCubit,
        listener: (context, state) {
          if (state is UpdateBookmarkFailure) {
            if (state.errorMessageCode == errorCodeUnauthorizedAccess) {
              showAlreadyLoggedInDialog(context);
              return;
            }

            if (state.failedStatus == '0') {
              bookmarkCubit.addBookmarkQuestion(
                widget.args.questions[_currQueIdx],
              );
            } else {
              bookmarkCubit.removeBookmarkQuestion(
                widget.args.questions[_currQueIdx].id!,
              );
            }

            UiUtils.showSnackBar(
              context.tr(
                convertErrorCodeToLanguageKey(errorCodeUpdateBookmarkFailure),
              )!,
              context,
            );
          }
          if (state is UpdateBookmarkSuccess) {}
        },
        child: BlocBuilder<BookmarkCubit, BookmarkState>(
          bloc: bookmarkCubit,
          builder: (context, state) {
            if (state is BookmarkFetchSuccess) {
              final isBookmarked = bookmarkCubit.hasQuestionBookmarked(
                widget.args.questions[_currQueIdx].id!,
              );
              return InkWell(
                onTap: () {
                  if (isBookmarked) {
                    bookmarkCubit.removeBookmarkQuestion(
                      widget.args.questions[_currQueIdx].id!,
                    );
                    updateBookmarkCubit.updateBookmark(
                      widget.args.questions[_currQueIdx].id!,
                      '0',
                      '1',
                    );
                  } else {
                    bookmarkCubit.addBookmarkQuestion(
                      widget.args.questions[_currQueIdx],
                    );
                    updateBookmarkCubit.updateBookmark(
                      widget.args.questions[_currQueIdx].id!,
                      '1',
                      '1',
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isBookmarked
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
              );
            }

            if (state is BookmarkFetchFailure) {
              log('Bookmark Fetch Failure: ${state.errorMessageCode}');
            }
            return const SizedBox();
          },
        ),
      );
    }

    //if quiz type is audio questions
    if (widget.args.quizType == QuizTypes.audioQuestions) {
      final bookmarkCubit = context.read<AudioQuestionBookmarkCubit>();
      final updateBookmarkCubit = context.read<UpdateBookmarkCubit>();
      return BlocListener<UpdateBookmarkCubit, UpdateBookmarkState>(
        bloc: updateBookmarkCubit,
        listener: (context, state) {
          //if failed to update bookmark status
          if (state is UpdateBookmarkFailure) {
            if (state.errorMessageCode == errorCodeUnauthorizedAccess) {
              showAlreadyLoggedInDialog(context);
              return;
            }

            if (state.failedStatus == '0') {
              bookmarkCubit.addBookmarkQuestion(
                widget.args.questions[_currQueIdx],
              );
            } else {
              //remove again
              //if unable to add question to bookmark then remove question
              bookmarkCubit.removeBookmarkQuestion(
                widget.args.questions[_currQueIdx].id!,
              );
            }

            UiUtils.showSnackBar(
              context.tr(
                convertErrorCodeToLanguageKey(errorCodeUpdateBookmarkFailure),
              )!,
              context,
            );
          }
        },
        child:
            BlocBuilder<AudioQuestionBookmarkCubit, AudioQuestionBookMarkState>(
              bloc: bookmarkCubit,
              builder: (context, state) {
                if (state is AudioQuestionBookmarkFetchSuccess) {
                  final isBookmarked = bookmarkCubit.hasQuestionBookmarked(
                    widget.args.questions[_currQueIdx].id!,
                  );
                  return InkWell(
                    onTap: () {
                      if (isBookmarked) {
                        bookmarkCubit.removeBookmarkQuestion(
                          widget.args.questions[_currQueIdx].id!,
                        );
                        updateBookmarkCubit.updateBookmark(
                          widget.args.questions[_currQueIdx].id!,
                          '0',
                          '4',
                        ); //type is 4 for audio questions
                      } else {
                        bookmarkCubit.addBookmarkQuestion(
                          widget.args.questions[_currQueIdx],
                        );
                        updateBookmarkCubit.updateBookmark(
                          widget.args.questions[_currQueIdx].id!,
                          '1',
                          '4',
                        ); //type is 4 for audio questions
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isBookmarked
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        color: Theme.of(context).colorScheme.onTertiary,
                        size: 20,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
      );
    }

    if (widget.args.quizType == QuizTypes.guessTheWord) {
      final bookmarkCubit = context.read<GuessTheWordBookmarkCubit>();
      final updateBookmarkCubit = context.read<UpdateBookmarkCubit>();
      return BlocListener<UpdateBookmarkCubit, UpdateBookmarkState>(
        bloc: updateBookmarkCubit,
        listener: (context, state) {
          //if failed to update bookmark status
          if (state is UpdateBookmarkFailure) {
            if (state.errorMessageCode == errorCodeUnauthorizedAccess) {
              showAlreadyLoggedInDialog(context);
              return;
            }

            //remove bookmark question
            if (state.failedStatus == '0') {
              //if unable to remove question from bookmark then add question
              //add again
              bookmarkCubit.addBookmarkQuestion(
                widget.args.guessTheWordQuestions[_currQueIdx],
              );
            } else {
              //remove again
              //if unable to add question to bookmark then remove question
              bookmarkCubit.removeBookmarkQuestion(
                widget.args.guessTheWordQuestions[_currQueIdx].id,
              );
            }
            UiUtils.showSnackBar(
              context.tr(
                convertErrorCodeToLanguageKey(errorCodeUpdateBookmarkFailure),
              )!,
              context,
            );
          }
        },
        child:
            BlocBuilder<GuessTheWordBookmarkCubit, GuessTheWordBookmarkState>(
              bloc: context.read<GuessTheWordBookmarkCubit>(),
              builder: (context, state) {
                if (state is GuessTheWordBookmarkFetchSuccess) {
                  return InkWell(
                    onTap: () {
                      if (bookmarkCubit.hasQuestionBookmarked(
                        widget.args.guessTheWordQuestions[_currQueIdx].id,
                      )) {
                        //remove
                        bookmarkCubit.removeBookmarkQuestion(
                          widget.args.guessTheWordQuestions[_currQueIdx].id,
                        );
                        updateBookmarkCubit.updateBookmark(
                          widget.args.guessTheWordQuestions[_currQueIdx].id,
                          '0',
                          '3', //type is 3 for guess the word questions
                        );
                      } else {
                        //add
                        bookmarkCubit.addBookmarkQuestion(
                          widget.args.guessTheWordQuestions[_currQueIdx],
                        );
                        updateBookmarkCubit.updateBookmark(
                          widget.args.guessTheWordQuestions[_currQueIdx].id,
                          '1',
                          '3',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Icon(
                        bookmarkCubit.hasQuestionBookmarked(
                              widget.args.guessTheWordQuestions[_currQueIdx].id,
                            )
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        color: Theme.of(context).colorScheme.onTertiary,
                        size: 20,
                      ),
                    ),
                  );
                }

                return const SizedBox();
              },
            ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QAppBar(
        title: Text(context.tr('reviewAnswerLbl')!),
        actions: [
          _buildBookmarkButton(),
          if (widget.args.questions.isNotEmpty &&
              (widget.args.quizType == QuizTypes.quizZone ||
                  widget.args.quizType == QuizTypes.dailyQuiz ||
                  widget.args.quizType == QuizTypes.trueAndFalse ||
                  widget.args.quizType == QuizTypes.selfChallenge ||
                  widget.args.quizType == QuizTypes.oneVsOneBattle ||
                  widget.args.quizType == QuizTypes.groupPlay)) ...[
            _buildReportButton(),
          ],
        ],
      ),
      body: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: _buildQuestions()),
          Align(alignment: Alignment.bottomCenter, child: _buildBottomMenu()),
        ],
      ),
    );
  }
}
