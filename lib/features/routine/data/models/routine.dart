import 'package:flutter/material.dart';

enum RoutineFrequency { daily, weekly, monthly }

class Routine {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final bool enabled;
  // e.g. [1, 2, 3, 4, 5] for Monday-Friday (DateTime.monday = 1)
  final List<int> daysOfWeek;
  final DateTime startDate;
  final DateTime? endDate;
  final RoutineFrequency frequency;
  final int? monthlyDay;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Routine({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = '📌',
    this.color = Colors.blue,
    this.enabled = true,
    required this.daysOfWeek,
    DateTime? startDate,
    this.endDate,
    this.frequency = RoutineFrequency.weekly,
    this.monthlyDay,
    required this.createdAt,
    this.updatedAt,
  }) : startDate = startDate ?? createdAt;

  /// Checks if this routine is active on a specific calendar date,
  /// honoring startDate, endDate, frequency, and active weekdays.
  bool isActiveOn(DateTime date) {
    if (!enabled) return false;

    final targetDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (targetDate.isBefore(start)) return false;

    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (targetDate.isAfter(end)) return false;
    }

    switch (frequency) {
      case RoutineFrequency.daily:
        return true;
      case RoutineFrequency.weekly:
        return daysOfWeek.contains(date.weekday);
      case RoutineFrequency.monthly:
        final day = monthlyDay ?? startDate.day;
        return date.day == day;
    }
  }

  Routine copyWith({
    String? name,
    String? description,
    String? icon,
    Color? color,
    bool? enabled,
    List<int>? daysOfWeek,
    DateTime? startDate,
    DateTime? endDate,
    RoutineFrequency? frequency,
    int? monthlyDay,
    DateTime? updatedAt,
  }) {
    return Routine(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color.toARGB32(),
      'enabled': enabled,
      'daysOfWeek': daysOfWeek,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'frequency': frequency.name,
      'monthlyDay': monthlyDay,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Routine.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();

    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📌',
      color: json['color'] != null
          ? Color(json['color'] as int)
          : Colors.blue,
      enabled: json['enabled'] as bool? ?? true,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : createdAt,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      frequency: json['frequency'] != null
          ? RoutineFrequency.values.firstWhere(
              (f) => f.name == json['frequency'],
              orElse: () => RoutineFrequency.weekly,
            )
          : RoutineFrequency.weekly,
      monthlyDay: json['monthlyDay'] as int?,
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

