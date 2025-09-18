import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/profile_management/cubits/update_score_and_coins_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/profile_management/profile_management_repository.dart';
import 'package:flutterquiz/features/quiz/cubits/quiz_category_cubit.dart';
import 'package:flutterquiz/features/quiz/cubits/unlock_premium_category_cubit.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

/// [_UnlockPremiumAlertDialog] handles showing the unlock confirmation dialog.
///
/// It takes in the category details needed to show the unlock dialog.
///
/// On press unlock:
/// - Calls UnlockPremiumCategoryCubit to unlock the category/subcategory
/// - Updates user coins via UpdateScoreAndCoinsCubit if unlock succeeds
/// - Shows success/error message
/// - Closes dialog on completion
///
/// It disables back button while dialog is open.
///
/// Parameters:
/// - categoryId: id of category/subcategory to unlock
/// - subcategoryId: optional subcategory id
/// - categoryName: name to show in dialog text
/// - requiredCoins: coins needed to unlock
/// - isQuizZone (bool): Whether this is a quizzone category
///
/// State handling:
/// - Shows initial unlock confirmation dialog
/// - Shows circular progress indicator when unlock in progress
/// - Shows success/error message based on unlock result
/// - Closes dialog and resets state when finished
///
Future<bool?> showUnlockPremiumCategoryDialog(
  BuildContext context, {
  required String categoryId,
  required String categoryName,
  required int requiredCoins,
  required QuizCategoryCubit categoryCubit,
}) async {
  return showDialog<bool?>(
    context: context,
    builder: (dialogCtx) => _UnlockPremiumAlertDialog(
      categoryId: categoryId,
      categoryName: categoryName,
      requiredCoins: requiredCoins,
      categoryCubit: categoryCubit,
    ),
  );
}

class _UnlockPremiumAlertDialog extends StatelessWidget {
  const _UnlockPremiumAlertDialog({
    required this.categoryId,
    required this.categoryName,
    required this.requiredCoins,
    required this.categoryCubit,
  });

  final String categoryId;
  final String categoryName;
  final int requiredCoins;
  final QuizCategoryCubit categoryCubit;

  ///--- Logic
  void _onPressedUnlock(BuildContext context) {
    final coins = int.parse(context.read<UserDetailsCubit>().getCoins() ?? '0');
    if (coins >= requiredCoins) {
      context.read<UnlockPremiumCategoryCubit>().unlockPremiumCategory(
        categoryId: categoryId,
      );
    } else {
      _closeDialog(context);
      showNotEnoughCoinsDialog(context);
      return;
    }
  }

  void _closeDialog(BuildContext context) {
    context.shouldPop();
    context.read<UnlockPremiumCategoryCubit>().reset();
  }

  ///--- UI

  Text _titleText(String textLbl, BuildContext context) {
    return Text(
      context.tr(textLbl) ?? textLbl,
      style: TextStyle(
        fontWeight: FontWeights.semiBold,
        fontSize: 16,
        color: context.colorScheme.onTertiary,
      ),
    );
  }

  TextButton _textBtn(
    String textLbl,
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        context.tr(textLbl) ?? textLbl,
        style: TextStyle(color: context.primaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useLbl = context.tr('useLbl');
    final coinsLbl = context.tr('coinsLbl');
    final unlockLbl = context.tr('unlockLbl');
    final unlockedLbl = context.tr('unlockedLbl');
    final unlockPremiumDescription = context.tr('unlockPremiumDescription')!;

    return MultiBlocProvider(
      providers: [
        BlocProvider<UpdateCoinsCubit>(
          create: (_) => UpdateCoinsCubit(ProfileManagementRepository()),
        ),
        BlocProvider.value(value: categoryCubit),
      ],
      child:
          BlocConsumer<UnlockPremiumCategoryCubit, UnlockPremiumCategoryState>(
            builder: (context, state) {
              if (state is UnlockPremiumCategoryInitial) {
                return AlertDialog(
                  shadowColor: Colors.transparent,
                  title: _titleText('$unlockLbl $categoryName', context),
                  content: Text(
                    unlockPremiumDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colorScheme.onTertiary.withValues(
                        alpha: .6,
                      ),
                    ),
                  ),
                  actions: [
                    PopScope(
                      canPop: state is! UnlockPremiumCategoryInProgress,
                      child: _textBtn(
                        'close',
                        context,
                        onPressed: () => _closeDialog(context),
                      ),
                    ),
                    _textBtn(
                      '$useLbl $requiredCoins $coinsLbl',
                      context,
                      onPressed: () => _onPressedUnlock(context),
                    ),
                  ],
                );
              }

              if (state is UnlockPremiumCategoryInProgress) {
                return const AlertDialog(content: CircularProgressContainer());
              }

              if (state is UnlockPremiumCategoryFailure) {
                return AlertDialog(
                  content: _titleText('defaultErrorMessage', context),
                  actions: [
                    _textBtn(
                      'close',
                      context,
                      onPressed: () => _closeDialog(context),
                    ),
                  ],
                );
              }

              return const SizedBox();
            },
            listener: (context, state) {
              if (state is UnlockPremiumCategorySuccess) {
                context.read<QuizCategoryCubit>().unlockPremiumCategory(
                  id: categoryId,
                );

                // update user coins to remote DS
                context.read<UpdateCoinsCubit>().updateCoins(
                  coins: requiredCoins,
                  addCoin: false,
                  title: '$unlockedLbl $categoryName',
                );
                // update user coins to local DS
                context.read<UserDetailsCubit>().updateCoins(
                  addCoin: false,
                  coins: requiredCoins,
                );

                UiUtils.showSnackBar('$unlockedLbl $categoryName', context);
                context.shouldPop(true);
                Future.delayed(
                  const Duration(milliseconds: 20),
                  context.read<UnlockPremiumCategoryCubit>().reset,
                );
              }
            },
          ),
    );
  }
}
