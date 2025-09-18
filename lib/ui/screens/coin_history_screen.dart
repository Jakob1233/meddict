import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/ads/ads.dart';
import 'package:flutterquiz/features/coin_history/coin_history_cubit.dart';
import 'package:flutterquiz/features/coin_history/coin_history_repository.dart';
import 'package:flutterquiz/features/coin_history/models/coin_history.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/ui/widgets/already_logged_in_dialog.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/ui/widgets/error_container.dart';
import 'package:flutterquiz/utils/datetime_utils.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class CoinHistoryScreen extends StatefulWidget {
  const CoinHistoryScreen({super.key});

  @override
  State<CoinHistoryScreen> createState() => _CoinHistoryScreenState();

  static Route<dynamic> route() {
    return CupertinoPageRoute(
      builder: (_) => BlocProvider<CoinHistoryCubit>(
        create: (_) => CoinHistoryCubit(CoinHistoryRepository()),
        child: const CoinHistoryScreen(),
      ),
    );
  }
}

class _CoinHistoryScreenState extends State<CoinHistoryScreen> {
  late final _coinHistoryScrollController = ScrollController()
    ..addListener(hasMoreCoinHistoryScrollListener);

  void getCoinHistory() {
    Future.delayed(Duration.zero, () {
      context.read<CoinHistoryCubit>().getCoinHistory();
    });
  }

  @override
  void initState() {
    getCoinHistory();
    super.initState();
  }

  @override
  void dispose() {
    _coinHistoryScrollController
      ..removeListener(hasMoreCoinHistoryScrollListener)
      ..dispose();
    super.dispose();
  }

  void hasMoreCoinHistoryScrollListener() {
    if (_coinHistoryScrollController.position.maxScrollExtent ==
        _coinHistoryScrollController.offset) {
      if (context.read<CoinHistoryCubit>().hasMoreCoinHistory()) {
        //
        context.read<CoinHistoryCubit>().getMoreCoinHistory(
          userId: context.read<UserDetailsCubit>().userId(),
        );
      } else {}
    }
  }

  Widget _buildCoinHistoryContainer({
    required CoinHistory coinHistory,
    required int index,
    required int totalCurrentCoinHistory,
    required bool hasMoreCoinHistoryFetchError,
    required bool hasMore,
  }) {
    if (index == totalCurrentCoinHistory - 1) {
      //check if hasMore
      if (hasMore) {
        if (hasMoreCoinHistoryFetchError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: IconButton(
                onPressed: () {
                  context.read<CoinHistoryCubit>().getMoreCoinHistory(
                    userId: context.read<UserDetailsCubit>().userId(),
                  );
                },
                icon: Icon(Icons.error, color: Theme.of(context).primaryColor),
              ),
            ),
          );
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: CircularProgressContainer(),
            ),
          );
        }
      }
    }
    final formattedDate = DateTimeUtils.dateFormat.format(
      DateTime.parse(coinHistory.date),
    );
    final size = context;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => log(coinHistory.type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        height: size.height * 0.1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size.width * 0.63,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr(coinHistory.type) ?? coinHistory.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onTertiary,
                      fontSize: 16.5,
                      fontWeight: FontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: 3.5),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: colorScheme.onTertiary.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              alignment: Alignment.center,
              height: size.width * 0.1,
              width: size.width * .180,
              decoration: BoxDecoration(
                color: coinHistory.status == '1'
                    ? kHurryUpTimerColor
                    : kAddCoinColor,
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                coinHistory.status == '0'
                    ? '+ ${UiUtils.formatNumber(int.parse(coinHistory.points))}'
                    : UiUtils.formatNumber(int.parse(coinHistory.points)),
                maxLines: 1,
                style: TextStyle(color: colorScheme.surface, fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinHistory() {
    return BlocConsumer<CoinHistoryCubit, CoinHistoryState>(
      listener: (context, state) {
        if (state is CoinHistoryFetchFailure) {
          if (state.errorMessage == errorCodeUnauthorizedAccess) {
            showAlreadyLoggedInDialog(context);
          }
        }
      },
      bloc: context.read<CoinHistoryCubit>(),
      builder: (context, state) {
        if (state is CoinHistoryFetchInProgress ||
            state is CoinHistoryInitial) {
          return const Center(child: CircularProgressContainer());
        }
        if (state is CoinHistoryFetchFailure) {
          return Center(
            child: ErrorContainer(
              errorMessageColor: Theme.of(context).primaryColor,
              errorMessage: convertErrorCodeToLanguageKey(state.errorMessage),
              onTapRetry: getCoinHistory,
              showErrorImage: true,
            ),
          );
        }
        return ListView.separated(
          controller: _coinHistoryScrollController,
          padding: EdgeInsets.symmetric(
            vertical: context.height * UiUtils.vtMarginPct,
            horizontal: context.width * UiUtils.hzMarginPct,
          ),
          itemCount: (state as CoinHistoryFetchSuccess).coinHistory.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            return _buildCoinHistoryContainer(
              coinHistory: state.coinHistory[index],
              hasMore: state.hasMore,
              hasMoreCoinHistoryFetchError: state.hasMoreFetchError,
              index: index,
              totalCurrentCoinHistory: state.coinHistory.length,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerAdLoaded =
        context.watch<BannerAdCubit>().bannerAdLoaded &&
        !context.read<UserDetailsCubit>().removeAds();

    return Scaffold(
      appBar: QAppBar(title: Text(context.tr(coinHistoryKey)!)),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bannerAdLoaded ? 60 : 0),
            child: _buildCoinHistory(),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BannerAdContainer(),
          ),
        ],
      ),
    );
  }
}
