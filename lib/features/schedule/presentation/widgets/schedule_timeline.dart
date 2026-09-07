import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timora/core/theme/app_colors.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import '../screens/activity_details_sheet.dart';

class ScheduleTimeline extends StatelessWidget {
  final List<ScheduleActivity> activities;

  const ScheduleTimeline({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time and Timeline Line
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(activity.startTime),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(context, activity.status),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Activity Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ActivityDetailsSheet(activity: activity),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getCardColor(context, activity.status, activity.color),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getBorderColor(context, activity.status, activity.color),
                          width: activity.status == ActivityStatus.current ? 2 : 1,
                        ),
                        boxShadow: [
                          if (Theme.of(context).brightness == Brightness.light)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(activity.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: activity.status == ActivityStatus.skipped 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                    color: activity.status == ActivityStatus.skipped 
                                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5) 
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _getStatusIcon(activity.status, activity.color),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${DateFormat('h:mm a').format(activity.startTime)} – ${DateFormat('h:mm a').format(activity.endTime)}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, ActivityStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case ActivityStatus.current:
        return theme.colorScheme.primary;
      case ActivityStatus.completed:
        return Colors.green;
      case ActivityStatus.skipped:
        return Colors.grey;
      case ActivityStatus.upcoming:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  Color _getCardColor(BuildContext context, ActivityStatus status, Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (status == ActivityStatus.current) {
      return isDark ? baseColor.withValues(alpha: 0.2) : baseColor.withValues(alpha: 0.1);
    }
    return isDark ? AppColors.cardDark : AppColors.cardLight;
  }

  Color _getBorderColor(BuildContext context, ActivityStatus status, Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (status == ActivityStatus.current) {
      return baseColor;
    }
    return isDark ? AppColors.borderDark : AppColors.borderLight;
  }

  Widget _getStatusIcon(ActivityStatus status, Color baseColor) {
    IconData iconData;
    Color color;

    switch (status) {
      case ActivityStatus.completed:
        iconData = Icons.check_circle_rounded;
        color = Colors.green;
        break;
      case ActivityStatus.current:
        iconData = Icons.play_circle_filled_rounded;
        color = baseColor;
        break;
      case ActivityStatus.skipped:
        iconData = Icons.cancel_rounded;
        color = Colors.grey;
        break;
      case ActivityStatus.upcoming:
        iconData = Icons.radio_button_unchecked_rounded;
        color = Colors.grey;
        break;
    }

    return Icon(iconData, size: 14, color: color);
  }
}
