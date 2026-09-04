import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit_log_model.dart';

class HabitHeatmap extends StatelessWidget {
  final List<HabitLogModel> logs;
  final Color baseColor;
  final int daysToShow;

  const HabitHeatmap({
    super.key,
    required this.logs,
    this.baseColor = const Color(0xFF10B981),
    this.daysToShow = 63, // 9 weeks
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build completed set for O(1) lookups
    final completedDays = logs
        .where((l) => l.completed)
        .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
        .toSet();

    // Generate list of days from (daysToShow - 1) days ago to today
    final days = List.generate(daysToShow, (i) {
      return today.subtract(Duration(days: daysToShow - 1 - i));
    });

    // Group into 7-day columns (weeks)
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      final end = (i + 7 < days.length) ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
    }

    final totalCompleted = days.where((d) => completedDays.contains(d)).length;
    final completionRate = days.isNotEmpty ? (totalCompleted / days.length * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last $daysToShow Days Consistency',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$completionRate% ($totalCompleted / $daysToShow days)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: baseColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Column(
                  children: week.map((date) {
                    final isDone = completedDays.contains(date);
                    final isTodayDate = date.isAtSameMomentAs(today);

                    return Tooltip(
                      message: '${DateFormat('EEE, MMM d').format(date)}: ${isDone ? 'Completed' : 'Missed'}',
                      child: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isDone
                              ? baseColor
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                          border: isTodayDate
                              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
