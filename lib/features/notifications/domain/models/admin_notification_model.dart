import 'dart:convert';

class AdminNotificationModel {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final String targetAudience;
  final List<String> targetUserIds;
  final DateTime scheduledAt;
  final DateTime? sentAt;
  final String status;
  final String priority;
  final String? deepLink;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.notificationType = 'broadcast',
    this.targetAudience = 'all',
    this.targetUserIds = const [],
    required this.scheduledAt,
    this.sentAt,
    this.status = 'sent',
    this.priority = 'normal',
    this.deepLink,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool isEligibleForUser(String? userId, [String? userEmail]) {
    final s = status.toLowerCase().trim();
    if (s.isNotEmpty && s != 'sent') return false;

    final aud = targetAudience.toLowerCase().trim();
    if (aud == 'all' ||
        aud == 'broadcast' ||
        aud == 'everyone' ||
        aud.isEmpty) {
      return true;
    }

    final normalizedUserIds =
        targetUserIds.map((e) => e.toLowerCase().trim()).toSet();
    if (userId != null && userId.trim().isNotEmpty) {
      if (normalizedUserIds.contains(userId.toLowerCase().trim())) {
        return true;
      }
    }

    if (userEmail != null && userEmail.trim().isNotEmpty) {
      if (normalizedUserIds.contains(userEmail.toLowerCase().trim())) {
        return true;
      }
    }

    return false;
  }

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    List<String> userIds = [];
    final rawTargetIds = json['target_user_ids'];
    if (rawTargetIds != null) {
      if (rawTargetIds is List) {
        userIds = rawTargetIds
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (rawTargetIds is String) {
        final str = rawTargetIds.trim();
        if (str.startsWith('[') && str.endsWith(']')) {
          try {
            final decoded = jsonDecode(str);
            if (decoded is List) {
              userIds = decoded
                  .map((e) => e.toString().trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } catch (_) {}
        } else if (str.startsWith('{') && str.endsWith('}')) {
          final inner = str.substring(1, str.length - 1);
          if (inner.isNotEmpty) {
            userIds = inner
                .split(',')
                .map((e) => e.replaceAll('"', '').trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } else if (str.isNotEmpty) {
          userIds = str
              .split(',')
              .map((e) => e.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    }

    return AdminNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'broadcast',
      targetAudience: json['target_audience']?.toString() ?? 'all',
      targetUserIds: userIds,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'].toString())
          : null,
      status: json['status']?.toString() ?? 'sent',
      priority: json['priority']?.toString() ?? 'normal',
      deepLink: json['deep_link']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : (json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'])
              : const {}),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'target_audience': targetAudience,
      'target_user_ids': targetUserIds,
      'scheduled_at': scheduledAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'status': status,
      'priority': priority,
      'deep_link': deepLink,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
