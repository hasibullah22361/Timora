import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../widgets/current_activity_card.dart';
import '../widgets/next_activity_card.dart';
import '../widgets/autopilot_banner_widget.dart';
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
import '../widgets/today_insight_widget.dart';
import 'package:timora/features/settings/presentation/providers/settings_provider.dart';
import 'package:timora/features/settings/data/models/settings_models.dart';
import 'package:timora/features/settings/services/feature_flags_service.dart';
import 'package:timora/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:timora/features/profile/presentation/screens/profile_screen.dart';
import 'package:timora/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/timora_ai_button.dart';
import 'package:timora/features/quick_add/presentation/widgets/quick_add_sheet.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/quick_voice_note_sheet.dart';
import 'package:timora/features/ai_assistant/presentation/screens/morning_brief_screen.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/daily_debrief_sheet.dart';
import 'package:timora/core/services/connectivity_service.dart';
import 'package:timora/core/widgets/timora_banner_ad.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/schedule/services/missed_task_recovery_service.dart';
import 'package:timora/features/analytics/services/insights_engine_service.dart';
import 'package:timora/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'timora_search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Dynamic widget map for extra user-configured sections below Today's Progress
    final extraWidgetMap = <DashboardWidgetType, Widget>{
      DashboardWidgetType.todayPlan:
          const _DashboardSection(widget: TodayPlanWidget()),
      DashboardWidgetType.dailyReview:
          const _DashboardSection(widget: DashboardReviewWidget()),
      DashboardWidgetType.todayTasks:
          const _DashboardSection(widget: TodayTasksList()),
      DashboardWidgetType.analyticsSnapshot:
          const _DashboardSection(widget: ProductivitySnapshotWidget()),
      DashboardWidgetType.projects:
          const _DashboardSection(widget: ProjectProgressList()),
      DashboardWidgetType.goals:
          const _DashboardSection(widget: GoalProgressList()),
      DashboardWidgetType.thisWeek:
          const _DashboardSection(widget: ThisWeekWidget()),
      DashboardWidgetType.thisMonth:
          const _DashboardSection(widget: ThisMonthWidget()),
    };

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final flags = ref.watch(featureFlagsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: flags.isAiAssistantEnabled ? const TimoraAIButton() : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(currentTimeProvider.notifier).refresh();
            ref.invalidate(dailyScheduleProvider);
            ref.invalidate(todayTasksProvider);
            ref.invalidate(allTasksProvider);
            ref.invalidate(recoveryRecommendationsProvider);
            ref.invalidate(todayTopInsightProvider);
            ref.invalidate(analyticsInsightsProvider);
            ref.invalidate(timelineProvider);
            await ref.read(syncServiceProvider).autoSync();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const PageStorageKey('home_screen_scroll'),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= TOP HEADER =================
              const HomeTopHeader(),
              const SizedBox(height: 20),

              // ================= QUICK ADD & VOICE NOTE BAR =================
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => QuickAddSheet.show(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E1626) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E2A42)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: isDark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB),
                                  size: 19),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Quick Add with AI...',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF64748B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (flags.isNaturalVoicePlanningEnabled) ...[
                    const SizedBox(width: 10),
                    // Dedicated Quick Voice Note Action Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => QuickVoiceNoteSheet.show(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Voice Note',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // ================= MORNING BRIEF & DAILY DEBRIEF PILLS =================
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MorningBriefScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🌅', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Morning Brief',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => DailyDebriefSheet.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🌙', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Daily Debrief',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ================= AUTOPILOT NOTIFICATION & RECOVERY BANNER =================
              if (flags.isAutopilotEnabled) const AutopilotBannerWidget(),

              // ================= HERO ACTIVE FOCUS SESSION CARD =================
              const CurrentActivityCard(),
              const SizedBox(height: 24),

              // ================= UP NEXT SECTION =================
              const NextActivityCard(),
              const SizedBox(height: 24),

              // ================= FOCUS TOOLS (4-CARD GRID) =================
              const FocusDashboardWidget(),
              const SizedBox(height: 20),

              // ================= STREAK BANNER (KEEP IT UP) =================
              if (flags.isRoutineConsistencyEnabled) ...[
                const StreaksWidget(),
                const SizedBox(height: 24),
              ],

              // ================= TODAY'S PROGRESS (4 METRICS) =================
              const ProgressSection(),
              const SizedBox(height: 24),

              // ================= TODAY'S INTELLIGENCE & INSIGHTS =================
              const TodayInsightWidget(),
              const SizedBox(height: 24),

              // ================= SPONSORED BANNER AD =================
              const TimoraBannerAd(
                margin: EdgeInsets.only(bottom: 24),
              ),

              // Dynamic Dashboard based on user settings (if any other specific widget is enabled)
              ...settings.dashboardOrder
                  .where((type) =>
                      settings.dashboardVisibility[type] == true &&
                      type != DashboardWidgetType.focusTimer &&
                      type != DashboardWidgetType.streaks)
                  .map((type) {
                return extraWidgetMap[type] ?? const SizedBox.shrink();
              }),

              const SizedBox(height: 80),
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 24.0),
      child: widget,
    );
  }
}

/// Self-contained header widget that isolates high-frequency greeting/date
/// and notification/online changes from rebuilding the entire HomeScreen.
class HomeTopHeader extends ConsumerWidget {
  const HomeTopHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final greeting = ref.watch(greetingProvider);
    final formattedDate = ref.watch(formattedDateProvider);

    final hasCustomAvatar = profile.hasCustomImage &&
        (!kIsWeb
            ? File(profile.customImagePath!).existsSync()
            : profile.customImagePath!.isNotEmpty);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName =
        profile.fullName.trim().isNotEmpty ? profile.fullName.trim() : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Greeting, User Name, Subtitle, Blue Calendar Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('👋', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    "Let's make today productive!",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('🚀', style: TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              // Blue calendar date row
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right side: Search | Notifications | Profile (far right top corner)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔍 Search Button
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Search Timora',
                child: InkWell(
                  key: const Key('home_search_button'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TimoraSearchScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131B2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 🔔 Notifications Button with Badge
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Notifications',
                child: InkWell(
                  key: const Key('home_notifications_button'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 44,
                    padding: EdgeInsets.symmetric(
                        horizontal: unreadCount > 0 ? 12 : 11),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131B2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: unreadCount > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active_rounded,
                                color: Color(0xFF3B82F6),
                                size: 20,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$unreadCount',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          )
                        : Icon(
                            Icons.notifications_none_rounded,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Profile Avatar Column with bottom-right green dot and status pill (Far Right)
            Column(
              children: [
                InkWell(
                  key: const Key('home_profile_button'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF131B2E)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                                : const Color(0xFF2563EB).withValues(alpha: 0.35),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasCustomAvatar
                              ? (kIsWeb
                                  ? Image.network(
                                      profile.customImagePath!,
                                      width: 48,
                                      height: 48,
                                      cacheWidth: 150,
                                      cacheHeight: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        profile.avatarPreset,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    )
                                  : Image.file(
                                      File(profile.customImagePath!),
                                      width: 48,
                                      height: 48,
                                      cacheWidth: 150,
                                      cacheHeight: 150,
                                      fit: BoxFit.cover,
                                    ))
                              : Text(
                                  profile.avatarPreset,
                                  style: const TextStyle(fontSize: 26),
                                ),
                        ),
                      ),
                      // Green online indicator dot
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF070B14)
                                  : Colors.white,
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Offline/Online pill chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131B2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline
                            ? Icons.cloud_queue_rounded
                            : Icons.cloud_off_outlined,
                        size: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
