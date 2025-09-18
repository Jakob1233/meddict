import 'dart:developer';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

enum BannerAdState { initial, loading, loaded, failure }

class BannerAdCubit extends Cubit<BannerAdState> {
  BannerAdCubit() : super(BannerAdState.initial);

  BannerAd? _googleBannerAd;
  UnityBannerAd? _unityBannerAd;

  BannerAd? get googleBannerAd => _googleBannerAd;
  UnityBannerAd? get unityBannerAd => _unityBannerAd;

  int _bannerRetryCount = 0;
  static const int _maxRetryCount = 3;

  Future<void> _createGoogleBannerAd(BuildContext context) async {
    await _googleBannerAd?.dispose();
    _googleBannerAd = null;

    final ad = BannerAd(
      request: const AdRequest(),
      adUnitId: context.read<SystemConfigCubit>().googleBannerId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerRetryCount = 0; // Reset

          _googleBannerAd = ad as BannerAd;
          emit(BannerAdState.loaded);
          log('BannerAd loaded');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) async {
          await ad.dispose(); // Dispose failed ad
          log('BannerAd failedToLoad: $error');
          emit(BannerAdState.failure);

          if (error.code == 3 && _bannerRetryCount < _maxRetryCount) {
            final delay = Duration(seconds: min(2 << _bannerRetryCount, 10));
            _bannerRetryCount++;

            log('Retrying in ${delay.inSeconds}s (attempt $_bannerRetryCount)');
            await Future<void>.delayed(delay);
            await _createGoogleBannerAd(context); // Retry recursively
          } else {
            log('Stopped retrying after $_bannerRetryCount attempts.');
          }
        },
        onAdOpened: (_) => log('BannerAd opened'),
        onAdClosed: (_) => log('BannerAd closed'),
      ),
      size: AdSize.banner,
    );

    await ad.load();
  }

  void _createUnityBannerAd() {
    _unityBannerAd = null;

    _unityBannerAd = UnityBannerAd(
      placementId: unityBannerAdsPlacement(),
      onLoad: (_) {
        _bannerRetryCount = 0; // Reset
        log('BannerAd loaded');
        emit(BannerAdState.loaded);
      },
      onFailed: (placementId, error, message) async {
        log('Banner Ad $placementId failed: $error $message');
        emit(BannerAdState.failure);

        if (_bannerRetryCount < _maxRetryCount) {
          final delay = Duration(seconds: min(2 << _bannerRetryCount, 10));
          _bannerRetryCount++;

          log('Retrying in ${delay.inSeconds}s (attempt $_bannerRetryCount)');
          await Future<void>.delayed(delay);
          _createUnityBannerAd(); // Retry
        } else {
          log('Stopped retrying after $_bannerRetryCount attempts.');
        }
      },
    );
  }

  void initBannerAd(BuildContext context) {
    final systemConfigCubit = context.read<SystemConfigCubit>();
    if (systemConfigCubit.isAdsEnable &&
        !context.read<UserDetailsCubit>().removeAds()) {
      if (systemConfigCubit.adsType == 1) {
        _createGoogleBannerAd(context);
      } else {
        _createUnityBannerAd();
      }
    }
  }

  String unityBannerAdsPlacement() {
    if (Platform.isAndroid) {
      return 'Banner_Android';
    }
    if (Platform.isIOS) {
      return 'Banner_iOS';
    }
    return '';
  }

  bool get bannerAdLoaded => state == BannerAdState.loaded;

  @override
  Future<void> close() async {
    await _googleBannerAd?.dispose();
    return super.close();
  }
}
