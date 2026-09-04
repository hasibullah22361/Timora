import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import '../models/cloud_models.dart';

final mockSupabaseProvider = Provider<MockSupabaseProvider>((ref) {
  return MockSupabaseProvider();
});

class MockSupabaseProvider implements CloudSyncProvider {
  CloudAccount? _currentUser;
  
  // Simulated cloud database state (keyed by entityId)
  final Map<String, Map<String, dynamic>> _cloudDb = {};
  
  // Simulate network conditions
  bool _simulateNetworkLatency = false;
  bool _simulateOffline = false;

  void setOffline(bool offline) {
    _simulateOffline = offline;
  }

  void setSimulateLatency(bool latency) {
    _simulateNetworkLatency = latency;
  }

  bool get isOffline => _simulateOffline;

  @override
  Future<CloudAccount?> authenticate(String email, String password) async {
    await _delay();
    if (_simulateOffline) throw Exception('Network unavailable');
    
    _currentUser = CloudAccount(
      userId: 'cloud_${email.hashCode.abs()}',
      email: email,
      displayName: email.split('@').first,
      createdAt: DateTime.now(),
      syncEnabled: true,
      backupEnabled: true,
    );
    return _currentUser;
  }

  @override
  Future<CloudAccount?> getCurrentUser() async {
    return _currentUser;
  }

  void setCurrentUser(CloudAccount? account) {
    _currentUser = account;
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
    if (_currentUser == null) throw Exception('Unauthorized: Cloud Account required');

    final serverTimestamp = DateTime.now().toUtc().toIso8601String();

    for (var item in items) {
      if (item.operation == SyncOperation.create || item.operation == SyncOperation.update) {
        final payload = payloads[item.entityId];
        if (payload != null) {
          _cloudDb[item.entityId] = {
            ...payload,
            '_entityType': item.entityType,
            '_serverUpdatedAt': serverTimestamp,
            '_deletedAt': null,
          };
        }
      } else if (item.operation == SyncOperation.delete) {
        if (_cloudDb.containsKey(item.entityId)) {
          _cloudDb[item.entityId]!['_deletedAt'] = serverTimestamp;
          _cloudDb[item.entityId]!['_serverUpdatedAt'] = serverTimestamp;
        } else {
          _cloudDb[item.entityId] = {
            'id': item.entityId,
            '_entityType': item.entityType,
            '_deletedAt': serverTimestamp,
            '_serverUpdatedAt': serverTimestamp,
          };
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>> pullChanges(DateTime? lastSyncedAt) async {
    await _delay();
    if (_simulateOffline) throw Exception('Network unavailable');
    if (_currentUser == null) throw Exception('Unauthorized: Cloud Account required');

    final changes = <String, dynamic>{};
    
    _cloudDb.forEach((id, record) {
      final updatedAt = DateTime.parse(record['_serverUpdatedAt'] as String);
      if (lastSyncedAt == null || updatedAt.isAfter(lastSyncedAt)) {
        changes[id] = Map<String, dynamic>.from(record);
      }
    });
    
    return changes;
  }

  Future<void> _delay() async {
    if (_simulateNetworkLatency) {
      await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
    }
  }

  // Inspection helpers for tests
  Map<String, dynamic>? getCloudRecord(String entityId) => _cloudDb[entityId];
  int get cloudRecordCount => _cloudDb.length;
  void clearCloudDatabase() => _cloudDb.clear();
}
