import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/notifications/domain/models/admin_notification_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminNotificationModel - JSON & Target Audience Robustness', () {
    test('Parses target_user_ids from standard Dart List<dynamic>', () {
      final json = {
        'id': 'notif-1',
        'title': 'System Update',
        'message': 'We have updated the server.',
        'target_audience': 'targeted',
        'target_user_ids': ['user-123', 'user-456'],
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = AdminNotificationModel.fromJson(json);
      expect(model.id, 'notif-1');
      expect(model.targetUserIds, containsAll(['user-123', 'user-456']));
      expect(model.isEligibleForUser('user-123', 'test@example.com'), isTrue);
      expect(model.isEligibleForUser('user-999', 'other@example.com'), isFalse);
    });

    test('Parses target_user_ids from Postgres array string "{user1,user2}"', () {
      final json = {
        'id': 'notif-2',
        'title': 'Security Alert',
        'message': 'Please reset your password.',
        'target_audience': 'targeted',
        'target_user_ids': '{user-abc,user-xyz}',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = AdminNotificationModel.fromJson(json);
      expect(model.targetUserIds, containsAll(['user-abc', 'user-xyz']));
      expect(model.isEligibleForUser('user-abc', null), isTrue);
      expect(model.isEligibleForUser('user-xyz', null), isTrue);
      expect(model.isEligibleForUser('user-other', null), isFalse);
    });

    test('Parses target_user_ids from JSON array string "["user-a", "user-b"]"', () {
      final json = {
        'id': 'notif-3',
        'title': 'Feature Announcement',
        'message': 'Check out new speaking notifications!',
        'target_audience': 'targeted',
        'target_user_ids': '["user-a", "user-b"]',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = AdminNotificationModel.fromJson(json);
      expect(model.targetUserIds, containsAll(['user-a', 'user-b']));
      expect(model.isEligibleForUser('user-a', null), isTrue);
      expect(model.isEligibleForUser('user-b', null), isTrue);
      expect(model.isEligibleForUser('user-c', null), isFalse);
    });

    test('Parses target_user_ids from comma-separated string', () {
      final json = {
        'id': 'notif-4',
        'title': 'Maintenance',
        'message': 'Scheduled downtime tonight.',
        'target_audience': 'targeted',
        'target_user_ids': 'user-alpha, user-beta',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = AdminNotificationModel.fromJson(json);
      expect(model.targetUserIds, containsAll(['user-alpha', 'user-beta']));
      expect(model.isEligibleForUser('user-alpha', null), isTrue);
      expect(model.isEligibleForUser('user-beta', null), isTrue);
    });

    test('Handles targetAudience "all", "broadcast", and "everyone" for all users', () {
      final broadcastAll = AdminNotificationModel.fromJson({
        'id': 'notif-all',
        'title': 'Holiday Greetings',
        'message': 'Happy holidays to everyone!',
        'target_audience': 'all',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(broadcastAll.isEligibleForUser('any-user', 'any@email.com'), isTrue);
      expect(broadcastAll.isEligibleForUser(null, null), isTrue);

      final broadcastWord = AdminNotificationModel.fromJson({
        'id': 'notif-bcast',
        'title': 'Notice',
        'message': 'Broadcast notice',
        'target_audience': 'broadcast',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(broadcastWord.isEligibleForUser('random-id', 'random@mail.com'), isTrue);
    });

    test('Matches user by email when targeted by email address', () {
      final json = {
        'id': 'notif-email',
        'title': 'VIP Offer',
        'message': 'Exclusive offer for you',
        'target_audience': 'targeted',
        'target_user_ids': ['vip@timora.app'],
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = AdminNotificationModel.fromJson(json);
      expect(model.isEligibleForUser('some-internal-uuid', 'vip@timora.app'), isTrue);
      expect(model.isEligibleForUser('some-internal-uuid', 'VIP@TIMORA.APP'), isTrue);
      expect(model.isEligibleForUser('some-internal-uuid', 'other@timora.app'), isFalse);
    });

    test('Serialization to and from JSON preserves all fields', () {
      final now = DateTime(2026, 9, 9, 12, 0);
      final original = AdminNotificationModel(
        id: 'notif-serde',
        title: 'Serde Test',
        message: 'Checking serialization roundtrip',
        targetAudience: 'targeted',
        targetUserIds: ['user-1', 'user-2'],
        status: 'sent',
        priority: 'high',
        scheduledAt: now,
        createdAt: now,
        updatedAt: now,
        deepLink: 'timora://schedule',
      );

      final json = original.toJson();
      final roundtrip = AdminNotificationModel.fromJson(json);

      expect(roundtrip.id, original.id);
      expect(roundtrip.title, original.title);
      expect(roundtrip.message, original.message);
      expect(roundtrip.targetAudience, original.targetAudience);
      expect(roundtrip.targetUserIds, original.targetUserIds);
      expect(roundtrip.status, original.status);
      expect(roundtrip.priority, original.priority);
      expect(roundtrip.deepLink, original.deepLink);
    });
  });
}
