import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/main.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/schedule/data/activity_library.dart';
import 'package:timora/features/schedule/data/models/activity_definition.dart';
import 'package:timora/features/schedule/data/repositories/custom_activity_repository.dart';
import 'package:timora/features/profile/data/repositories/user_profile_repository.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Activity Library contains 50+ activities across all categories', () {
    final activities = ActivityLibrary.defaultActivities;
    expect(activities.length, greaterThanOrEqualTo(50));

    // Verify categories exist
    final categories = activities.map((a) => a.categoryGroup).toSet();
    expect(categories.contains(ActivityCategoryGroup.healthFitness), isTrue);
    expect(categories.contains(ActivityCategoryGroup.foodDrink), isTrue);
    expect(categories.contains(ActivityCategoryGroup.workStudy), isTrue);
    expect(categories.contains(ActivityCategoryGroup.productivity), isTrue);
    expect(categories.contains(ActivityCategoryGroup.lifeHome), isTrue);
    expect(categories.contains(ActivityCategoryGroup.restWellbeing), isTrue);
    expect(categories.contains(ActivityCategoryGroup.spiritualPersonal), isTrue);
  });

  test('UserProfileRepository saves and loads profile correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = UserProfileRepository(prefs);

    final defaultProfile = repo.loadProfile();
    expect(defaultProfile.fullName.isNotEmpty, isTrue);

    final updated = defaultProfile.copyWith(
      fullName: 'Hasib Ullah Test',
      username: 'hasibt',
      dailyGoalHours: 8.0,
      bio: 'New bio test',
      customImagePath: '/data/user/0/com.example.timora/app_flutter/avatar.jpg',
    );
    await repo.saveProfile(updated);

    final loaded = repo.loadProfile();
    expect(loaded.fullName, 'Hasib Ullah Test');
    expect(loaded.username, 'hasibt');
    expect(loaded.dailyGoalHours, 8.0);
    expect(loaded.bio, 'New bio test');
    expect(loaded.hasCustomImage, isTrue);
    expect(loaded.customImagePath, '/data/user/0/com.example.timora/app_flutter/avatar.jpg');
  });

  test('VoiceAnnouncementService builds dynamic speech phrases correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = NotificationSettingsRepository(prefs);
    final voiceService = VoiceAnnouncementService(repo);

    expect(voiceService.buildAnnouncementPhrase('Breakfast'), 'Your breakfast time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Gym'), 'Your gym time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Work'), 'Your work time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Prayer'), 'Your prayer time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Study'), 'Your study time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Meeting'), 'Your meeting time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Deep Work'), 'Your deep work time starts now.');
    expect(voiceService.buildAnnouncementPhrase('Focus Time'), 'Your focus time starts now.');
  });

  test('NotificationSettingsRepository manages voice announcement toggle', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = NotificationSettingsRepository(prefs);

    expect(repo.spokenAnnouncementsEnabled, isTrue);
    await repo.setSpokenAnnouncementsEnabled(false);
    expect(repo.spokenAnnouncementsEnabled, isFalse);
  });

  test('CustomActivityRepository tracks custom activities and favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = CustomActivityRepository(prefs);

    const custom = ActivityDefinition(
      id: 'custom_test_1',
      name: 'Violin Practice',
      category: 'Music',
      categoryGroup: ActivityCategoryGroup.restWellbeing,
      icon: '🎻',
      isCustom: true,
    );

    await repo.saveCustomActivities([custom]);
    final list = repo.getCustomActivities();
    expect(list.length, 1);
    expect(list.first.name, 'Violin Practice');

    await repo.setFavorite('custom_test_1', true);
    expect(repo.getFavoriteIds().contains('custom_test_1'), isTrue);
  });

  testWidgets('Timora App Smoke Test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationSettingsRepositoryProvider.overrideWithValue(
            NotificationSettingsRepository(prefs),
          ),
        ],
        child: const TimoraApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(TimoraApp), findsOneWidget);
  });
}

