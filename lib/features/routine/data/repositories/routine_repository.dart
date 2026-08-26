import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/routine.dart';
import '../models/routine_block.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RoutineRepository(prefs);
});

class RoutineRepository {
  static const String _routinesKey = 'timora_routines_data';
  static const String _blocksKey = 'timora_routine_blocks_data';

  final SharedPreferences _prefs;
  final List<Routine> _routines = [];
  final List<RoutineBlock> _blocks = [];
  final _uuid = const Uuid();

  RoutineRepository(this._prefs) {
    _loadFromStorage();
  }

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
      name: 'Core Study & Focus Routine',
      description: 'Daily structured routine for study, research, and personal time',
      icon: '📚',
      color: const Color(0xFF2962FF),
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // All week
      createdAt: DateTime.now(),
    ));

    void addBlock(String title, String desc, String icon, int startH, int endH, Color color, int order, String category) {
      _blocks.add(RoutineBlock(
        id: _uuid.v4(),
        routineId: routineId,
        title: title,
        description: desc,
        startTime: TimeOfDay(hour: startH, minute: 0),
        endTime: TimeOfDay(hour: endH, minute: 0),
        category: category,
        icon: icon,
        color: color,
        order: order,
      ));
    }

    // 12:00 AM – 8:00 AM: Sleep
    addBlock('Sleep', 'Sleep and full recovery', '💤', 0, 8, Colors.indigo, 0, 'Sleep');
    // 8:00 AM – 9:00 AM: Get ready, clothes, breakfast
    addBlock('Get Ready', 'Get ready, clothes, breakfast', '🍳', 8, 9, Colors.orange, 1, 'Routine');
    // 9:00 AM – 12:00 PM: AI & Data Science study
    addBlock('AI & Data Science Study', 'Deep study session', '🤖', 9, 12, Colors.blue, 2, 'AI & Data Science');
    // 12:00 PM – 1:00 PM: Lunch / rest
    addBlock('Lunch / Rest', 'Lunch and recharge', '🍛', 12, 13, Colors.green, 3, 'Food');
    // 1:00 PM – 5:00 PM: AI & Data Science study
    addBlock('AI & Data Science Study', 'Practical study & coding', '🤖', 13, 17, Colors.blue, 4, 'AI & Data Science');
    // 5:00 PM – 8:00 PM: Tea, food, prayer, rest / personal time
    addBlock('Personal Time', 'Tea, food, prayer, rest / personal time', '☕', 17, 20, Colors.teal, 5, 'Personal');
    // 8:00 PM – 11:00 PM: Research + Project
    addBlock('Research + Project', 'Research and project implementation', '💻', 20, 23, Colors.purple, 6, 'Project');
    // 11:00 PM – 12:00 AM: Daily review + plan tomorrow
    addBlock('Daily Review', 'Daily review + plan tomorrow', '📝', 23, 0, Colors.blueGrey, 7, 'Routine');

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
}

