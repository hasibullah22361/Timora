import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/cloud_models.dart';
import '../data/providers/mock_supabase_provider.dart';
import '../data/repositories/sync_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
// Note: We would import all providers needed to extract payloads, but for MVP we focus on Tasks as the primary test.

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

// A global provider to expose sync status to the UI
final globalSyncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.offline);

class SyncService {
  final Ref _ref;

  SyncService(this._ref);

  Future<void> syncNow() async {
    final statusNotifier = _ref.read(globalSyncStatusProvider.notifier);
    statusNotifier.state = SyncStatus.syncing;
    
    try {
      final provider = _ref.read(mockSupabaseProvider);
      final user = await provider.getCurrentUser();
      
      if (user == null || !user.syncEnabled) {
        statusNotifier.state = SyncStatus.offline;
        return;
      }

      await _pushChanges();
      await _pullChanges();
      
      statusNotifier.state = SyncStatus.synced;
    } catch (e) {
      statusNotifier.state = SyncStatus.failed;
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _pushChanges() async {
    final syncRepo = _ref.read(syncRepositoryProvider);
    final provider = _ref.read(mockSupabaseProvider);
    
    final pending = await syncRepo.getPendingItems();
    if (pending.isEmpty) return;

    final payloads = <String, dynamic>{};
    
    // For MVP, we will extract Tasks payloads
    final tasks = await _ref.read(allTasksProvider.future);
    
    for (var item in pending) {
      if (item.entityType == 'tasks' && item.operation != SyncOperation.delete) {
        final task = tasks.firstWhere((t) => t.id == item.entityId, orElse: () => TaskModel(id: '', title: '', createdAt: DateTime.now()));
        if (task.id.isNotEmpty) {
          payloads[task.id] = task.toJson();
        }
      }
    }

    try {
      await provider.pushChanges(pending, payloads);
      // On success, clear queue
      for (var item in pending) {
        await syncRepo.markItemSynced(item.id);
      }
    } catch (e) {
      // Exponential backoff logic would evaluate here.
      for (var item in pending) {
        await syncRepo.markItemFailed(item.id, e.toString());
      }
      rethrow;
    }
  }

  Future<void> _pullChanges() async {
    // MVP: In a real app we'd fetch the highest lastSyncedAt from metadata.
    // Here we just fetch everything that changed.
    final provider = _ref.read(mockSupabaseProvider);
    final changes = await provider.pullChanges(null);
    
    if (changes.isEmpty) return;
    
    // Resolve conflicts
    final taskRepo = _ref.read(taskRepositoryProvider);
    final syncRepo = _ref.read(syncRepositoryProvider);
    
    for (var entry in changes.entries) {
      final id = entry.key;
      final record = entry.value;
      
      final isDeleted = record['_deletedAt'] != null;
      final serverUpdatedAt = DateTime.parse(record['_serverUpdatedAt']);
      
      final localMeta = await syncRepo.getMetadata(id);
      
      // Conflict Resolution: Last-Write-Wins
      if (localMeta != null && localMeta.localUpdatedAt.isAfter(serverUpdatedAt)) {
        // Local is newer. Ignore server change. It will be pushed in next cycle.
        continue;
      }
      
      // Server wins. Apply locally.
      if (isDeleted) {
        await taskRepo.deleteTask(id);
      } else {
        // Just recreate the task for MVP
        final task = TaskModel(
          id: id,
          title: record['title'] ?? 'Synced Task',
          createdAt: DateTime.tryParse(record['createdAt'] ?? '') ?? DateTime.now(),
        );
        await taskRepo.createTask(task);
      }
      
      // Update metadata
      await syncRepo.saveMetadata(SyncMetadata(
        entityId: id,
        entityType: 'tasks',
        localUpdatedAt: serverUpdatedAt, // It matches server now
        remoteUpdatedAt: serverUpdatedAt,
        lastSyncedAt: DateTime.now(),
        deletedAt: isDeleted ? serverUpdatedAt : null,
      ));
    }
  }
}
