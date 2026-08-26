import 'package:flutter/material.dart';

class Routine {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final bool enabled;
  // e.g. [1, 2, 3, 4, 5] for Monday-Friday (DateTime.monday = 1)
  final List<int> daysOfWeek;
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
    required this.createdAt,
    this.updatedAt,
  });

  Routine copyWith({
    String? name,
    String? description,
    String? icon,
    Color? color,
    bool? enabled,
    List<int>? daysOfWeek,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Routine.fromJson(Map<String, dynamic> json) {
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
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

