import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cloud_models.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

class SyncRepository {
  // In a real app this would be a local SQLite table. 
  // For MVP we mock it in memory.
  final List<SyncQueueItem> _queue = [];
  final Map<String, SyncMetadata> _metadata = {};

  Future<void> enqueueChange({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
  }) async {
    // Deduplicate: If an update already exists in queue for this entity, we just update its timestamp.
    final existingIndex = _queue.indexWhere((q) => q.entityId == entityId && q.entityType == entityType);
    
    if (existingIndex != -1) {
      final existing = _queue[existingIndex];
      // If we are deleting something that was pending creation, just remove it from queue entirely
      if (existing.operation == SyncOperation.create && operation == SyncOperation.delete) {
        _queue.removeAt(existingIndex);
        return;
      }
      // Update existing item
      _queue[existingIndex] = existing.copyWith(
        updatedAt: DateTime.now(),
        status: SyncStatus.pending,
      );
    } else {
      _queue.add(SyncQueueItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    return _queue.where((item) => item.status == SyncStatus.pending || item.status == SyncStatus.failed).toList();
  }

  Future<void> markItemSynced(String queueItemId) async {
    _queue.removeWhere((q) => q.id == queueItemId);
  }

  Future<void> markItemFailed(String queueItemId, String error) async {
    final index = _queue.indexWhere((q) => q.id == queueItemId);
    if (index != -1) {
      final item = _queue[index];
      _queue[index] = item.copyWith(
        status: SyncStatus.failed,
        lastError: error,
        retryCount: item.retryCount + 1,
      );
    }
  }

  Future<SyncMetadata?> getMetadata(String entityId) async {
    return _metadata[entityId];
  }

  Future<void> saveMetadata(SyncMetadata metadata) async {
    _metadata[metadata.entityId] = metadata;
  }
}
