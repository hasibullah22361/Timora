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
  });
}
