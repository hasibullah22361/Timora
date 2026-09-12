import 'package:flutter/material.dart';

enum TimelineItemType { routine, schedule, task, block }

class TimelineItem {
  final String id;
  final String sourceId;
  final TimelineItemType type;
  final String title;
  final String subtitle;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String icon;
  final bool isCompleted;
  final int? customPlannedMinutes;
  final int completedMinutes;

  TimelineItem({
    required this.id,
    required this.sourceId,
    required this.type,
    required this.title,
    this.subtitle = '',
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.icon,
    this.isCompleted = false,
    this.customPlannedMinutes,
    this.completedMinutes = 0,
  });

  /// Original planned duration in minutes
  int get plannedMinutes {
    if (customPlannedMinutes != null && customPlannedMinutes! > 0) {
      return customPlannedMinutes!;
    }
    final startMins = startTime.hour * 60 + startTime.minute;
    final endMins = endTime.hour * 60 + endTime.minute;
    final diff = endMins - startMins;
    return diff > 0 ? diff : 0;
  }

  /// Remaining duration in minutes (formula: remaining = max(0, planned - completed))
  int get remainingMinutes {
    final rem = plannedMinutes - completedMinutes;
    return rem > 0 ? rem : 0;
  }

  /// Formatted planned string e.g. "20 min planned"
  String get plannedFormatted => '$plannedMinutes min planned';

  /// Formatted completed string e.g. "7 min completed"
  String get completedFormatted => '$completedMinutes min completed';

  /// Formatted remaining string e.g. "13 min remaining"
  String get remainingFormatted => '$remainingMinutes min remaining';

  /// Check if completed reaches planned
  bool get isFullyCompleted =>
      isCompleted || (plannedMinutes > 0 && completedMinutes >= plannedMinutes);
}
