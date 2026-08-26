
enum SyncStatus { offline, pending, syncing, synced, failed, conflict }
enum SyncOperation { create, update, delete }

class CloudAccount {
  final String userId;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastSyncAt;
  final bool syncEnabled;
  final bool backupEnabled;

  CloudAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.lastSyncAt,
    this.syncEnabled = false,
    this.backupEnabled = false,
  });

  CloudAccount copyWith({
    String? userId,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastSyncAt,
    bool? syncEnabled,
    bool? backupEnabled,
  }) {
    return CloudAccount(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      backupEnabled: backupEnabled ?? this.backupEnabled,
    );
  }
}

class SyncQueueItem {
  final String id;
  final String entityType; // e.g., 'tasks', 'focus_sessions'
  final String entityId;
  final SyncOperation operation;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int retryCount;
  final String? lastError;
  final SyncStatus status;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.createdAt,
    required this.updatedAt,
    this.retryCount = 0,
    this.lastError,
    this.status = SyncStatus.pending,
  });

  SyncQueueItem copyWith({
    int? retryCount,
    String? lastError,
    SyncStatus? status,
    DateTime? updatedAt,
  }) {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }
}

class SyncMetadata {
  final String entityId;
  final String entityType;
  final DateTime localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final DateTime? lastSyncedAt;
  final int syncVersion;
  final DateTime? deletedAt;

  SyncMetadata({
    required this.entityId,
    required this.entityType,
    required this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.lastSyncedAt,
    this.syncVersion = 1,
    this.deletedAt,
  });

  SyncMetadata copyWith({
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
    DateTime? lastSyncedAt,
    int? syncVersion,
    DateTime? deletedAt,
  }) {
    return SyncMetadata(
      entityId: entityId,
      entityType: entityType,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
