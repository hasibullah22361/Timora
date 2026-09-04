import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/diary_entry_model.dart';

class MoodTrendSummary {
  final double averageMood;
  final double averageEnergy;
  final int totalEntries;
  final List<DiaryEntryModel> recentEntries;

  MoodTrendSummary({
    required this.averageMood,
    required this.averageEnergy,
    required this.totalEntries,
    required this.recentEntries,
  });
}

class DiaryStreakStats {
  final int currentStreak;
  final int longestStreak;
  final int totalEntries;
  final int entriesThisWeek;
  final int entriesThisMonth;
  final double avgEntriesPerWeek;
  final double avgEntriesPerMonth;
  final String? mostUsedMood;
  final String? mostUsedActivity;
  final String? mostUsedTag;

  const DiaryStreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalEntries,
    required this.entriesThisWeek,
    required this.entriesThisMonth,
    required this.avgEntriesPerWeek,
    required this.avgEntriesPerMonth,
    this.mostUsedMood,
    this.mostUsedActivity,
    this.mostUsedTag,
  });

  static const empty = DiaryStreakStats(
    currentStreak: 0,
    longestStreak: 0,
    totalEntries: 0,
    entriesThisWeek: 0,
    entriesThisMonth: 0,
    avgEntriesPerWeek: 0.0,
    avgEntriesPerMonth: 0.0,
  );
}

class MoodAnalyticsResult {
  final int totalEntries;
  final double averageScore;
  final Map<String, int> moodCounts;
  final List<MapEntry<DateTime, double>> dailyScores;

  const MoodAnalyticsResult({
    required this.totalEntries,
    required this.averageScore,
    required this.moodCounts,
    required this.dailyScores,
  });

  static const empty = MoodAnalyticsResult(
    totalEntries: 0,
    averageScore: 0.0,
    moodCounts: {},
    dailyScores: [],
  );
}

class DiaryReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const DiaryReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const defaultSettings = DiaryReminderSettings(
    enabled: false,
    hour: 20,
    minute: 0,
  );
}

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return DiaryRepository(prefs, userId: currentUser?.id);
});

class DiaryRepository {
  static const String _defaultStorageKey = 'timora_diary_entries_data';
  static const String _defaultDraftKey = 'timora_diary_draft_v1';
  static const String _defaultReminderKey = 'timora_diary_reminder_settings_v1';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<DiaryEntryModel> _entries = [];

  DiaryRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_diary_${_userId}_data'
      : _defaultStorageKey;

  String get _draftKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_diary_draft_${_userId}_v1'
      : _defaultDraftKey;

  String get _reminderKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_diary_reminder_${_userId}_v1'
      : _defaultReminderKey;

  void _loadFromStorage() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _entries.clear();
        for (var item in decoded) {
          _entries.add(DiaryEntryModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, raw);
  }

