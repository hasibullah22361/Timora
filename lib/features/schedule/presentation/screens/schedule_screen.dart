import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/schedule/services/smart_rescheduling_service.dart';
import 'package:timora/features/schedule/services/calendar_sync_service.dart';
import 'package:timora/features/schedule/presentation/widgets/schedule_timeline.dart';
import 'package:timora/features/schedule/presentation/screens/add_edit_activity_sheet.dart';
import 'package:timora/core/theme/app_colors.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final activitiesAsync = ref.watch(scheduleActivitiesProvider);

    final isToday = _isSameDay(selectedDate, DateTime.now());
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Schedule & Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Calendar (.ics)',
            onPressed: () => _showExportSheet(context, ref),
          ),
          if (!isToday)
            TextButton(
              onPressed: () {
                final now = DateTime.now();
                ref.read(selectedDateProvider.notifier).state = DateTime(now.year, now.month, now.day);
              },
              child: const Text('Today'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive 7-Day Calendar Strip
            _buildCalendarStrip(context, ref, selectedDate),
            
            // Timeline Content
            Expanded(
              child: activitiesAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (activities) {
                  if (activities.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        final date = ref.read(selectedDateProvider);
                        ref.invalidate(scheduleActivitiesProvider);
                        ref.invalidate(scheduleActivitiesByDateProvider(date));
                        await ref.read(scheduleActivitiesProvider.future);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          _buildEmptyState(context),
                        ],
                      ),
                    );
                  }
                  final conflicts = SmartReschedulingService.detectConflicts(activities);

                  return Column(
                    children: [
                      if (conflicts.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${conflicts.length} overlapping schedule conflict(s) detected.',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () async {
                                  final resolved = SmartReschedulingService.resolveConflicts(activities);
                                  for (var act in resolved) {
                                    await ref.read(scheduleNotifierProvider).updateActivity(act);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('⚡ Schedule auto-rescheduled without overlaps!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Auto Fix', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            final date = ref.read(selectedDateProvider);
                            ref.invalidate(scheduleActivitiesProvider);
                            ref.invalidate(scheduleActivitiesByDateProvider(date));
                            await ref.read(scheduleActivitiesProvider.future);
                          },
                          child: ScheduleTimeline(
                            activities: activities,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'schedule_fab',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddEditActivitySheet(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarStrip(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Generate 7 days centered around selected date
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isSelected = _isSameDay(day, selectedDate);
          final isCurrentDay = _isSameDay(day, today);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = DateTime(day.year, day.month, day.day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : isCurrentDay
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? null
                    : isCurrentDay
                        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))
                        : null,
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected || isCurrentDay ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) async {
    final activities = await ref.read(scheduleActivitiesProvider.future);
    final tasks = await ref.read(allTasksProvider.future);

    final icsContent = CalendarSyncService.exportActivitiesToIcs(
      activities: activities,
      tasks: tasks,
    );

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 10),
                    const Text('Export Timora Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Standard RFC 5545 iCalendar (.ics) ready with ${activities.length} schedule activities and timed tasks for sync with Google Calendar, Apple Calendar, or Outlook.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy .ics Data to Clipboard'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: icsContent));
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('iCalendar (.ics) data copied to clipboard!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_available_rounded, size: 36, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text('Your day is open', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Schedule activities or routine blocks to organize your day.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddEditActivitySheet(),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Activity'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
