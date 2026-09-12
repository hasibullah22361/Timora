import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/core/services/remote_config_service.dart';
import 'package:timora/features/settings/services/feature_flags_service.dart';
import 'package:timora/features/profile/data/models/user_profile.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Timora Admin Central Control & Realtime Management Tests', () {
    test('1. Remote App Configuration defaults and caching', () async {
      final service = RemoteConfigService(prefs);
      final defaultConfig = service.currentConfig;

      expect(defaultConfig.defaultTaskDurationMinutes, equals(45));
      expect(defaultConfig.defaultReminderOffsetMinutes, equals(10));
      expect(defaultConfig.maintenanceMode, isFalse);
      expect(defaultConfig.minSupportedVersion, equals('1.0.0'));
      expect(defaultConfig.syncIntervalSeconds, equals(60));

      // Test parsing from Supabase general_app_config map
      final parsed = RemoteAppConfig.fromMap({
        'default_task_duration_minutes': 50,
        'default_reminder_offset_minutes': 15,
        'maintenance_mode': true,
        'min_supported_version': '1.2.0',
        'sync_interval_seconds': 120,
      });

      expect(parsed.defaultTaskDurationMinutes, equals(50));
      expect(parsed.defaultReminderOffsetMinutes, equals(15));
      expect(parsed.maintenanceMode, isTrue);
      expect(parsed.minSupportedVersion, equals('1.2.0'));
      expect(parsed.syncIntervalSeconds, equals(120));

      service.dispose();
    });

    test('2. Feature Flags dynamic gating and real-time state', () async {
      final service = FeatureFlagsService(prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final initialState = container.read(featureFlagsProvider);
      expect(initialState.isSmartDailyPlannerEnabled, isTrue);
      expect(initialState.isAutopilotEnabled, isTrue);
      expect(initialState.isCareerRoadmapEnabled, isTrue);
      expect(initialState.isCareerDocumentVaultEnabled, isTrue);
      expect(initialState.isNaturalVoicePlanningEnabled, isTrue);
      expect(initialState.isRoutineConsistencyEnabled, isTrue);
      expect(initialState.isAiAssistantEnabled, isTrue);

      // Disable a feature dynamically (simulating CDC update from Admin panel)
      final toggledMap = Map<String, bool>.from(initialState.flags);
      toggledMap['career_roadmap'] = false;
      toggledMap['timora_autopilot'] = false;

      final updatedState = initialState.copyWith(flags: toggledMap);
      expect(updatedState.isCareerRoadmapEnabled, isFalse);
      expect(updatedState.isAutopilotEnabled, isFalse);
      // Other features remain enabled
      expect(updatedState.isCareerDocumentVaultEnabled, isTrue);
      expect(updatedState.isSmartDailyPlannerEnabled, isTrue);

      container.dispose();
    });

    test('3. UserProfile account suspension fields and serialization', () {
      final now = DateTime.now();
      final activeUser = UserProfile(
        id: 'test_user_1',
        fullName: 'Jane Doe',
        username: 'janedoe',
        email: 'jane@example.com',
        isSuspended: false,
        suspendedReason: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(activeUser.isSuspended, isFalse);
      expect(activeUser.suspendedReason, isNull);

      // Supabase map parsing with active account
      final supabaseMapActive = {
        'id': 'test_user_1',
        'display_name': 'Jane Doe',
        'email': 'jane@example.com',
        'is_suspended': false,
        'suspended_reason': null,
      };
      final fromActiveMap = UserProfile.fromSupabaseMap(supabaseMapActive);
      expect(fromActiveMap.isSuspended, isFalse);
      expect(fromActiveMap.suspendedReason, isNull);

      // Supabase map parsing with suspended account
      final supabaseMapSuspended = {
        'id': 'test_user_2',
        'display_name': 'Bad Actor',
        'email': 'bad@example.com',
        'is_suspended': true,
        'suspended_reason': 'Terms of service violation - excessive spam',
      };
      final fromSuspendedMap =
          UserProfile.fromSupabaseMap(supabaseMapSuspended);
      expect(fromSuspendedMap.isSuspended, isTrue);
      expect(fromSuspendedMap.suspendedReason,
          equals('Terms of service violation - excessive spam'));

      // JSON serialization roundtrip
      final json = fromSuspendedMap.toJson();
      expect(json['is_suspended'], isTrue);
      expect(json['suspended_reason'],
          equals('Terms of service violation - excessive spam'));

      final fromJson = UserProfile.fromJson(json);
      expect(fromJson.isSuspended, isTrue);
      expect(fromJson.suspendedReason,
          equals('Terms of service violation - excessive spam'));
    });

    test('4. RemoteConfigProvider exposes live reactive state in Riverpod',
        () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final config = container.read(remoteConfigProvider);
      expect(config.maintenanceMode, isFalse);
      expect(config.minSupportedVersion, equals('1.0.0'));

      container.dispose();
    });
  });
}
