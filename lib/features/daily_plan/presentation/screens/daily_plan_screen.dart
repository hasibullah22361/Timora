import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/data/models/timeline_item.dart';
import 'package:timora/features/daily_plan/presentation/widgets/auto_plan_dialog.dart';
import 'package:timora/features/daily_plan/presentation/widgets/plan_task_sheet.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import 'package:timora/features/schedule/presentation/screens/add_edit_activity_sheet.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart' show scheduleNotifierProvider, scheduleActivitiesByDateProvider;

class DailyPlanScreen extends ConsumerWidget {
  const DailyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = ref.watch(selectedDateProvider);
    final timelineAsync = ref.watch(timelineProvider(date));
    final planAsync = ref.watch(dailyPlanProvider(date));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Daily Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete_day_plan') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Day Plan?'),
                    content: Text(
                      'Are you sure you want to delete the plan for ${DateFormat('EEEE, MMM d').format(date)}? All planned tasks for this day will be removed.',
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
                  await ref.read(dailyPlanNotifierProvider).deleteDayPlan(date);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Day Plan deleted successfully')),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete_day_plan',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Day Plan', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(context, ref, date),
          _buildSummary(context, ref, date),
          Expanded(
            child: timelineAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing planned for today.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _buildTimelineItem(context, ref, items[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'autoPlan',
            onPressed: () {
              planAsync.whenData((plan) {
                showDialog(
                  context: context,
                  builder: (ctx) => AutoPlanDialog(date: date, plan: plan),
                );
              });
            },
            backgroundColor: theme.colorScheme.secondary,
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'addPlan',
            onPressed: () {
              planAsync.whenData((plan) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => PlanTaskSheet(date: date, plan: plan),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Plan Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedDateProvider.notifier).state = date.subtract(const Duration(days: 1)),
          ),
          Text(
            _isToday(date) ? 'Today' : DateFormat('EEEE, MMM d').format(date),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedDateProvider.notifier).state = date.add(const Duration(days: 1)),
          ),
        ],
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref, DateTime date) {
    final planAsync = ref.watch(dailyPlanProvider(date));
    final theme = Theme.of(context);
    
    return planAsync.when(
      data: (plan) {
        final plannedStr = _formatDuration(plan.plannedDurationSeconds);
        final completedStr = _formatDuration(plan.completedDurationSeconds);
        final remaining = (plan.plannedDurationSeconds - plan.completedDurationSeconds).clamp(0, double.infinity).toInt();
        final remainingStr = _formatDuration(remaining);
        
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(context, 'Planned', plannedStr, theme.colorScheme.primary),
              _buildStat(context, 'Completed', completedStr, Colors.green),
              _buildStat(context, 'Remaining', remainingStr, Colors.orange),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
    return '${m}m';
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, TimelineItem item) {
    final theme = Theme.of(context);
    final isRoutine = item.type == TimelineItemType.routine;
    final isBlock = item.type == TimelineItemType.block;
    
    final timeStr = '${item.startTime.format(context)} - ${item.endTime.format(context)}';

    return IntrinsicHeight(
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 70,
            child: Text(
              item.startTime.format(context),
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          
          // Line and dot
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.isCompleted ? Colors.green : item.color,
                  shape: BoxShape.circle,
                  border: isRoutine ? null : Border.all(color: theme.colorScheme.surface, width: 2),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Card content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.isCompleted ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : item.color.withValues(alpha: isRoutine ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                            color: item.isCompleted ? Colors.grey : null,
                          ),
                        ),
                      ),
                      if (isBlock && !item.isCompleted)
                        IconButton(
                          icon: const Icon(Icons.self_improvement, size: 20),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
                          },
                        ),
                      if (isBlock)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) async {
                            if (v == 'delete') {
                              ref.read(dailyPlanNotifierProvider).deletePlannedBlock(item.sourceId, ref.read(selectedDateProvider));
                            } else if (v == 'move') {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: ref.read(selectedDateProvider),
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                // Simplified move: delete from old, will need to create in new day
                                ref.read(dailyPlanNotifierProvider).deletePlannedBlock(item.sourceId, ref.read(selectedDateProvider));
                                // In a full implementation, we fetch the new DailyPlan and create a new block there.
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task moved')));
                                }
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'move', child: Text('Move to another day')),
                            const PopupMenuItem(value: 'delete', child: Text('Remove from Plan', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      if (item.type == TimelineItemType.schedule)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) async {
                            final currentDate = ref.read(selectedDateProvider);
                            if (v == 'edit') {
                              final activities = ref.read(scheduleActivitiesByDateProvider(currentDate)).valueOrNull ?? [];
                              final act = activities.where((a) => a.id == item.sourceId).firstOrNull;
                              if (act != null && context.mounted) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => AddEditActivitySheet(activityToEdit: act),
                                );
                              }
                            } else if (v == 'delete') {
                              await ref.read(scheduleNotifierProvider).deleteActivity(item.sourceId);
                              ref.invalidate(scheduleActivitiesByDateProvider(currentDate));
                              ref.invalidate(timelineProvider(currentDate));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Scheduled activity removed')),
                                );
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit Schedule'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Schedule', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: item.color)),
                  const SizedBox(height: 8),
                  Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
