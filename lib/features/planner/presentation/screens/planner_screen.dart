import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/planner/presentation/providers/planner_provider.dart';
import 'package:timora/features/daily_plan/presentation/screens/daily_plan_screen.dart';
import 'package:timora/features/weekly_plan/presentation/screens/weekly_plan_screen.dart';
import 'package:timora/features/monthly_plan/presentation/screens/monthly_plan_screen.dart';
import 'package:timora/features/routine/presentation/screens/routine_templates_screen.dart';
import 'package:timora/core/widgets/timora_banner_ad.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/quick_voice_note_sheet.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(activePlannerTabProvider);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab.index,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(activePlannerTabProvider.notifier).state =
            PlannerTab.values[_tabController.index];
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTab = ref.watch(activePlannerTabProvider);

    if (_tabController.index != activeTab.index) {
      _tabController.animateTo(activeTab.index);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Smart Planner',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF6366F1)),
            tooltip: 'Quick Voice Note',
            onPressed: () => QuickVoiceNoteSheet.show(context),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RoutineTemplatesScreen()),
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Templates',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: theme.colorScheme.onPrimary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.7),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.today, size: 15),
                        SizedBox(width: 4),
                        Text('Daily & Agenda'),
                      ],
                    ),
                  ),
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_week_outlined, size: 15),
                        SizedBox(width: 4),
                        Text('Weekly Overview'),
                      ],
                    ),
                  ),
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 15),
                        SizedBox(width: 4),
                        Text('Monthly Calendar'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                DailyPlanScreen(),
                WeeklyPlanScreen(),
                MonthlyPlanScreen(),
              ],
            ),
          ),
          const SafeArea(
            top: false,
            child: TimoraBannerAd(
              margin: EdgeInsets.only(top: 6, bottom: 8, left: 16, right: 16),
            ),
          ),
        ],
      ),
    );
  }
}
