import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/routine.dart';
import '../../data/models/routine_block.dart';
import '../../data/repositories/routine_repository.dart';

final routinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.getAllRoutines();
});

final routineBlocksProvider = FutureProvider.family<List<RoutineBlock>, String>((ref, routineId) async {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.getBlocksForRoutine(routineId);
});

final activeRoutineProvider = FutureProvider<Routine?>((ref) async {
  final routines = await ref.watch(routinesProvider.future);
  try {
    return routines.firstWhere((r) => r.enabled);
  } catch (_) {
    return null;
  }
});


class RoutineNotifier extends StateNotifier<AsyncValue<void>> {
  final RoutineRepository _repo;
  final Ref _ref;

  RoutineNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> addRoutine(Routine routine, List<RoutineBlock> blocks) async {
    await _repo.addRoutine(routine, blocks);
    _ref.invalidate(routinesProvider);
  }

  Future<void> updateRoutine(Routine routine) async {
    await _repo.updateRoutine(routine);
    _ref.invalidate(routinesProvider);
    _ref.invalidate(routineBlocksProvider(routine.id));
  }

  Future<void> deleteRoutine(String id) async {
    await _repo.deleteRoutine(id);
    _ref.invalidate(routinesProvider);
    _ref.invalidate(routineBlocksProvider(id));
  }
  
  Future<void> addRoutineBlock(RoutineBlock block) async {
    await _repo.addRoutineBlock(block);
    _ref.invalidate(routineBlocksProvider(block.routineId));
  }

  Future<void> updateRoutineBlock(RoutineBlock block) async {
    await _repo.updateRoutineBlock(block);
    _ref.invalidate(routineBlocksProvider(block.routineId));
  }

  Future<void> deleteRoutineBlock(String id, String routineId) async {
    await _repo.deleteRoutineBlock(id);
    _ref.invalidate(routineBlocksProvider(routineId));
  }
}

final routineNotifierProvider = Provider<RoutineNotifier>((ref) {
  return RoutineNotifier(ref.watch(routineRepositoryProvider), ref);
});
