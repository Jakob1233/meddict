import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/features/ads/blocs/banner_ad_cubit.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdContainer extends StatefulWidget {
  const BannerAdContainer({super.key});

  @override
  State<BannerAdContainer> createState() => _BannerAdContainer();
}

class _BannerAdContainer extends State<BannerAdContainer> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      context.read<BannerAdCubit>().initBannerAd(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<SystemConfigCubit>();
    return BlocBuilder<BannerAdCubit, BannerAdState>(
      builder: (context, state) {
        if (config.isAdsEnable && state == BannerAdState.loaded) {
          if (config.adsType == 1) {
            final bannerAd = context.read<BannerAdCubit>().googleBannerAd;
            if (bannerAd != null) {
              return SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              );
            }
          } else {
            final unityBannerAd = context.read<BannerAdCubit>().unityBannerAd;
            if (unityBannerAd != null) {
              return SizedBox(
                height: unityBannerAd.size.height.toDouble(),
                width: unityBannerAd.size.width.toDouble(),
                child: unityBannerAd,
              );
            }
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}
