import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/routine.dart';
import '../../data/models/routine_block.dart';
import '../../data/repositories/routine_repository.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';

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

  void _notifyRelated(String routineId) {
    _ref.invalidate(routinesProvider);
    _ref.invalidate(activeRoutineProvider);
    _ref.invalidate(routineBlocksProvider(routineId));
    _ref.invalidate(dailyScheduleProvider);
    _ref.invalidate(scheduleActivitiesProvider);
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> addRoutine(Routine routine, List<RoutineBlock> blocks) async {
    await _repo.addRoutine(routine, blocks);
    final syncRepo = _ref.read(syncRepositoryProvider);
    await syncRepo.enqueueChange(
      entityType: 'routines',
      entityId: routine.id,
      operation: SyncOperation.create,
    );
    for (var b in blocks) {
      await syncRepo.enqueueChange(
        entityType: 'routine_blocks',
        entityId: b.id,
        operation: SyncOperation.create,
      );
    }
    _notifyRelated(routine.id);
  }

  Future<void> updateRoutine(Routine routine) async {
    await _repo.updateRoutine(routine);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'routines',
      entityId: routine.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(routine.id);
  }

  Future<void> deleteRoutine(String id) async {
    await _repo.deleteRoutine(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'routines',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(id);
  }
  
  Future<void> addRoutineBlock(RoutineBlock block) async {
    await _repo.addRoutineBlock(block);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'routine_blocks',
      entityId: block.id,
      operation: SyncOperation.create,
    );
    _notifyRelated(block.routineId);
  }

  Future<void> updateRoutineBlock(RoutineBlock block) async {
    await _repo.updateRoutineBlock(block);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'routine_blocks',
      entityId: block.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(block.routineId);
  }

  Future<void> deleteRoutineBlock(String id, String routineId) async {
    await _repo.deleteRoutineBlock(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'routine_blocks',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(routineId);
  }
}

final routineNotifierProvider = Provider<RoutineNotifier>((ref) {
  return RoutineNotifier(ref.watch(routineRepositoryProvider), ref);
});
