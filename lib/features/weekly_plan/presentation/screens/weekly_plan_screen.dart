import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/weekly_plan_provider.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/presentation/screens/daily_plan_screen.dart';
import 'package:timora/features/monthly_plan/presentation/screens/monthly_plan_screen.dart';
import 'package:timora/features/weekly_plan/presentation/widgets/auto_plan_week_dialog.dart';

class WeeklyPlanScreen extends ConsumerWidget {
  const WeeklyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weekStart = ref.watch(selectedWeekProvider);
    final statsAsync = ref.watch(weeklyStatsProvider(weekStart));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Weekly Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete_week_plan') {
                final endOfWeek = weekStart.add(const Duration(days: 6));
                final format = DateFormat('MMM d');
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Week Plan?'),
                    content: Text(
                      'Are you sure you want to delete the plan for ${format.format(weekStart)} – ${format.format(endOfWeek)}? All planned tasks for this week will be removed.',
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
                  await ref.read(weeklyPlanNotifierProvider).deleteWeekPlan(weekStart, deleteDailyPlans: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Week Plan deleted successfully')),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete_week_plan',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Week Plan', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekSelector(context, ref, weekStart),
          
          TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()));
            },
            icon: const Icon(Icons.calendar_month, size: 16),
            label: Text('View Full Month: ${DateFormat('MMMM yyyy').format(weekStart)}'),
          ),
          
          statsAsync.when(
            data: (stats) => _buildSummary(context, stats),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 7,
              itemBuilder: (ctx, index) {
                final date = weekStart.add(Duration(days: index));
                return _buildDayCard(context, ref, date);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AutoPlanWeekDialog(startOfWeek: weekStart),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Auto Plan Week'),
        backgroundColor: theme.colorScheme.secondary,
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context, WidgetRef ref, DateTime weekStart) {
    final endOfWeek = weekStart.add(const Duration(days: 6));
    final format = DateFormat('MMM d');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedWeekProvider.notifier).state = weekStart.subtract(const Duration(days: 7)),
          ),
          Text(
            '${format.format(weekStart)} – ${format.format(endOfWeek)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedWeekProvider.notifier).state = weekStart.add(const Duration(days: 7)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WeeklyStats stats) {
    final theme = Theme.of(context);
    
    final planned = _formatDuration(stats.totalPlannedSeconds);
    final completed = _formatDuration(stats.totalCompletedSeconds);
    final remaining = _formatDuration((stats.totalPlannedSeconds - stats.totalCompletedSeconds).clamp(0, double.infinity).toInt());
    
    final progress = stats.totalTasks == 0 ? 0.0 : stats.completedTasks / stats.totalTasks;
    
    return Container(
      margin: const EdgeInsets.all(24),
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
              _buildStat(context, 'Planned', planned, theme.colorScheme.primary),
              _buildStat(context, 'Completed', completed, Colors.green),
              _buildStat(context, 'Remaining', remaining, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('${stats.completedTasks} / ${stats.totalTasks} tasks', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text('${(progress * 100).toInt()}%', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
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
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    return '0m';
  }

  Widget _buildDayCard(BuildContext context, WidgetRef ref, DateTime date) {
    final theme = Theme.of(context);
    final blocksAsync = ref.watch(timelineProvider(date));
    
    return InkWell(
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = date;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _isToday(date) ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isToday(date) ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isToday(date) ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: blocksAsync.when(
                data: (items) {
                  final taskBlocks = items.where((i) => i.type.name == 'block').toList();
                  if (taskBlocks.isEmpty) {
                    return Text('No tasks planned', style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
                  }
                  
                  final completed = taskBlocks.where((b) => b.isCompleted).length;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${taskBlocks.length} tasks', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$completed / ${taskBlocks.length} completed', style: theme.textTheme.bodySmall),
                    ],
                  );
                },
                loading: () => const Text('Loading...'),
                error: (_, __) => const Text('Error'),
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
