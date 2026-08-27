import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/cloud_models.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return SyncRepository(prefs, userId: currentUser?.id);
});

class SyncRepository {
  static const String _defaultQueueKey = 'timora_sync_queue_v1';
  static const String _defaultMetadataKey = 'timora_sync_metadata_v1';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<SyncQueueItem> _queue = [];
  final Map<String, SyncMetadata> _metadata = {};
  final _uuid = const Uuid();

  SyncRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _queueKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_sync_queue_${_userId}_v1'
      : _defaultQueueKey;

  String get _metadataKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_sync_metadata_${_userId}_v1'
      : _defaultMetadataKey;

  void _loadFromStorage() {
    // Load queue
    final queueStr = _prefs.getString(_queueKey);
    if (queueStr != null && queueStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(queueStr);
        _queue.clear();
        for (var item in decoded) {
          _queue.add(SyncQueueItem.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Error loading sync queue: $e');
      }
    }

    // Load metadata
    final metaStr = _prefs.getString(_metadataKey);
    if (metaStr != null && metaStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(metaStr);
        _metadata.clear();
        decoded.forEach((k, v) {
          _metadata[k] = SyncMetadata.fromJson(v as Map<String, dynamic>);
        });
      } catch (e) {
        debugPrint('Error loading sync metadata: $e');
      }
    }
  }

  Future<void> _saveQueue() async {
    final list = _queue.map((q) => q.toJson()).toList();
    await _prefs.setString(_queueKey, jsonEncode(list));
  }

  Future<void> _saveMetadataMap() async {
    final map = _metadata.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_metadataKey, jsonEncode(map));
  }

  Future<void> enqueueChange({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
  }) async {
    final existingIndex = _queue.indexWhere(
      (q) => q.entityId == entityId && q.entityType == entityType,
    );

    if (existingIndex != -1) {
      final existing = _queue[existingIndex];
      // If we are deleting something that was created while offline and not yet pushed:
      if (existing.operation == SyncOperation.create && operation == SyncOperation.delete) {
        _queue.removeAt(existingIndex);
        await _saveQueue();
        return;
      }
      // If it was created and is now updated, keep operation as create
      final effectiveOp = (existing.operation == SyncOperation.create && operation == SyncOperation.update)
          ? SyncOperation.create
          : operation;

      _queue[existingIndex] = SyncQueueItem(
        id: existing.id,
        entityType: existing.entityType,
        entityId: existing.entityId,
        operation: effectiveOp,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        retryCount: existing.retryCount,
        lastError: existing.lastError,
        status: SyncStatus.pending,
      );
    } else {
      _queue.add(SyncQueueItem(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: SyncStatus.pending,
      ));
    }

    await _saveQueue();
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    return _queue
        .where((item) => item.status == SyncStatus.pending || item.status == SyncStatus.failed)
        .toList();
  }

  Future<void> markItemSynced(String queueItemId) async {
    _queue.removeWhere((q) => q.id == queueItemId);
    await _saveQueue();
  }

  Future<void> markItemFailed(String queueItemId, String error) async {
    final index = _queue.indexWhere((q) => q.id == queueItemId);
    if (index != -1) {
      final item = _queue[index];
      _queue[index] = item.copyWith(
        status: SyncStatus.failed,
        lastError: error,
        retryCount: item.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      await _saveQueue();
    }
  }

  Future<SyncMetadata?> getMetadata(String entityId) async {
    return _metadata[entityId];
  }

  Future<void> saveMetadata(SyncMetadata metadata) async {
    _metadata[metadata.entityId] = metadata;
    await _saveMetadataMap();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
  }
}
