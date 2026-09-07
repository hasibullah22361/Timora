import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    _routines.clear();
    _blocks.clear();

    if (routinesJson != null && routinesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedRoutines = jsonDecode(routinesJson);
        for (var item in decodedRoutines) {
          _routines.add(Routine.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    if (blocksJson != null && blocksJson.isNotEmpty) {
      try {
        final List<dynamic> decodedBlocks = jsonDecode(blocksJson);
        for (var item in decodedBlocks) {
          _blocks.add(RoutineBlock.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final routinesJson = jsonEncode(_routines.map((r) => r.toJson()).toList());
    final blocksJson = jsonEncode(_blocks.map((b) => b.toJson()).toList());
    await _prefs.setString(_routinesKey, routinesJson);
    await _prefs.setString(_blocksKey, blocksJson);
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
    } else {
      _routines.add(routine);
    }
    await _saveToStorage();
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
    } else {
      _blocks.add(block);
    }
    await _saveToStorage();
  }

  Future<void> deleteRoutineBlock(String id) async {
    _blocks.removeWhere((b) => b.id == id);
    await _saveToStorage();
  }

  Future<List<RoutineBlock>> getAllBlocks() async {
    return List.from(_blocks);
  }
}

