import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/ads/blocs/interstitial_ad_cubit.dart';
import 'package:flutterquiz/features/badges/badge.dart';
import 'package:flutterquiz/features/badges/cubits/badges_cubit.dart';
import 'package:flutterquiz/features/statistic/cubits/statistics_cubit.dart';
import 'package:flutterquiz/ui/widgets/already_logged_in_dialog.dart';
import 'package:flutterquiz/ui/widgets/badges_icon_container.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/ui/widgets/error_container.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  static Route<BadgesScreen> route(RouteSettings routeSettings) {
    return CupertinoPageRoute(builder: (_) => const BadgesScreen());
  }

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      context.read<BadgesCubit>().getBadges();
    });

    Future.delayed(Duration.zero, () {
      UiUtils.updateBadgesLocally(context);
      context.read<StatisticCubit>().getStatistic();
    });

    Future.delayed(Duration.zero, () {
      context.read<InterstitialAdCubit>().showAd(context);
    });
  }

  void showBadgeDetails(BuildContext context, Badges badge) {
    showModalBottomSheet<void>(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 5,
      shape: const RoundedRectangleBorder(
        borderRadius: UiUtils.bottomSheetTopRadius,
      ),
      context: context,
      builder: (context) {
        final regularTextStyle = TextStyle(
          fontWeight: FontWeights.regular,
          color: Theme.of(context).colorScheme.onTertiary,
          fontSize: 16,
        );

        return Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: const BoxDecoration(
            borderRadius: UiUtils.bottomSheetTopRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: context.height * .25,
                width: context.width * .3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return BadgesIconContainer(
                      badge: badge,
                      constraints: constraints,
                      addTopPadding: true,
                    );
                  },
                ),
              ),
              Transform.translate(
                offset: Offset(0, context.height * (-0.05)),
                child: Column(
                  children: [
                    Text(
                      context.tr('${badge.type}_label') ?? badge.type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: badge.status == BadgesStatus.locked
                            ? kBadgeLockedColor
                            : Theme.of(context).colorScheme.onTertiary,
                        fontWeight: FontWeights.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      context.tr('${badge.type}_note') ?? badge.type,
                      textAlign: TextAlign.center,
                      style: regularTextStyle,
                    ),
                    const SizedBox(height: 2.5),
                    //
                    if (badge.type == 'big_thing' &&
                        badge.status == BadgesStatus.locked)
                      BlocBuilder<StatisticCubit, StatisticState>(
                        bloc: context.read<StatisticCubit>(),
                        builder: (context, state) {
                          if (state is StatisticInitial ||
                              state is StatisticFetchInProgress) {
                            return const Center(
                              child: SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressContainer(size: 15),
                              ),
                            );
                          }
                          if (state is StatisticFetchFailure) {
                            return const SizedBox();
                          }
                          if (state is StatisticFetchSuccess) {
                            final statisticDetails = state.statisticModel;
                            final answerToGo =
                                int.parse(badge.badgeCounter) -
                                int.parse(statisticDetails.correctAnswers);

                            return Column(
                              children: [
                                Text(
                                  '${context.tr(needMoreKey)} $answerToGo ${context.tr(correctAnswerToUnlockKey)}',
                                  textAlign: TextAlign.center,
                                  style: regularTextStyle,
                                ),
                                const SizedBox(height: 5),
                              ],
                            );
                          }
                          return const SizedBox();
                        },
                      )
                    else
                      const SizedBox(),

                    Text(
                      '${context.tr(getKey)} ${badge.badgeReward} ${context.tr(coinsUnlockingByBadgeKey)}',
                      textAlign: TextAlign.center,
                      style: regularTextStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Badges> _organizedBadges(List<Badges> badges) {
    final lockedBadges = badges
        .where((b) => b.status == BadgesStatus.locked)
        .toList(growable: false);

    final unlockedBadges = badges
        .where((b) => b.status != BadgesStatus.locked)
        .toList(growable: false);

    return [...unlockedBadges, ...lockedBadges];
  }

  Widget _buildBadges() {
    final badgesCubit = context.read<BadgesCubit>();

    return BlocConsumer<BadgesCubit, BadgesState>(
      listener: (context, state) {
        if (state is BadgesFetchFailure) {
          if (state.errorMessage == errorCodeUnauthorizedAccess) {
            showAlreadyLoggedInDialog(context);
          }
        }
      },
      bloc: badgesCubit,
      builder: (context, state) {
        if (state is BadgesFetchInProgress || state is BadgesInitial) {
          return const Center(child: CircularProgressContainer());
        }
        if (state is BadgesFetchFailure) {
          return Center(
            child: ErrorContainer(
              errorMessage: context.tr(
                convertErrorCodeToLanguageKey(state.errorMessage),
              )!,
              onTapRetry: badgesCubit.getBadges,
              showErrorImage: true,
            ),
          );
        }
        final badges = _organizedBadges((state as BadgesFetchSuccess).badges);

        return RefreshIndicator(
          color: Theme.of(context).primaryColor,
          displacement:
              context.height * (UiUtils.appBarHeightPercentage + 0.025) + 20,
          onRefresh: () async => badgesCubit.getBadges(),
          child: GridView.builder(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 20),
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 7.5,
              mainAxisSpacing: 10,
              childAspectRatio: 0.575,
            ),
            itemBuilder: (context, index) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTap: () => showBadgeDetails(context, badges[index]),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight * 0.65,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: constraints.maxHeight * .4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    context.tr('${badges[index].type}_label') ??
                                        badges[index].type,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color:
                                          badges[index].status ==
                                              BadgesStatus.locked
                                          ? kBadgeLockedColor
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onTertiary, //
                                      fontSize: 16,
                                      height: 1.175,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        BadgesIconContainer(
                          badge: badges[index],
                          constraints: constraints,
                          addTopPadding: true,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QAppBar(title: Text(context.tr(badgesKey)!)),
      body: _buildBadges(),
    );
  }
}
