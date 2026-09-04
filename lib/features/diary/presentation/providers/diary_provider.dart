import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/repositories/diary_repository.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';
import '../../../notifications/application/notification_service.dart';

final selectedDiaryDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final allDiaryEntriesProvider = FutureProvider<List<DiaryEntryModel>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getAllEntries();
});

final favoriteDiaryEntriesProvider = FutureProvider<List<DiaryEntryModel>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getFavoriteEntries();
});

final diaryEntriesForDateProvider = FutureProvider.family<List<DiaryEntryModel>, DateTime>((ref, date) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getEntriesForDate(date);
});

final diaryEntryForDateProvider = FutureProvider.family<DiaryEntryModel?, DateTime>((ref, date) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getEntryForDate(date);
});

final diaryEntryForSelectedDateProvider = FutureProvider<DiaryEntryModel?>((ref) async {
  final selectedDate = ref.watch(selectedDiaryDateProvider);
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getEntryForDate(selectedDate);
});

final diaryStreakStatsProvider = FutureProvider<DiaryStreakStats>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getStreakStats();
});

final moodAnalyticsProvider = FutureProvider.family<MoodAnalyticsResult, int>((ref, days) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getMoodAnalytics(days);
});

final activityAnalyticsProvider = FutureProvider<List<MapEntry<String, int>>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getActivityAnalytics();
});

final onThisDayEntriesProvider = FutureProvider<List<DiaryEntryModel>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getOnThisDayEntries(DateTime.now());
});

final moodTrendsProvider = FutureProvider.family<MoodTrendSummary, int>((ref, days) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getMoodTrends(days);
});

// Search & Filter State Providers
final diarySearchQueryProvider = StateProvider<String>((ref) => '');
final diaryFilterMoodProvider = StateProvider<String?>((ref) => null);
final diaryFilterActivityProvider = StateProvider<String?>((ref) => null);
final diaryFilterTagProvider = StateProvider<String?>((ref) => null);
final diaryFilterFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
final diaryFilterStartDateProvider = StateProvider<DateTime?>((ref) => null);
final diaryFilterEndDateProvider = StateProvider<DateTime?>((ref) => null);

final filteredDiaryEntriesProvider = FutureProvider<List<DiaryEntryModel>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  final query = ref.watch(diarySearchQueryProvider);
  final mood = ref.watch(diaryFilterMoodProvider);
  final activity = ref.watch(diaryFilterActivityProvider);
  final tag = ref.watch(diaryFilterTagProvider);
  final favOnly = ref.watch(diaryFilterFavoritesOnlyProvider);
  final start = ref.watch(diaryFilterStartDateProvider);
  final end = ref.watch(diaryFilterEndDateProvider);

  return repo.searchEntries(
    query: query,
    moodKey: mood,
    activity: activity,
    tag: tag,
    isFavorite: favOnly ? true : null,
    startDate: start,
    endDate: end,
  );
});

final diaryReminderSettingsProvider = Provider<DiaryReminderSettings>((ref) {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getReminderSettings();
});

class DiaryNotifier extends StateNotifier<AsyncValue<void>> {
  final DiaryRepository _repo;
  final Ref _ref;

  DiaryNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  void _notifyRelated(DateTime date) {
    _ref.invalidate(allDiaryEntriesProvider);
    _ref.invalidate(favoriteDiaryEntriesProvider);
    _ref.invalidate(diaryEntriesForDateProvider(date));
    _ref.invalidate(diaryEntryForDateProvider(date));
    _ref.invalidate(diaryEntryForSelectedDateProvider);
    _ref.invalidate(diaryStreakStatsProvider);
    _ref.invalidate(moodAnalyticsProvider);
    _ref.invalidate(activityAnalyticsProvider);
    _ref.invalidate(onThisDayEntriesProvider);
    _ref.invalidate(moodTrendsProvider);
    _ref.invalidate(filteredDiaryEntriesProvider);
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> saveEntry(DiaryEntryModel entry) async {
    await _repo.saveEntry(entry);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'diary_entries',
      entityId: entry.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(entry.date);
  }

  Future<void> toggleFavorite(String id) async {
    final updated = await _repo.toggleFavorite(id);
    if (updated != null) {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'diary_entries',
        entityId: id,
        operation: SyncOperation.update,
      );
      _notifyRelated(updated.date);
    }
  }

  Future<void> deleteEntry(String id, DateTime date) async {
    await _repo.deleteEntry(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'diary_entries',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(date);
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    await _repo.saveDraft(draft);
  }

  Map<String, dynamic>? getDraft() {
    return _repo.getDraft();
  }

  Future<void> clearDraft() async {
    await _repo.clearDraft();
  }

  Future<void> scheduleDiaryReminder(bool enabled, int hour, int minute) async {
    await _repo.saveReminderSettings(enabled, hour, minute);
    final notif = _ref.read(notificationServiceProvider);
    const int reminderId = 987654;

    if (!enabled) {
      await notif.cancelNotification(reminderId);
    } else {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await notif.scheduleNotification(
        reminderId,
        'Time to Reflect & Journal',
        'How was your day? Take a moment to capture your thoughts and wins in your Timora Diary.',
        scheduled,
        channelId: 'timora_daily',
      );
    }
    _ref.invalidate(diaryReminderSettingsProvider);
  }

  Future<void> generateAiReflection(DiaryEntryModel entry) async {
    String reflection = '';
    if (entry.mood >= 4) {
      reflection = '🌟 Outstanding momentum! You logged high energy and meaningful wins today. Consider identifying what specific habits contributed most to your positive state so you can replicate them tomorrow.';
    } else if (entry.mood <= 2) {
      reflection = '💙 Today presented some headwinds. Remember that recovery and rest are active parts of sustainable productivity. Prioritize an early wind-down and celebrate your gratitude points.';
    } else {
      reflection = '⚖️ A steady, balanced day. Consistency across routine blocks and small daily habits compounds rapidly over time.';
    }

    final updated = entry.copyWith(aiReflection: reflection);
    await saveEntry(updated);
  }
}

final diaryNotifierProvider = StateNotifierProvider<DiaryNotifier, AsyncValue<void>>((ref) {
  return DiaryNotifier(ref.watch(diaryRepositoryProvider), ref);
});
