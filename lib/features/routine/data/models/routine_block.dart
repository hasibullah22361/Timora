import 'package:flutter/material.dart';

class RoutineBlock {
  final String id;
  final String routineId;
  final String title;
  final String description;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String category;
  final String icon;
  final Color color;
  final int order;
  final bool enabled;
  final String notes;

  RoutineBlock({
    required this.id,
    required this.routineId,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.icon,
    this.color = Colors.blue,
    required this.order,
    this.enabled = true,
    this.notes = '',
  });

  RoutineBlock copyWith({
    String? title,
    String? description,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? category,
    String? icon,
    Color? color,
    int? order,
    bool? enabled,
    String? notes,
  }) {
    return RoutineBlock(
      id: id,
      routineId: routineId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routineId': routineId,
      'title': title,
      'description': description,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'category': category,
      'icon': icon,
      'color': color.toARGB32(),
      'order': order,
      'enabled': enabled,
      'notes': notes,
    };
  }

  factory RoutineBlock.fromJson(Map<String, dynamic> json) {
    final rId = (json['routineId'] ?? json['routine_id']) as String? ?? '';
    final sHour = (json['startHour'] ?? json['start_hour']) as int? ?? 0;
    final sMinute = (json['startMinute'] ?? json['start_minute']) as int? ?? 0;
    final eHour = (json['endHour'] ?? json['end_hour']) as int? ?? 0;
    final eMinute = (json['endMinute'] ?? json['end_minute']) as int? ?? 0;
    final sortOrder = (json['order'] ?? json['sort_order']) as int? ?? 0;

    return RoutineBlock(
      id: json['id'] as String,
      routineId: rId,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startTime: TimeOfDay(hour: sHour, minute: sMinute),
      endTime: TimeOfDay(hour: eHour, minute: eMinute),
      category: json['category'] as String? ?? 'Routine',
      icon: json['icon'] as String? ?? '📌',
      color: json['color'] != null
          ? Color((json['color'] as num).toInt())
          : Colors.blue,
      order: sortOrder,
      enabled: json['enabled'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
    );
  }
}

