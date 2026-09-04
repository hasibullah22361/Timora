import 'package:flutter/material.dart';

enum ActivityCategoryGroup {
  islamic('Islamic & Prayer', '🕌', Color(0xFF0D9488)),
  desiLifestyle('Desi Lifestyle', '☕', Color(0xFFD97706)),
  healthFitness('Health & Fitness', '🏃', Color(0xFF10B981)),
  foodDrink('Food & Drink', '🍽️', Color(0xFFF59E0B)),
  personalCare('Personal Care', '✨', Color(0xFF06B6D4)),
  workStudy('Work & Study', '💻', Color(0xFF2563EB)),
  productivity('Productivity', '⚡', Color(0xFF8B5CF6)),
  lifeHome('Life & Home', '🏡', Color(0xFFEC4899)),
  restWellbeing('Rest & Wellbeing', '🌙', Color(0xFF6366F1)),
  spiritualPersonal('Spiritual & Growth', '🌱', Color(0xFF14B8A6)),
  custom('Custom', '⭐', Color(0xFFF43F5E));

  final String label;
  final String icon;
  final Color color;

  const ActivityCategoryGroup(this.label, this.icon, this.color);
}

class ActivityDefinition {
  final String id;
  final String name;
  final String category;
  final ActivityCategoryGroup categoryGroup;
  final String icon;
  final String description;
  final Color color;
  final int defaultDurationMinutes;
  final bool isCustom;
  final bool isFavorite;

  const ActivityDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryGroup,
    required this.icon,
    this.description = '',
    this.color = const Color(0xFF2563EB),
    this.defaultDurationMinutes = 45,
    this.isCustom = false,
    this.isFavorite = false,
  });

  ActivityDefinition copyWith({
    String? name,
    String? category,
    ActivityCategoryGroup? categoryGroup,
    String? icon,
    String? description,
    Color? color,
    int? defaultDurationMinutes,
    bool? isCustom,
    bool? isFavorite,
  }) {
    return ActivityDefinition(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryGroup: categoryGroup ?? this.categoryGroup,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      color: color ?? this.color,
      defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'categoryGroup': categoryGroup.name,
      'icon': icon,
      'description': description,
      'color': color.toARGB32(),
      'defaultDurationMinutes': defaultDurationMinutes,
      'isCustom': isCustom,
      'isFavorite': isFavorite,
    };
  }

  factory ActivityDefinition.fromJson(Map<String, dynamic> json) {
    ActivityCategoryGroup group = ActivityCategoryGroup.custom;
    if (json['categoryGroup'] != null) {
      try {
        group = ActivityCategoryGroup.values.firstWhere(
          (g) => g.name == json['categoryGroup'],
          orElse: () => ActivityCategoryGroup.custom,
        );
      } catch (_) {}
    }

    return ActivityDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Personal',
      categoryGroup: group,
      icon: json['icon'] as String? ?? '📌',
      description: json['description'] as String? ?? '',
      color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFF2563EB),
      defaultDurationMinutes: json['defaultDurationMinutes'] as int? ?? 45,
      isCustom: json['isCustom'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
