import 'package:flutter/foundation.dart';

enum NotificationEventType {
  pre10Minutes,
  pre5Minutes,
  activityStart,
  activityEnd,
  nextDayPlan,
  testNotification,
}

enum NotificationSourceType {
  task,
  routine,
  schedule,
  other,
}

/// NotificationEvent — Unified model representing a scheduled Timora notification
/// that produces both a visible Android notification and a spoken voice announcement.
@immutable
class NotificationEvent {
  final String id;
  final int numericId;
  final NotificationEventType eventType;
  final NotificationSourceType sourceType;
  final String sourceId;
  final String title;
  final String notificationBody;
  final String spokenMessage;
  final DateTime scheduledTime;
  final bool enabled;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const NotificationEvent({
    required this.id,
    required this.numericId,
    required this.eventType,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.notificationBody,
    required this.spokenMessage,
    required this.scheduledTime,
    this.enabled = true,
    required this.createdAt,
    this.metadata = const {},
  });

  /// Deterministic numeric ID (positive 32-bit int) for Android PendingIntent & NotificationManager
  static int generateNumericId(String stringId) {
    return stringId.hashCode.abs() % 0x7FFFFFFF;
  }

  /// Construct a deterministic string ID for an event
  static String buildEventId({
    required NotificationSourceType sourceType,
    required String sourceId,
    required NotificationEventType eventType,
    required DateTime date,
  }) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return 'timora_evt_${sourceType.name}_${sourceId}_${eventType.name}_$dateStr';
  }

  factory NotificationEvent.create({
    required NotificationSourceType sourceType,
    required String sourceId,
    required NotificationEventType eventType,
    required String title,
    required String notificationBody,
    required String spokenMessage,
    required DateTime scheduledTime,
    bool enabled = true,
    Map<String, dynamic> metadata = const {},
  }) {
    final id = buildEventId(
      sourceType: sourceType,
      sourceId: sourceId,
      eventType: eventType,
      date: scheduledTime,
    );
    return NotificationEvent(
      id: id,
      numericId: generateNumericId(id),
      eventType: eventType,
      sourceType: sourceType,
      sourceId: sourceId,
      title: title,
      notificationBody: notificationBody,
      spokenMessage: spokenMessage,
      scheduledTime: scheduledTime,
      enabled: enabled,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numericId': numericId,
      'eventType': eventType.name,
      'sourceType': sourceType.name,
      'sourceId': sourceId,
      'title': title,
      'notificationBody': notificationBody,
      'spokenMessage': spokenMessage,
      'scheduledTime': scheduledTime.toIso8601String(),
      'triggerAtMillis': scheduledTime.millisecondsSinceEpoch,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    final typeName = json['eventType'] as String? ?? 'activityStart';
    final sourceTypeName = json['sourceType'] as String? ?? 'schedule';

    final eventType = NotificationEventType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => NotificationEventType.activityStart,
    );

    final sourceType = NotificationSourceType.values.firstWhere(
      (e) => e.name == sourceTypeName,
      orElse: () => NotificationSourceType.schedule,
    );

    final schedTime = json['scheduledTime'] != null
        ? DateTime.parse(json['scheduledTime'] as String)
        : (json['triggerAtMillis'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['triggerAtMillis'] as num).toInt())
            : DateTime.now());

    final stringId = json['id'] as String? ?? 'evt_${json['numericId']}';
    final numId = json['numericId'] as int? ?? generateNumericId(stringId);

    return NotificationEvent(
      id: stringId,
      numericId: numId,
      eventType: eventType,
      sourceType: sourceType,
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? 'Timora Alert',
      notificationBody: json['notificationBody'] as String? ?? '',
      spokenMessage: json['spokenMessage'] as String? ?? '',
      scheduledTime: schedTime,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  NotificationEvent copyWith({
    String? id,
    int? numericId,
    NotificationEventType? eventType,
    NotificationSourceType? sourceType,
    String? sourceId,
    String? title,
    String? notificationBody,
    String? spokenMessage,
    DateTime? scheduledTime,
    bool? enabled,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationEvent(
      id: id ?? this.id,
      numericId: numericId ?? this.numericId,
      eventType: eventType ?? this.eventType,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      notificationBody: notificationBody ?? this.notificationBody,
      spokenMessage: spokenMessage ?? this.spokenMessage,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
