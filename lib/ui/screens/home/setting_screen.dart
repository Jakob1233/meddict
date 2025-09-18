import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/settings/settings_cubit.dart';
import 'package:flutterquiz/ui/screens/menu/widgets/language_selector_sheet.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/gdpr_helper.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  static Route<SettingScreen> route(RouteSettings settings) {
    return CupertinoPageRoute(builder: (_) => const SettingScreen());
  }

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  late final Future<bool> _isUnderGdpr;

  @override
  void initState() {
    super.initState();

    _isUnderGdpr = GdprHelper.isUnderGdpr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QAppBar(title: Text(context.tr('settingLbl')!)),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          vertical: context.height * UiUtils.vtMarginPct,
          horizontal: context.width * UiUtils.hzMarginPct,
        ),
        child: BlocBuilder(
          bloc: context.read<SettingsCubit>(),
          builder: (BuildContext context, state) {
            if (state is SettingsState) {
              final settingsCubit = context.read<SettingsCubit>();
              final settings = settingsCubit.getSettings();

              final size = context;
              final colorScheme = Theme.of(context).colorScheme;
              final primaryColor = Theme.of(context).primaryColor;
              final textStyle = TextStyle(
                fontSize: 16,
                fontWeight: FontWeights.regular,
                color: colorScheme.onTertiary,
              );

              return Column(
                children: [
                  /// Sound
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.standard,
                    tileColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      Icons.volume_down,
                      color: primaryColor,
                      size: 24,
                    ),
                    title: Text(context.tr('soundLbl')!, style: textStyle),
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(
                        activeTrackColor: primaryColor,
                        value: settings.sound,
                        onChanged: (v) => setState(() {
                          settingsCubit.sound = v;
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),

                  /// Vibration
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.standard,
                    tileColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      Icons.vibration,
                      color: primaryColor,
                      size: 24,
                    ),
                    title: Text(context.tr('vibrationLbl')!, style: textStyle),
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(
                        activeTrackColor: primaryColor,
                        value: settings.vibration,
                        onChanged: (v) => setState(() {
                          settingsCubit.vibration = v;
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),

                  /// Font Size
                  ListTile(
                    dense: true,
                    onTap: () {
                      showModalBottomSheet<void>(
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: UiUtils.bottomSheetTopRadius,
                        ),
                        context: context,
                        builder: (_) {
                          var fontSize = settings.playAreaFontSize;

                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: UiUtils.bottomSheetTopRadius,
                            ),
                            height: size.height * 0.6,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: StatefulBuilder(
                              builder: (_, state) {
                                return Column(
                                  children: [
                                    Align(
                                      child: Text(
                                        context.tr(fontSizeLbl)!,
                                        style: TextStyle(
                                          fontWeight: FontWeights.bold,
                                          fontSize: 18,
                                          color: colorScheme.onTertiary,
                                        ),
                                      ),
                                    ),
                                    // horizontal divider
                                    const Divider(),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            size.width * UiUtils.hzMarginPct,
                                      ),
                                      child: Text(
                                        context.tr('fontSizeDescText')!,
                                        maxLines: 4,
                                        style: textStyle.copyWith(
                                          fontSize: fontSize,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Slider(
                                      value: fontSize,
                                      min: 14,
                                      max: 20,
                                      divisions: 5,
                                      label: fontSize.toString(),
                                      activeColor: primaryColor,
                                      inactiveColor: colorScheme.onTertiary
                                          .withValues(alpha: .1),
                                      onChanged: (v) => state(() {
                                        fontSize = v;
                                        settingsCubit.changeFontSize(fontSize);
                                      }),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    visualDensity: VisualDensity.standard,
                    tileColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(Icons.abc, color: primaryColor, size: 24),
                    title: Text(context.tr(fontSizeLbl)!, style: textStyle),
                  ),
                  SizedBox(height: size.height * 0.02),

                  if (context
                          .read<AppLocalizationCubit>()
                          .state
                          .systemLanguages
                          .length >
                      1)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.standard,
                      tileColor: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(
                        Icons.language,
                        color: primaryColor,
                        size: 24,
                      ),
                      title: Text(context.tr('language')!, style: textStyle),
                      onTap: () {
                        showLanguageSelectorSheet(
                          context,
                          onChange: () {
                            setState(() {});
                          },
                        );
                      },
                    ),

                  ///
                  SizedBox(height: size.height * 0.02),
                  FutureBuilder<bool>(
                    future: _isUnderGdpr,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!) {
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.standard,
                          tileColor: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          leading: Icon(
                            Icons.ads_click_rounded,
                            color: primaryColor,
                            size: 24,
                          ),
                          onTap: GdprHelper.changePrivacyPreferences,
                          title: Text(
                            context.tr('adsPreference')!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeights.regular,
                              color: Theme.of(context).colorScheme.onTertiary,
                            ),
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }
}
