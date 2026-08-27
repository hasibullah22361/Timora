import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/routine.dart';
import '../models/routine_block.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return RoutineRepository(prefs, userId: currentUser?.id);
});

class RoutineRepository {
  static const String _defaultRoutinesKey = 'timora_routines_data';
  static const String _defaultBlocksKey = 'timora_routine_blocks_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<Routine> _routines = [];
  final List<RoutineBlock> _blocks = [];
  final _uuid = const Uuid();

  RoutineRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _routinesKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_routines_${_userId}_data'
      : _defaultRoutinesKey;

  String get _blocksKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_blocks_${_userId}_data'
      : _defaultBlocksKey;

  void _loadFromStorage() {
    final routinesJson = _prefs.getString(_routinesKey);
    final blocksJson = _prefs.getString(_blocksKey);

    if (routinesJson != null && blocksJson != null) {
      try {
        final List<dynamic> decodedRoutines = jsonDecode(routinesJson);
        final List<dynamic> decodedBlocks = jsonDecode(blocksJson);

        _routines.clear();
        _blocks.clear();

        for (var item in decodedRoutines) {
          _routines.add(Routine.fromJson(item as Map<String, dynamic>));
        }
        for (var item in decodedBlocks) {
          _blocks.add(RoutineBlock.fromJson(item as Map<String, dynamic>));
        }
        if (_routines.isNotEmpty) {
          return;
        }
      } catch (_) {
        // Fallback to seeding defaults on decode error
      }
    }

    _populateDefaultRoutine();
  }

  Future<void> _saveToStorage() async {
    final routinesJson = jsonEncode(_routines.map((r) => r.toJson()).toList());
    final blocksJson = jsonEncode(_blocks.map((b) => b.toJson()).toList());
    await _prefs.setString(_routinesKey, routinesJson);
    await _prefs.setString(_blocksKey, blocksJson);
  }

  void _populateDefaultRoutine() {
    _routines.clear();
    _blocks.clear();

    final routineId = _uuid.v4();
    _routines.add(Routine(
      id: routineId,
      name: 'Master Daily Productivity Routine',
      description: 'Balanced daily structured routine for deep focus, learning, health, and personal growth',
      icon: '⚡',
      color: const Color(0xFF2563EB),
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // All week
      createdAt: DateTime.now(),
    ));

    void addBlock(String title, String desc, String icon, int startH, int startM, int endH, int endM, Color color, int order, String category) {
      _blocks.add(RoutineBlock(
        id: _uuid.v4(),
        routineId: routineId,
        title: title,
        description: desc,
        startTime: TimeOfDay(hour: startH, minute: startM),
        endTime: TimeOfDay(hour: endH, minute: endM),
        category: category,
        icon: icon,
        color: color,
        order: order,
      ));
    }

    // 12:00 AM – 7:30 AM: Sleep
    addBlock('Night Sleep', 'Restful sleep and physical recovery', '💤', 0, 0, 7, 30, const Color(0xFF4338CA), 0, 'Sleep');
    // 7:30 AM – 8:30 AM: Morning routine & breakfast
    addBlock('Morning Routine & Breakfast', 'Hydrate, stretch, shower, and energizing breakfast', '🍳', 7, 30, 8, 30, const Color(0xFFF59E0B), 1, 'Personal Care');
    // 8:30 AM – 12:30 PM: Deep focus block 1
    addBlock('Deep Work / Focus Block 1', 'High priority goals, intense focus, and output', '🔥', 8, 30, 12, 30, const Color(0xFF2563EB), 2, 'Work');
    // 12:30 PM – 1:30 PM: Lunch & rest
    addBlock('Lunch & Recharge', 'Nutritious lunch and relaxation break', '🍲', 12, 30, 13, 30, const Color(0xFF10B981), 3, 'Food');
    // 1:30 PM – 5:30 PM: Deep focus block 2
    addBlock('Deep Work / Focus Block 2', 'Project work, collaborative tasks, and execution', '💻', 13, 30, 17, 30, const Color(0xFF2563EB), 4, 'Work');
    // 5:30 PM – 7:00 PM: Workout & personal time
    addBlock('Workout & Personal Time', 'Exercise, gym, outdoors, or personal care', '🏃', 17, 30, 19, 0, const Color(0xFF0D9488), 5, 'Health');
    // 7:00 PM – 8:30 PM: Dinner & recharge
    addBlock('Dinner & Leisure', 'Dinner, family time, and leisure', '🍽️', 19, 0, 20, 30, const Color(0xFFEA580C), 6, 'Food');
    // 8:30 PM – 10:30 PM: Learning & reading
    addBlock('Skill Learning & Reading', 'Books, courses, research, and personal growth', '📖', 20, 30, 22, 30, const Color(0xFF8B5CF6), 7, 'Study');
    // 10:30 PM – 11:30 PM: Daily review & plan tomorrow
    addBlock('Daily Review & Planning', 'Reflect on accomplishments, clear tasks, plan tomorrow', '🗓️', 22, 30, 23, 30, const Color(0xFF64748B), 8, 'Productivity');
    // 11:30 PM – 12:00 AM: Wind down
    addBlock('Wind Down & Sleep Prep', 'Screen-off relaxation and preparing for rest', '🕯️', 23, 30, 0, 0, const Color(0xFF6366F1), 9, 'Personal Care');

    _saveToStorage();
  }

  Future<List<Routine>> getAllRoutines() async {
    return List.from(_routines);
  }

  Future<List<RoutineBlock>> getBlocksForRoutine(String routineId) async {
    final blocks = _blocks.where((b) => b.routineId == routineId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return blocks;
  }

  Future<void> addRoutine(Routine routine, List<RoutineBlock> blocks) async {
    _routines.add(routine);
    _blocks.addAll(blocks);
    await _saveToStorage();
  }

  Future<void> updateRoutine(Routine routine) async {
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      _routines[index] = routine.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  Future<void> deleteRoutine(String id) async {
    _routines.removeWhere((r) => r.id == id);
    _blocks.removeWhere((b) => b.routineId == id);
    await _saveToStorage();
  }

  Future<void> addRoutineBlock(RoutineBlock block) async {
    _blocks.add(block);
    await _saveToStorage();
  }

  Future<void> updateRoutineBlock(RoutineBlock block) async {
    final index = _blocks.indexWhere((b) => b.id == block.id);
    if (index >= 0) {
      _blocks[index] = block;
      await _saveToStorage();
    }
  }

  Future<void> deleteRoutineBlock(String id) async {
    _blocks.removeWhere((b) => b.id == id);
    await _saveToStorage();
  }

  Future<List<RoutineBlock>> getAllBlocks() async {
    return List.from(_blocks);
  }
}

