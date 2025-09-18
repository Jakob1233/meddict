import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/ads/blocs/rewarded_ad_cubit.dart';
import 'package:flutterquiz/features/battle_room/cubits/battle_room_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/update_score_and_coins_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/profile_management/profile_management_repository.dart';
import 'package:flutterquiz/features/quiz/cubits/quiz_category_cubit.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/screens/battle/create_or_join_screen.dart';
import 'package:flutterquiz/ui/screens/battle/widgets/top_curve_clipper.dart';
import 'package:flutterquiz/ui/widgets/already_logged_in_dialog.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';
import 'package:flutterquiz/ui/widgets/custom_rounded_button.dart';
import 'package:flutterquiz/ui/widgets/watch_reward_ad_dialog.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class RandomBattleScreen extends StatefulWidget {
  const RandomBattleScreen({super.key});

  static Route<RandomBattleScreen> route(RouteSettings settings) {
    return CupertinoPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => UpdateCoinsCubit(ProfileManagementRepository()),
        child: const RandomBattleScreen(),
      ),
    );
  }

  @override
  State<RandomBattleScreen> createState() => _RandomBattleScreenState();
}

class _RandomBattleScreenState extends State<RandomBattleScreen> {
  String selectedCategory = selectCategoryKey;
  String selectedCategoryId = '0';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      context.read<RewardedAdCubit>().createRewardedAd(context);
      if (context.read<SystemConfigCubit>().isCategoryEnabledForRandomBattle) {
        _getCategories();
      }
    });
  }

  void _getCategories() {
    context.read<QuizCategoryCubit>().getQuizCategoryWithUserId(
      languageId: UiUtils.getCurrentQuizLanguageId(context),
      type: UiUtils.getCategoryTypeNumberFromQuizType(QuizTypes.oneVsOneBattle),
      subType: UiUtils.subTypeFromQuizType(QuizTypes.oneVsOneBattle),
    );
  }

  void _addCoinsAfterRewardAd() {
    final rewardAdsCoins = context.read<SystemConfigCubit>().rewardAdsCoins;

    context.read<UserDetailsCubit>().updateCoins(
      addCoin: true,
      coins: rewardAdsCoins,
    );

    context.read<UpdateCoinsCubit>().updateCoins(
      coins: rewardAdsCoins,
      addCoin: true,
      type: watchedRewardAdKey,
      title: watchedRewardAdKey,
    );
  }

  Widget _buildDropDown({
    required List<Map<String, String?>> values,
    required String keyValue,
  }) {
    selectedCategory = values.map((e) => e['name']).toList().first!;
    selectedCategoryId = values.map((e) => e['id']).toList().first!;

    return StatefulBuilder(
      builder: (context, setState) {
        final optionNames = values
            .map((entry) => entry['name'])
            .whereType<String>()
            .toList(growable: false);

        String labelFor(String name) {
          if (name == selectCategoryKey) {
            return context.tr(selectCategoryKey) ?? name;
          }
          return name;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: AppDropdown<String>(
            key: ValueKey<String>(keyValue),
            hintText: context.tr(selectCategoryKey) ?? 'Kategorie wählen',
            items: optionNames,
            itemLabel: labelFor,
            value: selectedCategory,
            searchable: optionNames.length > 6,
            borderRadius: 16,
            onChanged: (value) {
              final selectedValue = value ?? selectCategoryKey;
              setState(() {
                selectedCategory = selectedValue;

                for (final v in values) {
                  if (v['name'] == selectedValue) {
                    selectedCategoryId = v['id'] ?? '0';
                  }
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget selectCategoryDropDown() {
    return context.read<SystemConfigCubit>().isCategoryEnabledForRandomBattle
        ? BlocConsumer<QuizCategoryCubit, QuizCategoryState>(
            listener: (context, state) {
              if (state is QuizCategorySuccess) {
                setState(() {
                  selectedCategory = state.categories.first.categoryName!;
                  selectedCategoryId = state.categories.first.id!;
                });
              }

              if (state is QuizCategoryFailure) {
                if (state.errorMessage == errorCodeUnauthorizedAccess) {
                  showAlreadyLoggedInDialog(context);
                  return;
                }
                showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    actions: [
                      TextButton(
                        onPressed: () => dialogCtx.pop(true),
                        child: Text(
                          context.tr(retryLbl)!,
                          style: TextStyle(color: context.primaryColor),
                        ),
                      ),
                    ],
                    content: Text(
                      context.tr(
                        convertErrorCodeToLanguageKey(state.errorMessage),
                      )!,
                    ),
                  ),
                ).then((value) {
                  if (value != null && value) {
                    _getCategories();
                  }
                });
              }
            },
            builder: (context, state) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: state is QuizCategorySuccess
                    ? _buildDropDown(
                        values: state.categories
                            .where((c) => !c.isPremium)
                            .map((e) => {'name': e.categoryName, 'id': e.id})
                            .toList(),
                        keyValue: 'selectCategorySuccess',
                      )
                    : Opacity(
                        opacity: 0.65,
                        child: _buildDropDown(
                          values: [
                            {'name': selectCategoryKey, 'id': '0'},
                          ],
                          keyValue: 'selectCategory',
                        ),
                      ),
              );
            },
          )
        : const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateCoinsCubit, UpdateCoinsState>(
      listener: (context, state) {
        if (state is UpdateCoinsFailure) {
          if (state.errorMessage == errorCodeUnauthorizedAccess) {
            showAlreadyLoggedInDialog(context);
          }
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: context.width,
            height: context.height,
            child: Stack(
              children: [
                /// Title & Back Btn
                Container(
                  width: context.width,
                  height: context.height * .45,
                  color: Theme.of(context).primaryColor,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      /// BG
                      SvgPicture.asset(
                        Assets.battleDesignImg,
                        fit: BoxFit.cover,
                        width: context.width,
                        height: context.height,
                      ),

                      /// VS
                      Padding(
                        padding: const EdgeInsets.only(top: 75, left: 3),
                        child: SvgPicture.asset(
                          Assets.vsImg,
                          width: 247.177,
                          height: 126.416,
                        ),
                      ),

                      /// Title & Back Button
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: context.height * 0.07,
                          start: 25,
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: AlignmentDirectional.topStart,
                              child: GestureDetector(
                                onTap: Navigator.of(context).pop,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 24.5,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.topCenter,
                              child: Text(
                                context.tr('randomLbl')!,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Theme.of(context).colorScheme.surface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  child: ClipPath(
                    clipper: TopCurveClipper(),
                    child: Container(
                      width: context.width,
                      height: context.height * .63,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.width * UiUtils.hzMarginPct,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: context.height * .07),

                          /// Select Category
                          if (context
                              .read<SystemConfigCubit>()
                              .isCategoryEnabledForRandomBattle)
                            Text(
                              context.tr(selectCategoryKey)!,
                              style: TextStyle(
                                fontWeight: FontWeights.regular,
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onTertiary,
                              ),
                            ),

                          /// dropDown
                          if (context
                              .read<SystemConfigCubit>()
                              .isCategoryEnabledForRandomBattle)
                            SizedBox(height: context.height * .01),
                          if (context
                              .read<SystemConfigCubit>()
                              .isCategoryEnabledForRandomBattle)
                            selectCategoryDropDown(),

                          /// Entry fees & Current user coins
                          SizedBox(height: context.height * .02),
                          _buildEntryFeesAndCoinsCard(context),

                          /// Let's Play
                          SizedBox(height: context.height * .04),
                          letsPlayButton(context),

                          if (context
                              .read<SystemConfigCubit>()
                              .isOneVsOneBattleEnabled) ...[
                            /// OR
                            SizedBox(height: context.height * .02),
                            _buildOrDivider(context),

                            /// Let's Play
                            SizedBox(height: context.height * .02),
                            playWithFrndsButton(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CustomRoundedButton playWithFrndsButton(BuildContext context) {
    return CustomRoundedButton(
      widthPercentage: context.width,
      backgroundColor: Theme.of(context).primaryColor,
      buttonTitle: context.tr('playWithFrdLbl'),
      radius: 8,
      showBorder: false,
      height: context.height * .07,
      fontWeight: FontWeights.semiBold,
      textSize: 18,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute<CreateOrJoinRoomScreen>(
            builder: (_) => BlocProvider<UpdateCoinsCubit>(
              create: (_) => UpdateCoinsCubit(ProfileManagementRepository()),
              child: CreateOrJoinRoomScreen(
                quizType: QuizTypes.oneVsOneBattle,
                title: context.tr('playWithFrdLbl')!,
              ),
            ),
          ),
        );
      },
    );
  }

  CustomRoundedButton letsPlayButton(BuildContext context) {
    return CustomRoundedButton(
      widthPercentage: context.width,
      backgroundColor: Theme.of(context).primaryColor,
      buttonTitle: context.tr('letsPlay'),
      radius: 8,
      showBorder: false,
      height: context.height * .07,
      fontWeight: FontWeights.semiBold,
      textSize: 18,
      onTap: () {
        final userProfile = context.read<UserDetailsCubit>().getUserProfile();

        if (int.parse(userProfile.coins!) <
            context.read<SystemConfigCubit>().randomBattleEntryCoins) {
          //if ad not loaded than show not enough coins
          if (context.read<RewardedAdCubit>().state is! RewardedAdLoaded) {
            UiUtils.errorMessageDialog(
              context,
              context.tr(
                convertErrorCodeToLanguageKey(errorCodeNotEnoughCoins),
              ),
            );
            return;
          }

          showDialog<void>(
            context: context,
            builder: (_) => WatchRewardAdDialog(
              onTapYesButton: () {
                //showAd
                context.read<RewardedAdCubit>().showAd(
                  context: context,
                  onAdDismissedCallback: _addCoinsAfterRewardAd,
                );
              },
            ),
          );
          return;
        }
        if (selectedCategory == selectCategoryKey &&
            context
                .read<SystemConfigCubit>()
                .isCategoryEnabledForRandomBattle) {
          UiUtils.errorMessageDialog(
            context,
            context.tr(pleaseSelectCategoryKey),
          );
          return;
        }

        context.read<BattleRoomCubit>().updateState(BattleRoomInitial());

        Navigator.of(context).pushReplacementNamed(
          Routes.battleRoomFindOpponent,
          arguments: selectedCategoryId,
        );
      },
    );
  }

  Container _buildEntryFeesAndCoinsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      width: context.width,
      height: context.height * .14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "${context.tr("entryFeesLbl")!}\n",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeights.regular,
                    color: Theme.of(
                      context,
                    ).colorScheme.onTertiary.withValues(alpha: .4),
                  ),
                ),
                TextSpan(
                  text:
                      '${context.read<SystemConfigCubit>().randomBattleEntryCoins} ${context.tr(coinsLbl)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeights.bold,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(
            indent: context.width * .07,
            endIndent: context.width * .07,
            color: Theme.of(
              context,
            ).colorScheme.onTertiary.withValues(alpha: .6),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${context.tr(currentCoinsKey)!}\n',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeights.regular,
                    color: Theme.of(
                      context,
                    ).colorScheme.onTertiary.withValues(alpha: .4),
                  ),
                ),
                WidgetSpan(
                  child: BlocBuilder<UserDetailsCubit, UserDetailsState>(
                    bloc: context.read<UserDetailsCubit>(),
                    builder: (context, state) {
                      return state is UserDetailsFetchSuccess
                          ? Text(
                              '${context.read<UserDetailsCubit>().getCoins()!} ${context.tr(coinsLbl)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeights.bold,
                                color: Theme.of(context).colorScheme.onTertiary,
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Row _buildOrDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(
              context,
            ).colorScheme.onTertiary.withValues(alpha: .6),
            thickness: .5,
            indent: context.width * .1,
            endIndent: context.width * .05,
          ),
        ),
        Text(
          context.tr(orLbl)!,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeights.regular,
            color: Theme.of(
              context,
            ).colorScheme.onTertiary.withValues(alpha: .6),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(
              context,
            ).colorScheme.onTertiary.withValues(alpha: .6),
            thickness: .5,
            indent: context.width * .05,
            endIndent: context.width * .1,
          ),
        ),
      ],
    );
  }
}
