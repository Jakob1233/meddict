import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/quiz/models/comprehension.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/ui/widgets/custom_rounded_button.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

class FunAndLearnScreen extends StatefulWidget {
  const FunAndLearnScreen({
    required this.quizType,
    required this.comprehension,
    required this.isPremiumCategory,
    required this.categoryId,
    this.subcategoryId,
    super.key,
  });

  final QuizTypes quizType;
  final Comprehension comprehension;
  final bool isPremiumCategory;
  final String categoryId;
  final String? subcategoryId;

  @override
  State<FunAndLearnScreen> createState() => _FunAndLearnScreen();

  static Route<dynamic> route(RouteSettings routeSettings) {
    final arguments = routeSettings.arguments as Map?;
    return CupertinoPageRoute(
      builder: (_) => FunAndLearnScreen(
        quizType: arguments!['quizType'] as QuizTypes,
        comprehension: arguments['comprehension'] as Comprehension,
        isPremiumCategory: arguments['isPremiumCategory'] as bool? ?? false,
        categoryId: arguments['categoryId'] as String,
        subcategoryId: arguments['subcategoryId'] as String? ?? '',
      ),
    );
  }
}

class _FunAndLearnScreen extends State<FunAndLearnScreen>
    with TickerProviderStateMixin {
  late final _ytController = YoutubePlayerController(
    initialVideoId: widget.comprehension.contentData,
    flags: const YoutubePlayerFlags(autoPlay: false),
  );

  @override
  void dispose() {
    super.dispose();
    _ytController.dispose();
  }

  void navigateToQuestionScreen() {
    Navigator.of(context).pushReplacementNamed(
      Routes.quiz,
      arguments: {
        'numberOfPlayer': 1,
        'quizType': QuizTypes.funAndLearn,
        'comprehension': widget.comprehension,
        'isPremiumCategory': widget.isPremiumCategory,
        'categoryId': widget.categoryId,
        'subcategoryId': widget.subcategoryId,
      },
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 30,
        left: context.width * UiUtils.hzMarginPct,
        right: context.width * UiUtils.hzMarginPct,
      ),
      child: CustomRoundedButton(
        widthPercentage: context.width,
        backgroundColor: Theme.of(context).primaryColor,
        buttonTitle: context.tr(letsStart),
        radius: 8,
        onTap: navigateToQuestionScreen,
        titleColor: Theme.of(context).colorScheme.surface,
        showBorder: false,
        height: 58,
        elevation: 5,
        textSize: 18,
        fontWeight: FontWeights.semiBold,
      ),
    );
  }

  bool showFullPdf = false;
  bool ytFullScreen = false;

  Widget _buildParagraph(Widget player) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      height: context.height * .75,
      margin: EdgeInsets.symmetric(
        horizontal: context.width * UiUtils.hzMarginPct,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            if (widget.comprehension.contentType == ContentType.yt &&
                widget.comprehension.contentData.isNotEmpty)
              player,
            if (widget.comprehension.contentType == ContentType.pdf &&
                widget.comprehension.contentData.isNotEmpty) ...[
              SizedBox(
                height: context.height * (showFullPdf ? .7 : 0.2),
                child: const PDF(
                  swipeHorizontal: true,
                  fitPolicy: FitPolicy.BOTH,
                ).fromUrl(widget.comprehension.contentData),
              ),
              TextButton(
                onPressed: () => setState(() => showFullPdf = !showFullPdf),
                child: Text(
                  context.tr(showFullPdf ? 'showLess' : 'showFull')!,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            HtmlWidget(
              widget.comprehension.detail,
              onErrorBuilder: (_, e, err) => Text('$e error: $err'),
              onLoadingBuilder: (_, e, l) => const Center(
                child: CircularProgressContainer(),
              ),
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onTertiary,
                fontWeight: FontWeights.regular,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController,
        progressIndicatorColor: Theme.of(context).primaryColor,
        progressColors: ProgressBarColors(
          playedColor: Theme.of(context).primaryColor,
          bufferedColor: Theme.of(
            context,
          ).colorScheme.onTertiary.withValues(alpha: .5),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: .5),
          handleColor: Theme.of(context).primaryColor,
        ),
      ),
      onExitFullScreen: () {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      },
      builder: (context, player) {
        return Scaffold(
          appBar: QAppBar(
            roundedAppBar: false,
            title: Text(widget.comprehension.title),
          ),
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _buildParagraph(player),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildStartButton(),
              ),
            ],
          ),
        );
      },
    );
  }
}
