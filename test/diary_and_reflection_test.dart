import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/diary/data/models/diary_entry_model.dart';
import 'package:timora/features/diary/data/repositories/diary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DiaryRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = DiaryRepository(prefs, userId: 'test_user_diary');
  });

  group('Diary & Journal System Tests', () {
    test('DIARY-1: Model serialization, 15 rich moods, activities, and fallback titles', () {
      final now = DateTime(2026, 8, 28, 20, 0);
      final entry = DiaryEntryModel(
        id: 'entry_test_1',
        date: DateTime(2026, 8, 28),
        title: 'Calm & Productive Friday',
        content: 'Completed all high-priority development sprints today.',
        moodKey: 'calm',
        mood: 4,
        energyLevel: 4,
        activities: ['Work', 'Study', 'Reading'],
        tags: ['Productivity', 'Flow'],
        photoPaths: ['/storage/emulated/0/Pictures/test.jpg'],
        isFavorite: true,
        gratitudeList: ['Coffee', 'Deep Focus', 'Supportive Team'],
        highlights: ['Shipped Diary upgrade on schedule'],
        aiReflection: 'Keep up the strong execution rhythm.',
        createdAt: now,
      );

      expect(entry.moodEmoji, '😌');
      expect(entry.moodLabel, 'Calm');
      expect(entry.effectiveTitle, 'Calm & Productive Friday');
      expect(entry.isFavorite, isTrue);
      expect(entry.photoPaths.length, 1);

      // Fallback title test
      final blankTitleEntry = DiaryEntryModel(
        id: 'entry_blank',
        date: DateTime(2026, 8, 29),
        createdAt: now,
      );
      expect(blankTitleEntry.effectiveTitle, 'Diary — August 29, 2026');

      final json = entry.toJson();
      final reconstituted = DiaryEntryModel.fromJson(json);

      expect(reconstituted.id, 'entry_test_1');
      expect(reconstituted.title, 'Calm & Productive Friday');
      expect(reconstituted.moodKey, 'calm');
      expect(reconstituted.mood, 4);
      expect(reconstituted.activities, containsAll(['Work', 'Study', 'Reading']));
      expect(reconstituted.photoPaths.first, '/storage/emulated/0/Pictures/test.jpg');
      expect(reconstituted.isFavorite, isTrue);

      final supabaseMap = entry.toSupabaseMap('user_xyz');
      expect(supabaseMap['user_id'], 'user_xyz');
      expect(supabaseMap['mood'], 'calm');

      final fromSupabase = DiaryEntryModel.fromSupabaseMap(supabaseMap);
      expect(fromSupabase.title, 'Calm & Productive Friday');
      expect(fromSupabase.moodKey, 'calm');
    });

    test('DIARY-2: Repository saving, updating, favorite toggling, and date retrieval', () async {
      final today = DateTime(2026, 8, 28);
      final entry = DiaryEntryModel(
        id: 'entry_today',
        date: today,
        title: 'Morning Plan',
        content: 'Drafting requirements.',
        moodKey: 'good',
        mood: 4,
        energyLevel: 3,
        activities: ['Work'],
        tags: ['Planning'],
        createdAt: DateTime.now(),
      );

      await repo.saveEntry(entry);
      final retrieved = await repo.getEntryForDate(today);

      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Morning Plan');
      expect(retrieved.moodKey, 'good');
      expect(retrieved.isFavorite, isFalse);

      // Toggle favorite
      final favToggled = await repo.toggleFavorite('entry_today');
      expect(favToggled!.isFavorite, isTrue);

      final favs = await repo.getFavoriteEntries();
      expect(favs.length, 1);
      expect(favs.first.id, 'entry_today');

      // Update entry
      final updated = retrieved.copyWith(
        title: 'Evening Wrap-Up',
        moodKey: 'happy',
        gratitudeList: ['Good health', 'Clean code'],
      );
      await repo.saveEntry(updated);

      final afterUpdate = await repo.getEntryForDate(today);
      expect(afterUpdate!.title, 'Evening Wrap-Up');
      expect(afterUpdate.moodKey, 'happy');
      expect(afterUpdate.gratitudeList.length, 2);

      // Delete entry
      await repo.deleteEntry('entry_today');
      final afterDelete = await repo.getEntryForDate(today);
      expect(afterDelete, isNull);
    });

    test('DIARY-3: Multi-criteria search and filter', () async {
      final today = DateTime(2026, 8, 28);
      await repo.saveEntry(DiaryEntryModel(
        id: 'e1',
        date: today,
        title: 'Mountain Hike',
        content: 'Breathtaking view from the summit.',
        moodKey: 'excited',
        mood: 5,
        activities: ['Travel', 'Walking'],
        tags: ['Nature', 'Weekend'],
        createdAt: today,
      ));
      await repo.saveEntry(DiaryEntryModel(
        id: 'e2',
        date: today.subtract(const Duration(days: 1)),
        title: 'Work Sprint',
        content: 'Coding Flutter user interface.',
        moodKey: 'thoughtful',
        mood: 3,
        activities: ['Work'],
        tags: ['Code', 'Productivity'],
        createdAt: today,
      ));

      // Search by text query
      final searchResult = await repo.searchEntries(query: 'summit');
      expect(searchResult.length, 1);
      expect(searchResult.first.id, 'e1');

      // Filter by mood
      final moodFilter = await repo.searchEntries(moodKey: 'thoughtful');
      expect(moodFilter.length, 1);
      expect(moodFilter.first.id, 'e2');

      // Filter by activity
      final actFilter = await repo.searchEntries(activity: 'Travel');
      expect(actFilter.length, 1);
      expect(actFilter.first.id, 'e1');

      // Filter by tag
      final tagFilter = await repo.searchEntries(tag: '#Code');
      expect(tagFilter.length, 1);
      expect(tagFilter.first.id, 'e2');
    });

    test('DIARY-4: Real streak and statistics calculation (0 for empty)', () async {
      // Empty repo check
      final emptyStats = await repo.getStreakStats();
      expect(emptyStats.currentStreak, 0);
      expect(emptyStats.longestStreak, 0);
      expect(emptyStats.totalEntries, 0);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Save entries for 3 consecutive days up to today
      await repo.saveEntry(DiaryEntryModel(
        id: 's1',
        date: today.subtract(const Duration(days: 2)),
        moodKey: 'good',
        mood: 4,
        activities: ['Gym'],
        tags: ['Fitness'],
        createdAt: today,
      ));
      await repo.saveEntry(DiaryEntryModel(
        id: 's2',
        date: today.subtract(const Duration(days: 1)),
        moodKey: 'good',
        mood: 4,
        activities: ['Gym', 'Work'],
        tags: ['Fitness'],
        createdAt: today,
      ));
      await repo.saveEntry(DiaryEntryModel(
        id: 's3',
        date: today,
        moodKey: 'excited',
        mood: 5,
        activities: ['Reading'],
        tags: ['Book'],
        createdAt: today,
      ));

      final stats = await repo.getStreakStats();
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
      expect(stats.totalEntries, 3);
      expect(stats.mostUsedActivity, 'Gym');
      expect(stats.mostUsedTag, 'Fitness');
    });

    test('DIARY-5: Mood and activity analytics with real calculations', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await repo.saveEntry(DiaryEntryModel(
        id: 'm1',
        date: today.subtract(const Duration(days: 1)),
        moodKey: 'happy',
        mood: 4,
        activities: ['Work'],
        createdAt: today,
      ));
      await repo.saveEntry(DiaryEntryModel(
        id: 'm2',
        date: today,
        moodKey: 'excited',
        mood: 5,
        activities: ['Work', 'Gym'],
        createdAt: today,
      ));

      final moodAnalytics = await repo.getMoodAnalytics(7);
      expect(moodAnalytics.totalEntries, 2);
      expect(moodAnalytics.averageScore, 4.5);
      expect(moodAnalytics.moodCounts['happy'], 1);
      expect(moodAnalytics.moodCounts['excited'], 1);

      final activityAnalytics = await repo.getActivityAnalytics();
      expect(activityAnalytics.first.key, 'Work');
      expect(activityAnalytics.first.value, 2);
    });

    test('DIARY-6: User data isolation between accounts', () async {
      final today = DateTime(2026, 8, 28);

      // User A creates entry
      await repo.saveEntry(DiaryEntryModel(
        id: 'user_a_entry',
        date: today,
        title: 'User A Secret Journal',
        content: 'Private thoughts of user A',
        createdAt: today,
      ));

      expect((await repo.getAllEntries()).length, 1);

      // User B logs in (different repo instance with userId 'test_user_b')
      final userBRepo = DiaryRepository(prefs, userId: 'test_user_b');
      final userBEntries = await userBRepo.getAllEntries();

      // User B must NOT see User A's entries
      expect(userBEntries, isEmpty);

      // User B saves their own entry
      await userBRepo.saveEntry(DiaryEntryModel(
        id: 'user_b_entry',
        date: today,
        title: 'User B Journal',
        content: 'Private thoughts of user B',
        createdAt: today,
      ));

      expect((await userBRepo.getAllEntries()).length, 1);
      expect((await userBRepo.getAllEntries()).first.id, 'user_b_entry');

      // User A still only sees User A's entry
      final userAEntries = await repo.getAllEntries();
      expect(userAEntries.length, 1);
      expect(userAEntries.first.id, 'user_a_entry');
    });

    test('DIARY-7: Auto-save draft and reminder settings persistence', () async {
      // Draft test
      await repo.saveDraft({
        'title': 'Draft Title',
        'content': 'Unfinished draft thoughts...',
      });

      final draft = repo.getDraft();
      expect(draft, isNotNull);
      expect(draft!['title'], 'Draft Title');
      expect(draft['content'], 'Unfinished draft thoughts...');

      await repo.clearDraft();
      expect(repo.getDraft(), isNull);

      // Reminder settings test
      await repo.saveReminderSettings(true, 21, 30);
      final reminder = repo.getReminderSettings();
      expect(reminder.enabled, isTrue);
      expect(reminder.hour, 21);
      expect(reminder.minute, 30);
    });
  });
}
