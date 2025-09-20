import 'dart:async';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/bottom_nav/bottom_nav.dart';
import 'package:flutterquiz/commons/widgets/custom_image.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/auth/auth_repository.dart';
import 'package:flutterquiz/features/auth/cubits/auth_cubit.dart';
import 'package:flutterquiz/features/auth/cubits/refer_and_earn_cubit.dart';
import 'package:flutterquiz/features/play_zone_tab/screens/play_zone_tab_screen.dart';
import 'package:flutterquiz/features/profile_management/cubits/update_score_and_coins_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/update_user_details_cubit.dart';
import 'package:flutterquiz/features/profile_management/profile_management_repository.dart';
import 'package:flutterquiz/features/profile_tab/screens/profile_tab_screen.dart';
// COMMUNITY FEATURE TEMPORARILY DISABLED: keep modules but remove navigation entry
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/screens/home/home_screen.dart';
import 'package:flutterquiz/ui/screens/flashcards/flashcards_screen.dart';

var dashboardScreenKey = GlobalKey<DashboardScreenState>(
  debugLabel: 'Dashboard',
);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();

  static Route<DashboardScreen> route() {
    dashboardScreenKey = GlobalKey<DashboardScreenState>(
      debugLabel: 'Dashboard',
    );

    return CupertinoPageRoute(
      builder: (_) => DashboardScreen(key: dashboardScreenKey),
    );
  }
}

class DashboardScreenState extends State<DashboardScreen> {
  final _pageController = PageController();
  final _currTabIndex = ValueNotifier<int>(0);
  late final StreamSubscription _tabsSub;
  bool _disposed = false;
  void changeTab(NavTabType type) {
    final index = _navTabs.indexWhere((e) => e.tab == type);

    if (index == -1) {
      return;
    }

    _currTabIndex.value = index;
    _pageController.jumpToPage(index);
  }

  final Map<NavTabType, GlobalKey<dynamic>> navTabsKeys = {
    NavTabType.home: GlobalKey<HomeScreenState>(debugLabel: 'Home'),
    // Reuse the leaderboard slot for Flashcards
    NavTabType.leaderboard: GlobalKey(debugLabel: 'Flashcards'),
    NavTabType.playZone: GlobalKey<PlayZoneTabScreenState>(
      debugLabel: 'Play Zone',
    ),
    NavTabType.profile: GlobalKey<ProfileTabScreenState>(debugLabel: 'Profile'),
  };

