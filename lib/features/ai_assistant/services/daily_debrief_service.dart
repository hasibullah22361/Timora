import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/providers/mock_ai_provider.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../diary/data/models/diary_entry_model.dart';
import '../../diary/presentation/providers/diary_provider.dart';

class DailyDebriefResult {
  final String dateString;
  final String whatWentWell;
  final String whatToImprove;
  final String reflection;
  final String diaryEntryId;
  final int tasksCompletedToday;
  final int focusMinutesToday;
  final bool generatedWithAI;

  const DailyDebriefResult({
    required this.dateString,
    required this.whatWentWell,
    required this.whatToImprove,
    required this.reflection,
    required this.diaryEntryId,
    required this.tasksCompletedToday,
    required this.focusMinutesToday,
    required this.generatedWithAI,
  });
}

final dailyDebriefServiceProvider = Provider<DailyDebriefService>((ref) {
  return DailyDebriefService(ref);
});

class DailyDebriefService {
  final Ref _ref;
  final _uuid = const Uuid();

  DailyDebriefService(this._ref);

  /// Generates the Daily Reflection from user answers + real Timora metrics,
  /// and automatically persists it to Timora's existing Diary system.
  Future<DailyDebriefResult> processAndSaveDebrief({
    required String whatWentWell,
    required String whatToImprove,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateString = DateFormat('EEEE, MMMM d, y').format(now);

    final cleanWentWell = whatWentWell.trim().isEmpty ? 'Completed daily tasks.' : whatWentWell.trim();
    final cleanImprove = whatToImprove.trim().isEmpty ? 'Maintain consistent focus and routines.' : whatToImprove.trim();

    // 1. Gather today's real performance metrics
    int tasksCompleted = 0;
    int focusMinutes = 0;

    try {
      final taskRepo = _ref.read(taskRepositoryProvider);
      final tasks = await taskRepo.getTasks();
      tasksCompleted = tasks.where((t) {
        if (!t.isCompleted || t.completedAt == null) return false;
        return t.completedAt!.year == today.year &&
            t.completedAt!.month == today.month &&
            t.completedAt!.day == today.day;
      }).length;
    } catch (_) {}

    try {
      final focusSessions = await _ref.read(allFocusSessionsProvider.future);
      final todayFocus = focusSessions.where((s) {
        return s.startedAt.year == today.year &&
            s.startedAt.month == today.month &&
            s.startedAt.day == today.day &&
            s.status == FocusSessionStatus.completed;
      });
      focusMinutes = todayFocus.fold<int>(0, (sum, s) => sum + (s.actualDurationSeconds ~/ 60));
    } catch (_) {}

    // 2. Generate AI Reflection with strict anti-hallucination rules
    String reflection = '';
    bool generatedWithAI = false;

    try {
      final ai = _ref.read(aiProvider);
      final contextBuffer = StringBuffer();
      contextBuffer.writeln('Date: $dateString');
      contextBuffer.writeln('User Answer - What went well: "$cleanWentWell"');
      contextBuffer.writeln('User Answer - What to improve: "$cleanImprove"');
      contextBuffer.writeln('Timora Stats: $tasksCompleted tasks completed today, $focusMinutes focus minutes logged.');

      final prompt = '''
Task: Generate a concise, inspiring, 3-part nightly productivity reflection.
Rules:
1. Summarize what went well, directly reflecting the user's answer.
2. Acknowledge the identified challenge or area for improvement.
3. Provide exactly ONE practical, constructive adjustment for tomorrow that fits Timora's productivity mindset.
4. Keep the entire reflection to 3 crisp sentences.
5. NEVER contradict the user's answers or invent facts not stated.
''';

      final response = await ai.generateResponse(
        prompt: prompt,
        contextContext: contextBuffer.toString(),
        history: [],
      );

      final content = response.content.trim();
      if (content.isNotEmpty &&
          !content.toLowerCase().contains('unsupported') &&
          !content.toLowerCase().contains('error')) {
        reflection = content;
        generatedWithAI = true;
      }
    } catch (_) {
      // Offline fallback
    }

    // Fallback deterministic reflection if offline or AI call failed
    if (reflection.isEmpty) {
      reflection = _generateDeterministicReflection(
        wentWell: cleanWentWell,
        improve: cleanImprove,
        tasksCompleted: tasksCompleted,
        focusMinutes: focusMinutes,
      );
    }

    // 3. Automatically Save to existing Diary system
    final diaryNotifier = _ref.read(diaryNotifierProvider.notifier);
    final existingEntry = await _ref.read(diaryEntryForDateProvider(today).future);

    final entryId = existingEntry?.id ?? _uuid.v4();
    final formattedContent = '''
### 🌙 Daily Debrief

**What went well today:**
$cleanWentWell

**What would you improve tomorrow:**
$cleanImprove

**AI Reflection:**
$reflection
'''.trim();

    final diaryEntry = DiaryEntryModel(
      id: entryId,
      date: today,
      title: '🌙 Daily Debrief — ${DateFormat('MMMM d, y').format(today)}',
      content: formattedContent,
      mood: 4,
      energyLevel: 4,
      highlights: [cleanWentWell],
      gratitudeList: [cleanImprove],
      aiReflection: reflection,
      isEncrypted: false,
      createdAt: existingEntry?.createdAt ?? now,
      updatedAt: now,
    );

    await diaryNotifier.saveEntry(diaryEntry);
    debugPrint('[DailyDebrief] Saved reflection to Diary entry: $entryId');

    return DailyDebriefResult(
      dateString: dateString,
      whatWentWell: cleanWentWell,
      whatToImprove: cleanImprove,
      reflection: reflection,
      diaryEntryId: entryId,
      tasksCompletedToday: tasksCompleted,
      focusMinutesToday: focusMinutes,
      generatedWithAI: generatedWithAI,
    );
  }

  /// Deterministic local generation ensuring 100% offline functionality.
  String _generateDeterministicReflection({
    required String wentWell,
    required String improve,
    required int tasksCompleted,
    required int focusMinutes,
  }) {
    final buffer = StringBuffer();
    buffer.write('Today you achieved meaningful progress by focusing on "$wentWell". ');
    buffer.write('You noted that "$improve" was your primary friction point. ');
    buffer.write('Tomorrow, consider prioritizing your most demanding tasks during your peak energy window to protect your focus.');
    return buffer.toString();
  }
}
