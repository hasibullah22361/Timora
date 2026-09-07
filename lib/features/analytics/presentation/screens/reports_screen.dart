import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/report_generator_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Timora Automatic Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyReportTab(),
          _WeeklyReportTab(),
          _MonthlyReportTab(),
        ],
      ),
    );
  }
}

class _DailyReportTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return dailyAsync.when(
      data: (report) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Today’s Productivity Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(report.date),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _metricBox('Planned', '${report.plannedActivities}', Icons.event, const Color(0xFF3B82F6), isDark),
                      _metricBox('Completed', '${report.completedActivities}', Icons.check_circle, const Color(0xFF10B981), isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _metricBox('Missed', '${report.missedActivities}', Icons.warning_amber, const Color(0xFFEF4444), isDark),
                      _metricBox('Recovered', '${report.recoveredActivities}', Icons.auto_awesome, const Color(0xFF8B5CF6), isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Metrics Cards
            _statRowCard('Schedule Completion', '${report.completionPercentage.round()}%', Icons.pie_chart, isDark),
            const SizedBox(height: 10),
            _statRowCard('Deep Focus Time', '${(report.focusTimeMinutes / 60).floor()}h ${report.focusTimeMinutes % 60}m', Icons.timer, isDark),
            const SizedBox(height: 10),
            _statRowCard('Routine Consistency', '${report.routineConsistency.round()}%', Icons.loop, isDark),
            const SizedBox(height: 10),
            _statRowCard('Tasks Completed', '${report.tasksCompleted} done (${report.tasksRemaining} remaining)', Icons.task_alt, isDark),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _WeeklyReportTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return weeklyAsync.when(
      data: (report) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Weekly Synthesis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('MMM d').format(report.weekStart)} – ${DateFormat('MMM d, yyyy').format(report.weekEnd)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            _statRowCard('Total Completed Time', '${report.totalCompletedHours}h of ${report.totalPlannedHours}h planned', Icons.schedule, isDark),
            const SizedBox(height: 10),
            _statRowCard('Weekly Completion Rate', '${report.completionRate.round()}%', Icons.trending_up, isDark),
            const SizedBox(height: 10),
            _statRowCard('Peak Productivity Day', report.bestDay, Icons.star, isDark),
            const SizedBox(height: 10),
            _statRowCard('Best Productivity Window', report.mostProductiveTime, Icons.wb_sunny, isDark),
            const SizedBox(height: 10),
            _statRowCard('Recovered Tasks', '${report.recoveredTasks} tasks recovered via Autopilot', Icons.auto_awesome, isDark),
            const SizedBox(height: 10),
            _statRowCard('Goal Milestone Progress', '${report.goalProgress.round()}% on track', Icons.flag, isDark),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _MonthlyReportTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlyReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return monthlyAsync.when(
      data: (report) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Monthly Productivity Review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMMM yyyy').format(report.monthStart),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            _statRowCard('Monthly Completion Trend', '${report.completionTrend.round()}%', Icons.bar_chart, isDark),
            const SizedBox(height: 10),
            _statRowCard('Overall Productivity Index', '${report.productivityTrend.round()}/100', Icons.insights, isDark),
            const SizedBox(height: 10),
            _statRowCard('Strongest Focus Window', report.strongestProductivityHours, Icons.access_time, isDark),
            const SizedBox(height: 18),

            Text(
              'Key Improvement Suggestions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            ...report.improvementSuggestions.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

Widget _metricBox(String label, String value, IconData icon, Color color, bool isDark) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B101B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _statRowCard(String title, String value, IconData icon, bool isDark) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    ),
  );
}
