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
