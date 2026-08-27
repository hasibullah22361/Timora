import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../widgets/current_activity_card.dart';
import '../widgets/next_activity_card.dart';
import '../widgets/progress_section.dart';
import '../widgets/today_tasks_list.dart';
import '../widgets/goal_progress_list.dart';
import '../widgets/project_progress_list.dart';
import '../widgets/focus_dashboard_widget.dart';
import '../widgets/today_plan_widget.dart';
import '../widgets/this_week_widget.dart';
import '../widgets/this_month_widget.dart';
import '../widgets/productivity_snapshot_widget.dart';
import '../widgets/streaks_widget.dart';
import '../widgets/dashboard_review_widget.dart';
import 'package:timora/features/settings/presentation/providers/settings_provider.dart';
import 'package:timora/features/settings/data/models/settings_models.dart';
import 'package:timora/features/cloud_sync/presentation/widgets/sync_indicator_widget.dart';
import 'package:timora/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:timora/features/profile/presentation/screens/profile_screen.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/timora_ai_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(userProfileProvider);
    final hasCustomAvatar = profile.hasCustomImage && File(profile.customImagePath!).existsSync();
    
    // Build widgets map
    final widgetMap = <DashboardWidgetType, Widget>{
      DashboardWidgetType.todayPlan: const _DashboardSection(widget: TodayPlanWidget()),
      DashboardWidgetType.dailyReview: const _DashboardSection(widget: DashboardReviewWidget()),
      DashboardWidgetType.todayTasks: const _DashboardSection(widget: TodayTasksList()),
      DashboardWidgetType.focusTimer: const _DashboardSection(widget: FocusDashboardWidget()),
      DashboardWidgetType.analyticsSnapshot: const _DashboardSection(widget: ProductivitySnapshotWidget()),
      DashboardWidgetType.streaks: const _DashboardSection(widget: StreaksWidget()),
      DashboardWidgetType.projects: const _DashboardSection(widget: ProjectProgressList()),
      DashboardWidgetType.goals: const _DashboardSection(widget: GoalProgressList()),
      DashboardWidgetType.thisWeek: const _DashboardSection(widget: ThisWeekWidget()),
      DashboardWidgetType.thisMonth: const _DashboardSection(widget: ThisMonthWidget()),
    };
    final greeting = ref.watch(greetingProvider);
    final formattedDate = ref.watch(formattedDateProvider);
    final formattedTime = ref.watch(formattedTimeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: const TimoraAIButton(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.fullName,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SyncIndicatorWidget(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: profile.avatarColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: profile.avatarColor, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: hasCustomAvatar
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.file(
                                File(profile.customImagePath!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              profile.avatarPreset,
                              style: const TextStyle(fontSize: 26),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    formattedTime,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Current Activity
              const CurrentActivityCard(),
              const SizedBox(height: 24),
              
              // Next Activity
              const NextActivityCard(),
              const SizedBox(height: 32),
              
              // Focus Timer
              const FocusDashboardWidget(),
              
              // Today's Progress
              const ProgressSection(),
              const SizedBox(height: 32),
            
              // Dynamic Dashboard based on settings
              ...settings.dashboardOrder.where((type) => settings.dashboardVisibility[type] == true).map((type) {
                return widgetMap[type] ?? const SizedBox.shrink();
              }),
              
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final Widget widget;
  const _DashboardSection({required this.widget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: widget,
    );
  }
}
