import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import '../models/cloud_models.dart';

final mockSupabaseProvider = Provider<CloudSyncProvider>((ref) {
  return MockSupabaseProvider();
});

class MockSupabaseProvider implements CloudSyncProvider {
  CloudAccount? _currentUser;
  
  // Simulate cloud database state
  final Map<String, Map<String, dynamic>> _cloudDb = {};
  
  // Simulate network conditions
  final bool _simulateNetworkLatency = true;
  bool _simulateOffline = false;

  @override
  Future<CloudAccount?> authenticate(String email, String password) async {
    await _delay();
    if (_simulateOffline) throw Exception('Network unavailable');
    
    _currentUser = CloudAccount(
      userId: 'mock_user_123',
      email: email,
      displayName: email.split('@').first,
      createdAt: DateTime.now(),
      syncEnabled: true,
    );
    return _currentUser;
  }

  @override
  Future<CloudAccount?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    await _delay();
    _currentUser = null;
  }

  @override
  Future<DateTime> getServerTime() async {
    await _delay();
    return DateTime.now().toUtc();
  }

  @override
  Future<void> pushChanges(List<SyncQueueItem> items, Map<String, dynamic> payloads) async {
    await _delay();
    if (_simulateOffline) throw Exception('Network unavailable');
    if (_currentUser == null) throw Exception('Unauthorized');

    for (var item in items) {
      if (item.operation == SyncOperation.create || item.operation == SyncOperation.update) {
        final payload = payloads[item.entityId];
        if (payload != null) {
          _cloudDb[item.entityId] = {
            ...payload,
            '_serverUpdatedAt': DateTime.now().toUtc().toIso8601String(),
          };
        }
      } else if (item.operation == SyncOperation.delete) {
        if (_cloudDb.containsKey(item.entityId)) {
          _cloudDb[item.entityId]!['_deletedAt'] = DateTime.now().toUtc().toIso8601String();
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>> pullChanges(DateTime? lastSyncedAt) async {
    await _delay();
    if (_simulateOffline) throw Exception('Network unavailable');
    if (_currentUser == null) throw Exception('Unauthorized');

    final changes = <String, dynamic>{};
    
    _cloudDb.forEach((id, record) {
      final updatedAt = DateTime.parse(record['_serverUpdatedAt']);
      if (lastSyncedAt == null || updatedAt.isAfter(lastSyncedAt)) {
        changes[id] = record;
      }
    });
    
    return changes;
  }

  Future<void> _delay() async {
    if (_simulateNetworkLatency) {
      await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));
    }
  }
  
  // Test Helpers
  void setOffline(bool offline) => _simulateOffline = offline;
}
