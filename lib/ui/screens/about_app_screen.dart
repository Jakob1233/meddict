import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/ui/screens/app_settings_screen.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static Route<dynamic> route() {
    return CupertinoPageRoute(builder: (_) => const AboutAppScreen());
  }

  static const List<String> _titleList = [
    contactUs,
    aboutUs,
    termsAndConditions,
    privacyPolicy,
  ];

  static const List<String> _leadingList = [
    Assets.contactUsIcon,
    Assets.aboutUsIcon,
    Assets.termsAndCondIcon,
    Assets.privacyPolicyIcon,
  ];

  @override
  Widget build(BuildContext context) {
    final size = context;

    return Scaffold(
      appBar: QAppBar(title: Text(context.tr(aboutQuizAppKey)!)),
      body: Stack(
        children: [
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              vertical: size.height * UiUtils.vtMarginPct,
              horizontal: size.width * UiUtils.hzMarginPct,
            ),
            separatorBuilder: (_, i) => const SizedBox(height: 18),
            itemBuilder: (_, i) {
              return ListTile(
                onTap: () => context.pushNamed(
                  Routes.appSettings,
                  arguments: AppSettingsScreenArgs(_titleList[i]),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: SvgPicture.asset(
                  _leadingList[i],
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
                title: Text(
                  context.tr(_titleList[i])!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeights.medium,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
                tileColor: Theme.of(context).colorScheme.surface,
              );
            },
            itemCount: _titleList.length,
          ),
        ],
      ),
    );
  }
}