  late var _navTabs = <NavTab>[
    NavTab(
      tab: NavTabType.home,
      title: 'navHome',
      icon: Assets.homeNavIcon,
      activeIcon: Assets.homeActiveNavIcon,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ReferAndEarnCubit>(
            create: (_) => ReferAndEarnCubit(AuthRepository()),
          ),
          BlocProvider<UpdateCoinsCubit>(
            create: (_) => UpdateCoinsCubit(ProfileManagementRepository()),
          ),
          BlocProvider<UpdateUserDetailCubit>(
            create: (_) => UpdateUserDetailCubit(ProfileManagementRepository()),
          ),
        ],
        child: HomeScreen(key: navTabsKeys[NavTabType.home]),
      ),
    ),
    NavTab(
      tab: NavTabType.leaderboard,
      title: 'Flashcards',
      icon: Assets.leaderboardNavIcon,
      activeIcon: Assets.leaderboardActiveNavIcon,
      child: FlashcardsScreen(key: navTabsKeys[NavTabType.leaderboard]),
    ),
    NavTab(
      tab: NavTabType.playZone,
      title: 'navPlayZone',
      icon: Assets.playZoneNavIcon,
      activeIcon: Assets.playZoneActiveNavIcon,
      child: PlayZoneTabScreen(key: navTabsKeys[NavTabType.playZone]),
    ),

    NavTab(
      tab: NavTabType.profile,
      title: 'navProfile',
      icon: Assets.profileNavIcon,
      activeIcon: Assets.profileActiveNavIcon,
      child: ProfileTabScreen(key: navTabsKeys[NavTabType.profile]),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeTabsSafely();
    });

    _tabsSub = context.read<AuthCubit>().stream.listen((state) {
      if (!mounted || _disposed) return;
      if (state is Authenticated || state is Unauthenticated) {
        _initializeTabsSafely();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _tabsSub.cancel();
    _pageController.dispose();
    _currTabIndex.dispose();
    super.dispose();
  }

  void _initializeTabsSafely() {
    if (!mounted || _disposed) return;
    final config = context.read<SystemConfigCubit>();

    _navTabs = <NavTab>[
      NavTab(
        tab: NavTabType.home,
        title: 'navHome',
        icon: Assets.homeNavIcon,
        activeIcon: Assets.homeActiveNavIcon,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ReferAndEarnCubit>(
              create: (_) => ReferAndEarnCubit(AuthRepository()),
            ),
            BlocProvider<UpdateCoinsCubit>(
              create: (_) => UpdateCoinsCubit(ProfileManagementRepository()),
            ),
            BlocProvider<UpdateUserDetailCubit>(
              create: (_) =>
                  UpdateUserDetailCubit(ProfileManagementRepository()),
            ),
          ],
          child: HomeScreen(key: navTabsKeys[NavTabType.home]),
        ),
      ),
      if (context.read<AuthCubit>().isLoggedIn)
        NavTab(
          tab: NavTabType.leaderboard,
          title: 'Flashcards',
          icon: Assets.leaderboardNavIcon,
          activeIcon: Assets.leaderboardActiveNavIcon,
          child: FlashcardsScreen(key: navTabsKeys[NavTabType.leaderboard]),
        ),
      if (config.isPlayZoneEnabled)
        NavTab(
          tab: NavTabType.playZone,
          title: 'navPlayZone',
          icon: Assets.playZoneNavIcon,
          activeIcon: Assets.playZoneActiveNavIcon,
          child: PlayZoneTabScreen(key: navTabsKeys[NavTabType.playZone]),
        ),
      NavTab(
        tab: NavTabType.profile,
        title: 'navProfile',
        icon: Assets.profileNavIcon,
        activeIcon: Assets.profileActiveNavIcon,
        child: ProfileTabScreen(key: navTabsKeys[NavTabType.profile]),
      ),
    ];
    if (!mounted || _disposed) return;
    setState(() {});
  }

  void _onTapBack() {
    if (_currTabIndex.value != 0) {
      HapticFeedback.mediumImpact();
      _currTabIndex.value = 0;
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemUiOverlayStyle =
        (context.read<ThemeCubit>().state == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: context.surfaceColor,
        systemNavigationBarIconBrightness:
            context.read<ThemeCubit>().state == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: ValueListenableBuilder(
        valueListenable: _currTabIndex,
        builder: (_, currentIndex, _) {
          return PopScope(
            canPop: currentIndex == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;

              _onTapBack();
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: PageView(
                controller: _pageController,
                onPageChanged: (i) => _currTabIndex.value = i,
                physics: const ClampingScrollPhysics(),
                scrollBehavior: const ScrollBehavior().copyWith(
                  overscroll: false,
                ),
                children: _navTabs
                    .map((navTab) => navTab.child)
                    .toList(growable: false),
              ),
              bottomNavigationBar: _buildBottomNavigationBar(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final theme = Theme.of(context);
    final currentIndex = _currTabIndex.value;

    return SafeArea(
      top: false,
      bottom: false,
      child: CurvedNavigationBar(
        index: currentIndex,
        backgroundColor: theme.scaffoldBackgroundColor,
        color: theme.primaryColor,
        buttonBackgroundColor: theme.primaryColor,
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        items: List.generate(_navTabs.length, (index) {
          final navTab = _navTabs[index];
          final isSelected = currentIndex == index;
          final Color iconColor = isSelected
              ? theme.colorScheme.onSecondary
              : theme.colorScheme.onPrimary;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: QImage(
              imageUrl: isSelected ? navTab.activeIcon : navTab.icon,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              color: iconColor,
            ),
          );
        }),
        onTap: (idx) {
          if (_currTabIndex.value != idx) {
            HapticFeedback.mediumImpact();
            _currTabIndex.value = idx;
            _pageController.jumpToPage(idx);
          }
        },
      ),
    );
  }

  bool hasTab(NavTabType type) => _navTabs.any((tab) => tab.tab == type);
}
