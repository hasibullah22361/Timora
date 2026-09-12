import 'package:flutter/material.dart';
import 'routine.dart';
import 'routine_block.dart';
import 'package:uuid/uuid.dart';

class RoutineTemplateBlockData {
  final String title;
  final String description;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String category;
  final String icon;
  final Color color;

  const RoutineTemplateBlockData({
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.icon,
    required this.color,
  });
}

class RoutineTemplate {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color color;
  final List<int> defaultDays;
  final List<RoutineTemplateBlockData> blocks;

  const RoutineTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultDays,
    required this.blocks,
  });

  factory RoutineTemplate.fromSupabase(Map<String, dynamic> map) {
    Color parseColor(dynamic c) {
      if (c is int) return Color(c);
      if (c is String) {
        final hex = c.replaceFirst('#', '').replaceAll('0x', '');
        return Color(int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16) ?? 0xFF3B82F6);
      }
      return const Color(0xFF3B82F6);
    }

    final rawBlocks = map['blocks'] as List<dynamic>? ?? [];
    final parsedBlocks = rawBlocks.map((b) {
      final bMap = Map<String, dynamic>.from(b as Map);
      final startH = bMap['start_hour'] as int? ?? 8;
      final startM = bMap['start_minute'] as int? ?? 0;
      final endH = bMap['end_hour'] as int? ?? 9;
      final endM = bMap['end_minute'] as int? ?? 0;

      return RoutineTemplateBlockData(
        title: bMap['title'] as String? ?? 'Activity',
        description: bMap['description'] as String? ?? '',
        startTime: TimeOfDay(hour: startH, minute: startM),
        endTime: TimeOfDay(hour: endH, minute: endM),
        category: bMap['category'] as String? ?? 'Personal',
        icon: bMap['icon'] as String? ?? '⚡',
        color: parseColor(bMap['color']),
      );
    }).toList();

    final defaultDaysRaw = map['default_days'] as List<dynamic>? ?? [1, 2, 3, 4, 5];
    final defaultDays = defaultDaysRaw.map((d) => d is int ? d : int.tryParse(d.toString()) ?? 1).toList();

    return RoutineTemplate(
      id: map['id'] as String? ?? const Uuid().v4(),
      title: map['title'] as String? ?? 'Custom Routine',
      description: map['description'] as String? ?? '',
      icon: map['icon'] as String? ?? '📅',
      color: parseColor(map['color']),
      defaultDays: defaultDays,
      blocks: parsedBlocks,
    );
  }

  Routine instantiateRoutine(String routineId) {
    return Routine(
      id: routineId,
      name: title,
      description: description,
      icon: icon,
      color: color,
      enabled: true,
      daysOfWeek: defaultDays,
      createdAt: DateTime.now(),
    );
  }

  List<RoutineBlock> instantiateBlocks(String routineId) {
    const uuid = Uuid();
    return List.generate(blocks.length, (index) {
      final b = blocks[index];
      return RoutineBlock(
        id: uuid.v4(),
        routineId: routineId,
        title: b.title,
        description: b.description,
        startTime: b.startTime,
        endTime: b.endTime,
        category: b.category,
        icon: b.icon,
        color: b.color,
        order: index,
        enabled: true,
      );
    });
  }

  static const List<RoutineTemplate> predefinedTemplates = [
    RoutineTemplate(
      id: 'tpl_full_productive_day',
      title: 'Full Productive Day',
      description: 'Structured from 7:00 AM wake up to 11:00 PM sleep with work, prayer, rest, family and reflection.',
      icon: '🌅',
      color: Color(0xFFF59E0B),
      defaultDays: [1, 2, 3, 4, 5, 6, 7],
      blocks: [
        // Morning
        RoutineTemplateBlockData(
          title: 'Wake Up',
          description: 'Early morning rising and hydration.',
          startTime: TimeOfDay(hour: 7, minute: 0),
          endTime: TimeOfDay(hour: 7, minute: 15),
          category: 'Personal',
          icon: '🌅',
          color: Color(0xFFF59E0B),
        ),
        RoutineTemplateBlockData(
          title: 'Brush + Clean Face + Hygiene',
          description: 'Personal hygiene and dental care.',
          startTime: TimeOfDay(hour: 7, minute: 15),
          endTime: TimeOfDay(hour: 7, minute: 30),
          category: 'Health',
          icon: '🪥',
          color: Color(0xFF06B6D4),
        ),
        RoutineTemplateBlockData(
          title: 'Reading Book',
          description: 'Quiet morning reading and mental focus.',
          startTime: TimeOfDay(hour: 7, minute: 30),
          endTime: TimeOfDay(hour: 8, minute: 0),
          category: 'Study',
          icon: '📖',
          color: Color(0xFF8B5CF6),
        ),
        RoutineTemplateBlockData(
          title: 'Breakfast',
          description: 'Healthy nutritious morning meal.',
          startTime: TimeOfDay(hour: 8, minute: 0),
          endTime: TimeOfDay(hour: 8, minute: 30),
          category: 'Health',
          icon: '🍳',
          color: Color(0xFF10B981),
        ),
        RoutineTemplateBlockData(
          title: 'Get Ready',
          description: 'Dress up and organize daily bag and gear.',
          startTime: TimeOfDay(hour: 8, minute: 30),
          endTime: TimeOfDay(hour: 8, minute: 50),
          category: 'Personal',
          icon: '👕',
          color: Color(0xFF6366F1),
        ),
        RoutineTemplateBlockData(
          title: 'Work / Office / Grass Cutting / Workout',
          description: 'Primary morning productivity or exercise block.',
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 11, minute: 30),
          category: 'Work',
          icon: '💼',
          color: Color(0xFF2563EB),
        ),

        // Midday
        RoutineTemplateBlockData(
          title: 'Shower + Refreshment',
          description: 'Midday cleansing and refreshing cooldown.',
          startTime: TimeOfDay(hour: 11, minute: 50),
          endTime: TimeOfDay(hour: 12, minute: 30),
          category: 'Health',
          icon: '🚿',
          color: Color(0xFF0EA5E9),
        ),
        RoutineTemplateBlockData(
          title: 'Free Time / Rest',
          description: 'Unwind, stretch, or quiet downtime.',
          startTime: TimeOfDay(hour: 12, minute: 30),
          endTime: TimeOfDay(hour: 13, minute: 15),
          category: 'Personal',
          icon: '🌿',
          color: Color(0xFF10B981),
        ),
        RoutineTemplateBlockData(
          title: 'Zohar Prayer',
          description: 'Midday Islamic prayer.',
          startTime: TimeOfDay(hour: 13, minute: 15),
          endTime: TimeOfDay(hour: 13, minute: 45),
          category: 'Islamic',
          icon: '🕌',
          color: Color(0xFF059669),
        ),
        RoutineTemplateBlockData(
          title: 'Lunch',
          description: 'Midday meal and hydration.',
          startTime: TimeOfDay(hour: 13, minute: 45),
          endTime: TimeOfDay(hour: 14, minute: 15),
          category: 'Health',
          icon: '🍛',
          color: Color(0xFFF97316),
        ),
        RoutineTemplateBlockData(
          title: 'Prepare for Rest',
          description: 'Dim lights and prepare bedroom for siesta.',
          startTime: TimeOfDay(hour: 14, minute: 15),
          endTime: TimeOfDay(hour: 14, minute: 30),
          category: 'Personal',
          icon: '😴',
          color: Color(0xFF64748B),
        ),
        RoutineTemplateBlockData(
          title: 'Power Nap / Rest',
          description: 'Recharging afternoon sleep block.',
          startTime: TimeOfDay(hour: 14, minute: 30),
          endTime: TimeOfDay(hour: 16, minute: 30),
          category: 'Health',
          icon: '😴',
          color: Color(0xFF6366F1),
        ),

        // Afternoon
        RoutineTemplateBlockData(
          title: 'Asr Prayer',
          description: 'Afternoon Islamic prayer.',
          startTime: TimeOfDay(hour: 16, minute: 45),
          endTime: TimeOfDay(hour: 17, minute: 15),
          category: 'Islamic',
          icon: '🕌',
          color: Color(0xFF059669),
        ),
        RoutineTemplateBlockData(
          title: 'Sports / Volleyball',
          description: 'Outdoor athletic activity and movement.',
          startTime: TimeOfDay(hour: 17, minute: 20),
          endTime: TimeOfDay(hour: 18, minute: 30),
          category: 'Health',
          icon: '🏐',
          color: Color(0xFFE11D48),
        ),
        RoutineTemplateBlockData(
          title: 'Maghrib Prayer',
          description: 'Sunset Islamic prayer.',
          startTime: TimeOfDay(hour: 18, minute: 30),
          endTime: TimeOfDay(hour: 18, minute: 50),
          category: 'Islamic',
          icon: '🕌',
          color: Color(0xFF059669),
        ),

        // Evening
        RoutineTemplateBlockData(
          title: 'Family Time + Dinner',
          description: 'Evening dinner together and bonding.',
          startTime: TimeOfDay(hour: 18, minute: 50),
          endTime: TimeOfDay(hour: 20, minute: 25),
          category: 'Family',
          icon: '👨‍👩‍👧',
          color: Color(0xFFD97706),
        ),
        RoutineTemplateBlockData(
          title: 'Isha Prayer',
          description: 'Night Islamic prayer.',
          startTime: TimeOfDay(hour: 20, minute: 25),
          endTime: TimeOfDay(hour: 21, minute: 0),
          category: 'Islamic',
          icon: '🕌',
          color: Color(0xFF059669),
        ),
        RoutineTemplateBlockData(
          title: 'Study / Project / Development',
          description: 'Focused evening skill acquisition or coding block.',
          startTime: TimeOfDay(hour: 21, minute: 0),
          endTime: TimeOfDay(hour: 22, minute: 30),
          category: 'Work',
          icon: '💻',
          color: Color(0xFF7C3AED),
        ),
        RoutineTemplateBlockData(
          title: 'Daily Review',
          description: 'Review productivity snapshot and reflection.',
          startTime: TimeOfDay(hour: 22, minute: 30),
          endTime: TimeOfDay(hour: 22, minute: 45),
          category: 'Personal',
          icon: '📊',
          color: Color(0xFF4F46E5),
        ),
        RoutineTemplateBlockData(
          title: 'Plan Next Day',
          description: 'Align agenda, schedule, and priority tasks for tomorrow.',
          startTime: TimeOfDay(hour: 22, minute: 46),
          endTime: TimeOfDay(hour: 22, minute: 56),
          category: 'Personal',
          icon: '📝',
          color: Color(0xFF2563EB),
        ),
        RoutineTemplateBlockData(
          title: 'Sleep',
          description: 'Restorative overnight deep sleep.',
          startTime: TimeOfDay(hour: 23, minute: 0),
          endTime: TimeOfDay(hour: 7, minute: 0),
          category: 'Health',
          icon: '😴',
          color: Color(0xFF3B82F6),
        ),
      ],
    ),
    RoutineTemplate(
      id: 'tpl_morning_momentum',
      title: 'Morning Momentum',
      description: 'Start the day primed with physical activation, mental clarity, and clear intent.',
      icon: '🌅',
      color: Color(0xFFF59E0B),
      defaultDays: [1, 2, 3, 4, 5],
      blocks: [
        RoutineTemplateBlockData(
          title: 'Hydrate & Morning Stretch',
          description: 'Drink 500ml water and light mobility stretching.',
          startTime: TimeOfDay(hour: 6, minute: 30),
          endTime: TimeOfDay(hour: 7, minute: 0),
          category: 'Health',
          icon: '💧',
          color: Color(0xFF06B6D4),
        ),
        RoutineTemplateBlockData(
          title: 'Physical Workout / Run',
          description: 'Cardio, strength training, or yoga session.',
          startTime: TimeOfDay(hour: 7, minute: 0),
          endTime: TimeOfDay(hour: 7, minute: 45),
          category: 'Fitness',
          icon: '🏃',
          color: Color(0xFF10B981),
        ),
        RoutineTemplateBlockData(
          title: 'Breakfast & Mindful Journaling',
          description: 'Nutritious meal and morning diary reflection.',
          startTime: TimeOfDay(hour: 7, minute: 45),
          endTime: TimeOfDay(hour: 8, minute: 30),
          category: 'Health',
          icon: '☕',
          color: Color(0xFFF59E0B),
        ),
        RoutineTemplateBlockData(
          title: 'Daily Planning & Top 3 Priorities',
          description: 'Review schedule, prioritize tasks, and align focus.',
          startTime: TimeOfDay(hour: 8, minute: 30),
          endTime: TimeOfDay(hour: 9, minute: 0),
          category: 'Productivity',
          icon: '🎯',
          color: Color(0xFF6366F1),
        ),
      ],
    ),
    RoutineTemplate(
      id: 'tpl_deep_work',
      title: 'Deep Work Power Blocks',
      description: 'Uninterrupted 90-minute blocks for high-value focus and output.',
      icon: '⚡',
      color: Color(0xFF6366F1),
      defaultDays: [1, 2, 3, 4, 5],
      blocks: [
        RoutineTemplateBlockData(
          title: 'Deep Focus Block 1 (Hardest Task)',
          description: 'Zero distractions, full concentration on primary objective.',
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 11, minute: 0),
          category: 'Work',
          icon: '🧠',
          color: Color(0xFF4F46E5),
        ),
        RoutineTemplateBlockData(
          title: 'Recharge Walk & Hydration',
          description: 'Step away from screen, walk, and rest eyes.',
          startTime: TimeOfDay(hour: 11, minute: 0),
          endTime: TimeOfDay(hour: 11, minute: 20),
          category: 'Rest',
          icon: '🚶',
          color: Color(0xFF10B981),
        ),
        RoutineTemplateBlockData(
          title: 'Deep Focus Block 2 (Execution)',
          description: 'Drafting, coding, writing, or analysis work.',
          startTime: TimeOfDay(hour: 11, minute: 20),
          endTime: TimeOfDay(hour: 13, minute: 0),
          category: 'Work',
          icon: '💻',
          color: Color(0xFF2563EB),
        ),
      ],
    ),
    RoutineTemplate(
      id: 'tpl_evening_winddown',
      title: 'Evening Wind-Down',
      description: 'Reflect on accomplishments, prep tomorrow, and promote deep rest.',
      icon: '🌙',
      color: Color(0xFF8B5CF6),
      defaultDays: [1, 2, 3, 4, 5, 6, 7],
      blocks: [
        RoutineTemplateBlockData(
          title: 'Day Review & Tomorrow Setup',
          description: 'Log diary entry, celebrate wins, and set tomorrow priorities.',
          startTime: TimeOfDay(hour: 20, minute: 30),
          endTime: TimeOfDay(hour: 21, minute: 0),
          category: 'Productivity',
          icon: '📖',
          color: Color(0xFF7C3AED),
        ),
        RoutineTemplateBlockData(
          title: 'Screen-Free Reading & Relaxation',
          description: 'Physical book reading, chamomile tea, or calm audio.',
          startTime: TimeOfDay(hour: 21, minute: 0),
          endTime: TimeOfDay(hour: 22, minute: 0),
          category: 'Rest',
          icon: '📚',
          color: Color(0xFF6366F1),
        ),
        RoutineTemplateBlockData(
          title: 'Sleep Preparation',
          description: 'Dark room, cool temperature, phone on do-not-disturb.',
          startTime: TimeOfDay(hour: 22, minute: 0),
          endTime: TimeOfDay(hour: 22, minute: 30),
          category: 'Health',
          icon: '😴',
          color: Color(0xFF475569),
        ),
      ],
    ),
    RoutineTemplate(
      id: 'tpl_student_mastery',
      title: 'Student Mastery Schedule',
      description: 'Optimized for high-retention study, active recall, and assignments.',
      icon: '🎓',
      color: Color(0xFF0284C7),
      defaultDays: [1, 2, 3, 4, 5],
      blocks: [
        RoutineTemplateBlockData(
          title: 'Lecture Review & Notes Synthesis',
          description: 'Summarize concepts and create flashcards.',
          startTime: TimeOfDay(hour: 8, minute: 30),
          endTime: TimeOfDay(hour: 10, minute: 30),
          category: 'Study',
          icon: '📝',
          color: Color(0xFF0284C7),
        ),
        RoutineTemplateBlockData(
          title: 'Active Recall & Practice Problems',
          description: 'Solve problem sets without looking at solutions.',
          startTime: TimeOfDay(hour: 11, minute: 0),
          endTime: TimeOfDay(hour: 13, minute: 0),
          category: 'Study',
          icon: '💡',
          color: Color(0xFF0D9488),
        ),
      ],
    ),
    RoutineTemplate(
      id: 'tpl_weekend_reset',
      title: 'Weekend Reset & Recharge',
      description: 'Maintain healthy momentum without weekday burnout.',
      icon: '🌿',
      color: Color(0xFF10B981),
      defaultDays: [6, 7],
      blocks: [
        RoutineTemplateBlockData(
          title: 'Outdoor Activity & Recreation',
          description: 'Nature walk, cycling, or socializing in sunshine.',
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
          category: 'Rest',
          icon: '🚴',
          color: Color(0xFF10B981),
        ),
        RoutineTemplateBlockData(
          title: 'Life Admin & Weekly Review',
          description: 'Meal prep, organize living space, and set weekly goals.',
          startTime: TimeOfDay(hour: 15, minute: 0),
          endTime: TimeOfDay(hour: 16, minute: 30),
          category: 'Productivity',
          icon: '🧹',
          color: Color(0xFF3B82F6),
        ),
      ],
    ),
  ];
}
