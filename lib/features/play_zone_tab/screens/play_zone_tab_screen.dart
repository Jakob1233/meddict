import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/screens/home/widgets/quiz_grid_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/ui/screens/quiz/category_screen.dart';
import 'package:flutterquiz/ui/widgets/all.dart';

class PlayZoneTabScreen extends StatefulWidget {
  const PlayZoneTabScreen({super.key});

  @override
  State<PlayZoneTabScreen> createState() => PlayZoneTabScreenState();
}

class PlayZoneTabScreenState extends State<PlayZoneTabScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  final _playZones = <Zone>[];

  static const _enhancedZoneAssets = <QuizTypes, String>{
    QuizTypes.dailyQuiz: 'assets/images/gamezone/find.svg',
    QuizTypes.funAndLearn: 'assets/images/gamezone/fun.svg',
    QuizTypes.guessTheWord: 'assets/images/gamezone/find.svg',
    QuizTypes.audioQuestions: 'assets/images/gamezone/audio.svg',
    QuizTypes.mathMania: 'assets/images/gamezone/fun.svg',
    QuizTypes.trueAndFalse: 'assets/images/gamezone/truefalse.svg',
    QuizTypes.multiMatch: 'assets/images/gamezone/all.svg',
  };

  @override
  void initState() {
    super.initState();
    _initializePlayZones();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void onTapTab() {
    if (_scrollController.hasClients && _scrollController.offset != 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _initializePlayZones() {
    final config = context.read<SystemConfigCubit>();

    _playZones.addAll([
      if (config.isDailyQuizEnabled)
        (
          type: QuizTypes.dailyQuiz,
          title: 'dailyQuiz',
          img: Assets.dailyQuizIcon,
          desc: 'desDailyQuiz',
        ),
      if (config.isFunNLearnEnabled)
        (
          type: QuizTypes.funAndLearn,
          title: 'funAndLearn',
          img: Assets.funNLearnIcon,
          desc: 'desFunAndLearn',
        ),
      if (config.isGuessTheWordEnabled)
        (
          type: QuizTypes.guessTheWord,
          title: 'guessTheWord',
          img: Assets.guessTheWordIcon,
          desc: 'desGuessTheWord',
        ),
      if (config.isAudioQuizEnabled)
        (
          type: QuizTypes.audioQuestions,
          title: 'audioQuestions',
          img: Assets.audioQuizIcon,
          desc: 'desAudioQuestions',
        ),
      if (config.isMathQuizEnabled)
        (
          type: QuizTypes.mathMania,
          title: 'mathMania',
          img: Assets.mathsQuizIcon,
          desc: 'desMathMania',
        ),
      if (config.isTrueFalseQuizEnabled)
        (
          type: QuizTypes.trueAndFalse,
          title: 'truefalse',
          img: Assets.trueFalseQuizIcon,
          desc: 'desTrueFalse',
        ),
      if (config.isMultiMatchQuizEnabled)
        (
          type: QuizTypes.multiMatch,
          title: 'multiMatch',
          img: Assets.multiMatchIcon,
          desc: 'desMultiMatch',
        ),
    ]);
  }

  void _onTapQuiz(QuizTypes type) {
    // Check if the user is a guest, Show login required dialog for guest users
    if (context.read<AuthCubit>().isGuest) {
      showLoginRequiredDialog(context);
      return;
    }

    if (type case QuizTypes.dailyQuiz || QuizTypes.trueAndFalse) {
      // Daily Quiz and True/False Quiz navigate directly to quiz screen
      Navigator.of(
        globalCtx,
      ).pushNamed(Routes.quiz, arguments: {'quizType': type});
    } else {
      /// Other quiz types (FunAndLearn, GuessTheWord, AudioQuestions, etc)
      /// navigate to category selection screen first.
      globalCtx.pushNamed(
        Routes.category,
        arguments: CategoryScreenArgs(quizType: type),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: QAppBar(
        title: Text(context.tr('playZone')!),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.8,
          physics: const NeverScrollableScrollPhysics(),
          children: _playZones
              .map<Widget>((zone) {
                if (_enhancedZoneAssets.containsKey(zone.type)) {
                  return _PlayZoneCard(
                    title: context.tr(zone.title)!,
                    assetPath: _enhancedZoneAssets[zone.type]!,
                    onTap: () => _onTapQuiz(zone.type),
                  );
                }

                return QuizGridCard(
                  onTap: () => _onTapQuiz(zone.type),
                  title: context.tr(zone.title)!,
                  desc: context.tr(zone.desc)!,
                  img: zone.img,
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _PlayZoneCard extends StatelessWidget {
  const _PlayZoneCard({
    required this.title,
    required this.assetPath,
    required this.onTap,
  });

  final String title;
  final String assetPath;
  final VoidCallback onTap;

  static const _cardRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.light
        ? Colors.black
        : Colors.white;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w700,
          color: textColor,
          fontSize: 18,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            elevation: 12,
            shadowColor: const Color(0xff45536d),
            borderRadius: BorderRadius.circular(_cardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_cardRadius),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(_cardRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SvgPicture.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
