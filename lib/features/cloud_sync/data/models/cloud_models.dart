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

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'syncEnabled': syncEnabled,
      'backupEnabled': backupEnabled,
    };
  }

  factory CloudAccount.fromJson(Map<String, dynamic> json) {
    return CloudAccount(
      userId: json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      syncEnabled: json['syncEnabled'] as bool? ?? false,
      backupEnabled: json['backupEnabled'] as bool? ?? false,
    );
  }
}

class SyncQueueItem {
  final String id;
  final String entityType; // e.g., 'tasks', 'routines', 'goals', etc.
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
      'status': status.name,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      operation: SyncOperation.values.firstWhere(
        (o) => o.name == json['operation'],
        orElse: () => SyncOperation.update,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      status: SyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
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

  Map<String, dynamic> toJson() {
    return {
      'entityId': entityId,
      'entityType': entityType,
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      'remoteUpdatedAt': remoteUpdatedAt?.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncVersion': syncVersion,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      entityId: json['entityId'] as String,
      entityType: json['entityType'] as String,
      localUpdatedAt: DateTime.parse(json['localUpdatedAt'] as String),
      remoteUpdatedAt: json['remoteUpdatedAt'] != null
          ? DateTime.parse(json['remoteUpdatedAt'] as String)
          : null,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      syncVersion: json['syncVersion'] as int? ?? 1,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
