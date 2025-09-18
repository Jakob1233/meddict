import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/settings/settings_cubit.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/screens/app_settings_screen.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/delete_account_dialog.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/language_selector_sheet.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/logout_dialog.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/quiz_language_selector_sheet.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/theme_selector_sheet.dart';
import 'package:flutterquiz/ui/screens/profile/create_or_edit_profile_screen.dart';
import 'package:flutterquiz/ui/dev/admin_portal_gate.dart';
import 'package:flutterquiz/ui/widgets/all.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/gdpr_helper.dart';
import 'package:flutterquiz/utils/ui_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => ProfileTabScreenState();
}

class ProfileTabScreenState extends State<ProfileTabScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  bool get _isGuest => context.read<AuthCubit>().isGuest;

  final List<({String image, String name})> menu = [
    (name: 'wallet', image: Assets.walletMenuIcon),
    (name: 'coinHistory', image: Assets.coinHistoryMenuIcon),
    (name: 'inviteFriendsLbl', image: Assets.inviteFriendsMenuIcon),
    //
    (name: 'bookmarkLbl', image: Assets.bookmarkMenuIcon),
    (name: 'badges', image: Assets.badgesMenuIcon),
    (name: 'rewardsLbl', image: Assets.rewardMenuIcon),
    (name: 'statisticsLabel', image: Assets.statisticsMenuIcon),
    (name: 'theme', image: Assets.themeMenuIcon),
    (name: 'quizLanguage', image: Assets.quizLanguageIcon),
    (name: 'language', image: Assets.languageMenuIcon),
    (name: 'soundLbl', image: Assets.volumeIcon),
    (name: 'vibrationLbl', image: Assets.vibrationIcon),
    (name: 'adsPreference', image: Assets.adsPreferenceIcon),
    (name: 'aboutQuizApp', image: Assets.aboutUsMenuIcon),
    (name: howToPlayLbl, image: Assets.howToPlayMenuIcon),
    (name: 'shareAppLbl', image: Assets.shareMenuIcon),
    (name: 'rateUsLbl', image: Assets.rateMenuIcon),
    (name: 'logoutLbl', image: Assets.logoutMenuIcon),
    (name: 'deleteAccountLbl', image: Assets.deleteAccountMenuIcon),
  ];

  @override
  void initState() {
    super.initState();
    final config = context.read<SystemConfigCubit>();

    Future.delayed(Duration.zero, () async {
      if (!config.isPaymentRequestEnabled) {
        menu.removeWhere((e) => e.name == 'wallet');
      }
      if (!config.isLanguageModeEnabled) {
        menu.removeWhere((e) => e.name == 'quizLanguage');
      }

      if (!(config.isQuizZoneEnabled ||
          config.isGuessTheWordEnabled ||
          config.isAudioQuizEnabled)) {
        menu.removeWhere((e) => e.name == 'bookmarkLbl');
      }

      if (_isGuest) {
        menu
          ..removeWhere((e) => e.name == 'logoutLbl')
          ..removeWhere((e) => e.name == 'deleteAccountLbl');
      }

      if (context.read<AppLocalizationCubit>().state.systemLanguages.length ==
          1) {
        menu.removeWhere((e) => e.name == 'language');
      }

      if (!await GdprHelper.isUnderGdpr()) {
        setState(() {
          menu.removeWhere((e) => e.name == 'adsPreference');
        });
      }
    });

    context.read<AuthCubit>().stream.listen((state) {
      if (state is Authenticated) {
        menu
          ..add((name: 'logoutLbl', image: Assets.logoutMenuIcon))
          ..add((
            name: 'deleteAccountLbl',
            image: Assets.deleteAccountMenuIcon,
          ));
      } else if (state is Unauthenticated) {
        menu
          ..removeWhere((e) => e.name == 'logoutLbl')
          ..removeWhere((e) => e.name == 'deleteAccountLbl');
      }
    });
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

  void _onTapMenuItem(String name) {
    /// Menus that guest can use without being logged in.
    switch (name) {
      case 'theme':
        showThemeSelectorSheet(globalCtx);
        return;
      case 'quizLanguage':
        showQuizLanguageSelectorSheet(globalCtx);
        return;
      case 'language':
        showLanguageSelectorSheet(globalCtx, onChange: () => setState(() {}));
        return;
      case 'aboutQuizApp':
        globalCtx.pushNamed(Routes.aboutApp);
        return;
      case howToPlayLbl:
        globalCtx.pushNamed(
          Routes.appSettings,
          arguments: const AppSettingsScreenArgs(howToPlayLbl),
        );
        return;
      case 'shareAppLbl':
        {
          try {
            UiUtils.share(
              '${context.read<SystemConfigCubit>().appUrl}\n${context.read<SystemConfigCubit>().shareAppText}',
              context: globalCtx,
            );
          } on Exception catch (e) {
            UiUtils.showSnackBar(e.toString(), context);
          }
        }
        return;
      case 'rateUsLbl':
        launchUrl(Uri.parse(context.read<SystemConfigCubit>().appUrl));
        return;
      case 'adsPreference':
        GdprHelper.changePrivacyPreferences();
        return;
    }

    /// Menus that users can't use without signing in, (ex. in guest mode).
    if (_isGuest) {
      showLoginRequiredDialog(context);
      return;
    }

    switch (name) {
      case 'coinHistory':
        globalCtx.pushNamed(Routes.coinHistory);
        return;
      case 'wallet':
        globalCtx.pushNamed(Routes.wallet);
        return;
      case 'bookmarkLbl':
        globalCtx.pushNamed(Routes.bookmark);
        return;
      case 'inviteFriendsLbl':
        globalCtx.pushNamed(Routes.referAndEarn);
        return;
      case 'badges':
        globalCtx.pushNamed(Routes.badges);
        return;
      case 'rewardsLbl':
        globalCtx.pushNamed(Routes.rewards);
        return;
      case 'statisticsLabel':
        globalCtx.pushNamed(Routes.statistics);
        return;
      case 'logoutLbl':
        showLogoutDialog(globalCtx);
        return;
      case 'deleteAccountLbl':
        showDeleteAccountDialog(globalCtx);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: [
          _buildProfileHeader(),

          ///
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: context.width * UiUtils.hzMarginPct,
                vertical: context.height * UiUtils.vtMarginPct,
              ),
              children: [
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  crossAxisSpacing: 20,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(3, _buildGridViewItem),
                ),
                const SizedBox(height: 16),
                if (!_isGuest &&
                    FirebaseAuth.instance.currentUser?.email
                            ?.toLowerCase() ==
                        'j.pleiner.1@gmail.com') ...[
                  OutlinedButton.icon(
                    onPressed: AdminPortalGate.open,
                    icon: const Icon(Icons.build),
                    label: const Text('Exameter-Import öffnen'),
                  ),
                  const SizedBox(height: 16),
                ],

                ///
                ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: menu.length - 3,
                  separatorBuilder: (_, i) =>
                      const SizedBox(height: UiUtils.listTileGap),
                  itemBuilder: (_, i) {
                    return _buildListViewItem(
                      i + 3,
                      trailing: () {
                        final name = menu[i + 3].name;
                        if (name == 'soundLbl') {
                          return BlocBuilder<SettingsCubit, SettingsState>(
                            builder: (context, state) {
                              return CustomSwitch(
                                value: state.settingsModel!.sound,
                                onChanged: (v) => setState(() {
                                  context.read<SettingsCubit>().sound = v;
                                }),
                              );
                            },
                          );
                        } else if (name == 'vibrationLbl') {
                          return BlocBuilder<SettingsCubit, SettingsState>(
                            builder: (context, state) {
                              return CustomSwitch(
                                value: state.settingsModel!.vibration,
                                onChanged: (v) => setState(() {
                                  context.read<SettingsCubit>().vibration = v;
                                }),
                              );
                            },
                          );
                        }

                        return null;
                      }(),
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    void onTapEditProfile() {
      if (_isGuest) {
        showLoginRequiredDialog(context);
        return;
      }

      globalCtx.pushNamed(
        Routes.selectProfile,
        arguments: const CreateOrEditProfileScreenArgs(isNewUser: false),
      );
    }

    return SizedBox(
      height: context.height * .25,
      width: double.maxFinite,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final maxWidth = constraints.maxWidth;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                height: maxHeight * .8,
                width: maxWidth,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Text(
                  context.tr('profileLbl')!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: maxHeight * .35,
                      width: maxWidth * .8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(200),
                        boxShadow: [
                          BoxShadow(
                            color: context.primaryTextColor.withValues(
                              alpha: .1,
                            ),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: maxHeight * .45,
                      margin: EdgeInsets.symmetric(
                        horizontal: context.width * UiUtils.hzMarginPct,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxHeight = constraints.maxHeight;

                          return BlocBuilder<
                            UserDetailsCubit,
                            UserDetailsState
                          >(
                            builder: (context, state) {
                              if (state is UserDetailsFetchInProgress) {
                                return const Center(
                                  child: CircularProgressContainer(),
                                );
                              }

                              var profileUrl = '';
                              var username = context.tr('helloGuest')!;
                              var profileDesc = context.tr(
                                'provideGuestDetails',
                              )!;

                              if (state is UserDetailsFetchSuccess) {
                                profileUrl = state.userProfile.profileUrl!;
                                username = state.userProfile.name!;

                                if (context
                                        .read<AuthCubit>()
                                        .getAuthProvider() ==
                                    AuthProviders.mobile) {
                                  profileDesc =
                                      state.userProfile.mobileNumber ?? '';
                                } else {
                                  profileDesc = state.userProfile.email ?? '';
                                }
                              }

                              return Row(
                                children: [
                                  Container(
                                    height: maxHeight,
                                    width: maxHeight,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.primaryTextColor
                                            .withValues(alpha: .1),
                                      ),
                                    ),
                                    child: QImage.circular(
                                      imageUrl: profileUrl,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            username,
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              color: context.primaryTextColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Flexible(
                                          child: SizedBox(height: 4),
                                        ),
                                        Flexible(
                                          child: Text(
                                            profileDesc,
                                            style: TextStyle(
                                              color: context.primaryTextColor
                                                  .withValues(alpha: .3),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: onTapEditProfile,
                                    child: Container(
                                      height: maxHeight * .5,
                                      width: maxHeight * .5,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.primaryTextColor
                                              .withValues(alpha: .1),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: QImage(
                                        imageUrl: Assets.editIcon,
                                        color: context.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGridViewItem(int idx) {
    return InkWell(
      onTap: () => _onTapMenuItem(menu[idx].name),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Image
            Container(
              height: 44,
              width: 44,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: context.scaffoldBackgroundColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: QImage(
                imageUrl: menu[idx].image,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 85,
              child: Text(
                context.tr(menu[idx].name)!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeights.regular,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 14,
                  color: context.primaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListViewItem(int idx, {Widget? trailing}) {
    return InkWell(
      onTap: () => _onTapMenuItem(menu[idx].name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            QImage(
              imageUrl: menu[idx].image,
              color: context.primaryColor,
              fit: BoxFit.fitHeight,
              height: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(menu[idx].name)!,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontWeight: FontWeights.regular,
                  fontSize: 16,
                  color: context.primaryTextColor,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
