import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/badges/cubits/badges_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/audio_question_bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/bookmark_cubit.dart';
import 'package:flutterquiz/features/bookmark/cubits/guess_the_word_bookmark_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

void showLogoutDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.width * UiUtils.hzMarginPct,
        ),
        alignment: Alignment.center,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.symmetric(
          vertical: context.height * UiUtils.vtMarginPct,
          horizontal: context.width * UiUtils.hzMarginPct,
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SvgPicture.asset(Assets.logoutAccount),

            ///
            const SizedBox(height: 32),
            Text(
              context.tr(logoutLbl)!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.primaryTextColor,
              ),
            ),

            ///
            const SizedBox(height: 19),
            Text(
              context.tr(logoutDialogLbl)!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: context.primaryTextColor),
            ),

            ///
            const SizedBox(height: 33),
            TextButton(
              onPressed: () {
                dialogCtx.shouldPop();
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

                dialogCtx.shouldPop();
                context.pushReplacementNamed(Routes.login);
              },
              style: TextButton.styleFrom(
                backgroundColor: context.primaryColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: Text(
                context.tr('yesLogoutLbl')!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.surfaceColor,
                ),
              ),
            ),

            ///
            const SizedBox(height: 19),
            TextButton(
              style: TextButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: dialogCtx.shouldPop,
              child: Text(
                context.tr('stayLoggedLbl')!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