  Future<List<DiaryEntryModel>> getAllEntries() async {
    final list = List<DiaryEntryModel>.from(_entries)
      ..sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  Future<DiaryEntryModel?> getEntryById(String id) async {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<DiaryEntryModel?> getEntryForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    try {
      return _entries.firstWhere(
        (e) => e.date.year == normalized.year &&
               e.date.month == normalized.month &&
               e.date.day == normalized.day,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<DiaryEntryModel>> getEntriesForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _entries.where(
      (e) => e.date.year == normalized.year &&
             e.date.month == normalized.month &&
             e.date.day == normalized.day,
    ).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<DiaryEntryModel>> getFavoriteEntries() async {
    return _entries.where((e) => e.isFavorite).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveEntry(DiaryEntryModel entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    final toSave = entry.copyWith(updatedAt: DateTime.now());

    if (index >= 0) {
      _entries[index] = toSave;
    } else {
      _entries.add(toSave);
    }

    await _saveToStorage();
  }

  Future<DiaryEntryModel?> toggleFavorite(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final updated = _entries[index].copyWith(
        isFavorite: !_entries[index].isFavorite,
        updatedAt: DateTime.now(),
      );
      _entries[index] = updated;
      await _saveToStorage();
      return updated;
    }
    return null;
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveToStorage();
  }

  Future<List<DiaryEntryModel>> searchEntries({
    String? query,
    String? moodKey,
    String? activity,
    String? tag,
    bool? isFavorite,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var filtered = List<DiaryEntryModel>.from(_entries);

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((e) {
        final inTitle = e.title.toLowerCase().contains(q);
        final inContent = e.content.toLowerCase().contains(q);
        final inTags = e.tags.any((t) => t.toLowerCase().contains(q));
        final inActivities = e.activities.any((a) => a.toLowerCase().contains(q));
        final inGratitude = e.gratitudeList.any((g) => g.toLowerCase().contains(q));
        final inHighlights = e.highlights.any((h) => h.toLowerCase().contains(q));
        return inTitle || inContent || inTags || inActivities || inGratitude || inHighlights;
      }).toList();
    }

    if (moodKey != null && moodKey.isNotEmpty) {
      filtered = filtered.where((e) => e.moodKey?.toLowerCase() == moodKey.toLowerCase()).toList();
    }

    if (activity != null && activity.isNotEmpty) {
      filtered = filtered.where((e) => e.activities.any((a) => a.toLowerCase() == activity.toLowerCase())).toList();
    }

    if (tag != null && tag.isNotEmpty) {
      final cleanTag = tag.replaceAll('#', '').toLowerCase();
      filtered = filtered.where((e) => e.tags.any((t) => t.replaceAll('#', '').toLowerCase() == cleanTag)).toList();
    }

    if (isFavorite == true) {
      filtered = filtered.where((e) => e.isFavorite).toList();
    }

    if (startDate != null) {
      final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
      filtered = filtered.where((e) => e.date.isAfter(startNorm) || e.date.isAtSameMomentAs(startNorm)).toList();
    }

    if (endDate != null) {
      final endNorm = DateTime(endDate.year, endDate.month, endDate.day);
      filtered = filtered.where((e) => e.date.isBefore(endNorm) || e.date.isAtSameMomentAs(endNorm)).toList();
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<DiaryStreakStats> getStreakStats() async {
    if (_entries.isEmpty) {
      return DiaryStreakStats.empty;
    }

    final uniqueDates = _entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int currentStreak = 0;
    if (uniqueDates.isNotEmpty) {
      if (uniqueDates.contains(today) || uniqueDates.contains(yesterday)) {
        var checkDate = uniqueDates.contains(today) ? today : yesterday;
        while (uniqueDates.contains(checkDate)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }
    }

    // Longest streak
    int longestStreak = 0;
    if (uniqueDates.isNotEmpty) {
      final ascDates = List<DateTime>.from(uniqueDates)..sort((a, b) => a.compareTo(b));
      int tempStreak = 1;
      longestStreak = 1;
      for (int i = 1; i < ascDates.length; i++) {
        final diff = ascDates[i].difference(ascDates[i - 1]).inDays;
        if (diff == 1) {
          tempStreak++;
          if (tempStreak > longestStreak) longestStreak = tempStreak;
        } else if (diff > 1) {
          tempStreak = 1;
        }
      }
    }

    // Weekly and Monthly metrics
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    final thisWeekEntries = _entries.where((e) => e.date.isAfter(weekAgo) || e.date.isAtSameMomentAs(weekAgo)).length;
    final thisMonthEntries = _entries.where((e) => e.date.isAfter(monthAgo) || e.date.isAtSameMomentAs(monthAgo)).length;

    // Averages
    final oldestDate = uniqueDates.last;
    final daysSinceFirst = today.difference(oldestDate).inDays + 1;
    final weeks = (daysSinceFirst / 7.0).clamp(1.0, 9999.0);
    final months = (daysSinceFirst / 30.0).clamp(1.0, 9999.0);
    final avgPerWeek = (_entries.length / weeks);
    final avgPerMonth = (_entries.length / months);

    // Most used mood, activity, tag
    final moodFrequency = <String, int>{};
    final activityFrequency = <String, int>{};
    final tagFrequency = <String, int>{};

    for (var e in _entries) {
      final mKey = e.moodKey ?? e.moodLabel;
      moodFrequency[mKey] = (moodFrequency[mKey] ?? 0) + 1;

      for (var act in e.activities) {
        if (act.trim().isNotEmpty) {
          activityFrequency[act] = (activityFrequency[act] ?? 0) + 1;
        }
      }
      for (var t in e.tags) {
        if (t.trim().isNotEmpty) {
          tagFrequency[t] = (tagFrequency[t] ?? 0) + 1;
        }
      }
    }

    String? topMood;
    int topMoodCount = 0;
    moodFrequency.forEach((k, v) {
      if (v > topMoodCount) {
        topMoodCount = v;
        topMood = k;
      }
    });

    String? topActivity;
    int topActCount = 0;
    activityFrequency.forEach((k, v) {
      if (v > topActCount) {
        topActCount = v;
        topActivity = k;
      }
    });

    String? topTag;
    int topTagCount = 0;
    tagFrequency.forEach((k, v) {
      if (v > topTagCount) {
        topTagCount = v;
        topTag = k;
      }
    });

    return DiaryStreakStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalEntries: _entries.length,
      entriesThisWeek: thisWeekEntries,
      entriesThisMonth: thisMonthEntries,
      avgEntriesPerWeek: double.parse(avgPerWeek.toStringAsFixed(1)),
      avgEntriesPerMonth: double.parse(avgPerMonth.toStringAsFixed(1)),
      mostUsedMood: topMood,
      mostUsedActivity: topActivity,
      mostUsedTag: topTag,
    );
  }

  Future<MoodAnalyticsResult> getMoodAnalytics(int days) async {
    if (_entries.isEmpty) {
      return MoodAnalyticsResult.empty;
    }

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final recent = _entries.where((e) => e.date.isAfter(cutoff) || e.date.isAtSameMomentAs(cutoff)).toList();
    if (recent.isEmpty) {
      return MoodAnalyticsResult.empty;
    }

    final moodCounts = <String, int>{};
    double totalScore = 0;
    final dailyScoresMap = <DateTime, List<int>>{};

    for (var e in recent) {
      final mKey = e.moodKey ?? e.moodLabel;
      moodCounts[mKey] = (moodCounts[mKey] ?? 0) + 1;
      totalScore += e.mood;

      final normDate = DateTime(e.date.year, e.date.month, e.date.day);
      dailyScoresMap.putIfAbsent(normDate, () => []).add(e.mood);
    }

    final dailyScores = dailyScoresMap.entries.map((entry) {
      final avg = entry.value.fold<int>(0, (a, b) => a + b) / entry.value.length;
      return MapEntry(entry.key, avg);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return MoodAnalyticsResult(
      totalEntries: recent.length,
      averageScore: double.parse((totalScore / recent.length).toStringAsFixed(1)),
      moodCounts: moodCounts,
      dailyScores: dailyScores,
    );
  }

  Future<List<MapEntry<String, int>>> getActivityAnalytics() async {
    final counts = <String, int>{};
    for (var e in _entries) {
      for (var act in e.activities) {
        if (act.trim().isNotEmpty) {
          counts[act] = (counts[act] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  Future<List<DiaryEntryModel>> getOnThisDayEntries(DateTime date) async {
    return _entries.where((e) {
      final isSameMonthDay = e.date.month == date.month && e.date.day == date.day;
      final isPastYear = e.date.year < date.year;
      return isSameMonthDay && isPastYear;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<MoodTrendSummary> getMoodTrends(int days) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final recent = _entries.where((e) => e.date.isAfter(cutoff) || e.date.isAtSameMomentAs(cutoff)).toList();
    if (recent.isEmpty) {
      return MoodTrendSummary(
        averageMood: 0.0,
        averageEnergy: 0.0,
        totalEntries: 0,
        recentEntries: [],
      );
    }

    final avgMood = recent.fold<int>(0, (sum, e) => sum + e.mood) / recent.length;
    final avgEnergy = recent.fold<int>(0, (sum, e) => sum + e.energyLevel) / recent.length;

    return MoodTrendSummary(
      averageMood: double.parse(avgMood.toStringAsFixed(1)),
      averageEnergy: double.parse(avgEnergy.toStringAsFixed(1)),
      totalEntries: recent.length,
      recentEntries: recent,
    );
  }

  Future<void> saveDraft(Map<String, dynamic> draftData) async {
    await _prefs.setString(_draftKey, jsonEncode(draftData));
  }

  Map<String, dynamic>? getDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<void> clearDraft() async {
    await _prefs.remove(_draftKey);
  }

  DiaryReminderSettings getReminderSettings() {
    final raw = _prefs.getString(_reminderKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return DiaryReminderSettings(
          enabled: decoded['enabled'] as bool? ?? false,
          hour: decoded['hour'] as int? ?? 20,
          minute: decoded['minute'] as int? ?? 0,
        );
      } catch (_) {}
    }
    return DiaryReminderSettings.defaultSettings;
  }

  Future<void> saveReminderSettings(bool enabled, int hour, int minute) async {
    final data = {
      'enabled': enabled,
      'hour': hour,
      'minute': minute,
    };
    await _prefs.setString(_reminderKey, jsonEncode(data));
  }
}
