// COMMUNITY UI
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'med_thread_page.dart';
import 'rooms_page.dart';
import 'events_page.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart'; // COMMUNITY UI
import '../../providers.dart'; // COMMUNITY UI

class CommunityLegacyScreen extends ConsumerStatefulWidget {
  const CommunityLegacyScreen({super.key, this.initialIndex = 0, this.initialRoomId});

  static Route<CommunityLegacyScreen> route({int initialIndex = 0, String? roomId}) =>
      MaterialPageRoute(builder: (_) => CommunityLegacyScreen(initialIndex: initialIndex, initialRoomId: roomId));

  final int initialIndex;
  final String? initialRoomId;

  @override
  CommunityLegacyScreenState createState() => CommunityLegacyScreenState();
}

class CommunityLegacyScreenState extends ConsumerState<CommunityLegacyScreen>
    with SingleTickerProviderStateMixin {
  // COMMUNITY UI
  late final TabController _tabController =
      TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);

  @override
  void initState() {
    super.initState();
    // COMMUNITY UI: preselect a room if provided via route args
    final roomId = widget.initialRoomId;
    if (roomId != null && roomId.isNotEmpty) {
      Future.microtask(() => ref.read(selectedRoomIdProvider.notifier).state = roomId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // COMMUNITY UI: Top-Navbar like Leaderboard tabs
      appBar: QAppBar(
        elevation: 0,
        title: Text('Community Legacy', style: theme.textTheme.titleLarge),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          tabs: const [
            Tab(text: 'MedThread'), // COMMUNITY UI
            Tab(text: 'Rooms'), // COMMUNITY UI
            Tab(text: 'Events'), // COMMUNITY UI
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const ClampingScrollPhysics(),
        children: const [
          MedThreadPage(),
          RoomsPage(),
          EventsPage(),
        ],
      ),
    );
  }
}
