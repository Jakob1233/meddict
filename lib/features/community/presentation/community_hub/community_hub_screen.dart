import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/features/community/presentation/community_hub/community_composer_sheets.dart';

// import 'tabs/community_exam_tips_tab.dart';
import 'tabs/community_experiences_tab.dart';
import 'tabs/community_feed_tab.dart';
// import 'tabs/community_subjects_tab.dart';
import 'package:flutterquiz/ui/screens/community/learning_materials_home.dart';
import 'package:flutterquiz/ui/screens/community/exameter_screen.dart';

class CommunityHubScreen extends ConsumerStatefulWidget {
  const CommunityHubScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  static Route<CommunityHubScreen> route({int initialIndex = 0}) =>
      MaterialPageRoute(builder: (_) => CommunityHubScreen(initialIndex: initialIndex));

  @override
  CommunityHubScreenState createState() => CommunityHubScreenState();
}

class CommunityHubScreenState extends ConsumerState<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this, initialIndex: widget.initialIndex);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Community', style: theme.textTheme.titleLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: _buildTabBar(theme),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const ClampingScrollPhysics(),
        children: const [
          CommunityFeedTab(),
          LearningMaterialsHomeScreen(),
          // CommunitySubjectsTab(),
          ExameterScreen(),
          CommunityExperiencesTab(),
        ],
      ),
      floatingActionButton: _ComposerFab(onTap: () => showQuestionComposer(context, ref)),
    );
  }

  TabBar _buildTabBar(ThemeData theme) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      indicator: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: theme.colorScheme.onPrimary,
      unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
      tabs: const [
        Tab(text: 'Q&A'),
        Tab(text: 'Lernmaterialien'),
        Tab(text: 'Exameter'),
        Tab(text: 'Erfahrungen'),
      ],
    );
  }

}

class _ComposerFab extends StatelessWidget {
  const _ComposerFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.add_comment_outlined),
      label: const Text('Frage stellen'),
    );
  }
}
