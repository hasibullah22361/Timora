import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/monthly_plan_provider.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/presentation/screens/daily_plan_screen.dart';
import 'package:timora/features/monthly_plan/presentation/widgets/auto_plan_month_dialog.dart';

class MonthlyPlanScreen extends ConsumerWidget {
  const MonthlyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthDate = ref.watch(selectedMonthProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(monthDate));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Monthly Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete_month_plan') {
                final format = DateFormat('MMMM yyyy');
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Month Plan?'),
                    content: Text(
                      'Are you sure you want to delete the plan for ${format.format(monthDate)}? All planned tasks for this month will be removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(monthlyPlanNotifierProvider).deleteMonthPlan(
                        monthDate.year,
                        monthDate.month,
                        deleteDailyPlans: true,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Month Plan deleted successfully')),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete_month_plan',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Month Plan', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildMonthSelector(context, ref, monthDate)),
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => _buildSummary(context, stats),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: _buildCalendarHeader(theme),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: _buildCalendarGrid(context, ref, monthDate),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AutoPlanMonthDialog(monthDate: monthDate),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Auto Plan Month'),
        backgroundColor: theme.colorScheme.secondary,
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, WidgetRef ref, DateTime monthDate) {
    final format = DateFormat('MMMM yyyy');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newDate = DateTime(monthDate.year, monthDate.month - 1, 1);
              ref.read(selectedMonthProvider.notifier).state = newDate;
            },
          ),
          Text(
            format.format(monthDate),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final newDate = DateTime(monthDate.year, monthDate.month + 1, 1);
              ref.read(selectedMonthProvider.notifier).state = newDate;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, MonthlyStats stats) {
    final theme = Theme.of(context);
    
    final progress = stats.totalTasks == 0 ? 0.0 : stats.completedTasks / stats.totalTasks;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(context, 'Tasks', '${stats.completedTasks}/${stats.totalTasks}', theme.colorScheme.primary),
              _buildStat(context, 'Planned', _formatDuration(stats.totalPlannedSeconds), Colors.blue),
              _buildStat(context, 'Progress', '${(progress * 100).toInt()}%', Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    return '${h}h';
  }

  Widget _buildCalendarHeader(ThemeData theme) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 2.0,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Center(
          child: Text(
            days[i],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        childCount: 7,
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, WidgetRef ref, DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstDayOfWeek = DateTime(monthDate.year, monthDate.month, 1).weekday;
    final emptySlots = firstDayOfWeek - 1; // Assuming Monday start

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          if (i < emptySlots) {
            return const SizedBox.shrink();
          }
          final day = i - emptySlots + 1;
          if (day > daysInMonth) return const SizedBox.shrink();
          
          final date = DateTime(monthDate.year, monthDate.month, day);
          return _CalendarCell(date: date);
        },
        childCount: emptySlots + daysInMonth,
      ),
    );
  }
}

class _CalendarCell extends ConsumerWidget {
  final DateTime date;

  const _CalendarCell({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocksAsync = ref.watch(timelineProvider(date));
    
    final isToday = date.year == DateTime.now().year && 
                    date.month == DateTime.now().month && 
                    date.day == DateTime.now().day;

    return InkWell(
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = date;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isToday ? theme.colorScheme.primary : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            blocksAsync.when(
              data: (items) {
                final taskBlocks = items.where((i) => i.type.name == 'block').toList();
                if (taskBlocks.isEmpty) return const SizedBox(height: 4, width: 4);
                
                final allCompleted = taskBlocks.every((b) => b.isCompleted);
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: allCompleted ? Colors.green : theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
