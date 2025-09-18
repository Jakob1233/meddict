import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/badges/cubits/badges_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/audio_question_bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/guess_the_word_bookmark_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/delete_account_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/profile_management/profile_management_repository.dart';
import 'package:flutterquiz/ui/widgets/all.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

void showDeleteAccountDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => BlocProvider(
      lazy: false,
      create: (_) => DeleteAccountCubit(ProfileManagementRepository()),
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.width * UiUtils.hzMarginPct,
        ),
        alignment: Alignment.center,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.symmetric(
          vertical: context.height * UiUtils.vtMarginPct,
          horizontal: context.width * UiUtils.hzMarginPct,
        ),
        title: BlocConsumer<DeleteAccountCubit, DeleteAccountState>(
          listener: (context, state) {
            if (state is DeleteAccountFailure) {
              dialogCtx.shouldPop();
              UiUtils.showSnackBar(
                context.tr(convertErrorCodeToLanguageKey(state.errorMessage))!,
                context,
              );
            }
            if (state is DeleteAccountSuccess) {
              context.read<BadgesCubit>().updateState(BadgesInitial());
              context.read<BookmarkCubit>().updateState(BookmarkInitial());
              context.read<GuessTheWordBookmarkCubit>().updateState(
                GuessTheWordBookmarkInitial(),
              );

              context.read<AudioQuestionBookmarkCubit>().updateState(
                AudioQuestionBookmarkInitial(),
              );

              context.read<AuthCubit>().logoutOrDeleteAccount();
              context.read<UserDetailsCubit>().logoutOrDeleteAccount();

              //
              UiUtils.showSnackBar(
                context.tr(accountDeletedSuccessfullyKey)!,
                context,
              );

              dialogCtx.shouldPop();
              globalCtx.pushReplacementNamed(Routes.login);
            }
          },
          builder: (context, state) {
            if (state is DeleteAccountInProgress) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressContainer(size: 45),
                  const SizedBox(width: 16),
                  Text(
                    context.tr(deletingAccountKey)!,
                    style: TextStyle(color: context.primaryColor, fontSize: 16),
                  ),
                ],
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QImage(
                  imageUrl: Assets.deleteAccount,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  context.tr('deleteAccountLbl')!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeights.bold,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 19),
                Text(
                  context.tr('deleteAccConfirmation')!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: context.primaryTextColor,
                  ),
                ),

                ///
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () {
                    context.read<DeleteAccountCubit>().deleteUserAccount();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      context.primaryColor,
                    ),
                  ),
                  child: Text(
                    context.tr('yesDeleteAcc')!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeights.semiBold,
                      color: context.surfaceColor,
                    ),
                  ),
                ),

                ///
                const SizedBox(height: 20),
                TextButton(
                  onPressed: dialogCtx.pop,
                  child: Text(
                    context.tr('keepAccount')!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeights.semiBold,
                      color: context.primaryColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
