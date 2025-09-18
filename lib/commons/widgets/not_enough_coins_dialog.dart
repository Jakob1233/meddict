import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';

/// A dialog that prompts users to purchase more coins when they don't have enough
/// coins to access certain features.
///
/// This dialog is shown in various scenarios:
/// * When trying to enter a contest
/// * When attempting to unlock premium categories
/// * When trying to review answers
/// * When creating a battle room
/// * Any other feature that requires coins
///
/// The dialog provides two options:
/// * Close - Dismisses the dialog
/// * Buy Coins - Navigates to the coin store
///
/// Usage:
/// ```dart
/// await showNotEnoughCoinsDialog(context);
/// ```
Future<void> showNotEnoughCoinsDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (dialogCxt) => AlertDialog(
      key: const Key('notEnoughCoinsDialog'),
      title: Text(
        context.tr(notEnoughCoinsKey)!,
        style: context.titleLarge?.copyWith(color: context.primaryTextColor),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: dialogCxt.shouldPop,
          child: Text(
            context.tr('close')!,
            style: context.labelLarge?.copyWith(color: context.primaryColor),
          ),
        ),
        if (context.read<SystemConfigCubit>().isCoinStoreEnabled)
          TextButton(
            onPressed: () {
              dialogCxt
                ..shouldPop()
                ..pushNamed(Routes.coinStore);
            },
            child: Text(
              context.tr('buyCoins')!,
              style: context.labelLarge?.copyWith(
                color: context.primaryColor,
                fontWeight: FontWeights.semiBold,
              ),
            ),
          ),
      ],
    ),
  );
}
