import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import '../domain/models/voice_note_models.dart';
import 'ai_context_builder.dart';

final voiceNoteAIServiceProvider = Provider<VoiceNoteAIService>((ref) {
  return VoiceNoteAIService(ref);
});

/// Intelligent service to understand natural voice notes and extract
/// diary reflections and actionable tasks with real Timora context.
class VoiceNoteAIService {
  final Ref _ref;
  final _uuid = const Uuid();
  final Set<String> _processedSignatures = <String>{};
  static const String _processedSignaturesStorageKey = 'timora_processed_voice_note_signatures_v1';

  VoiceNoteAIService(this._ref);

  /// Checks if a voice note signature was already processed in this session or stored on device.
  bool isAlreadyProcessed(String signature) {
    if (_processedSignatures.contains(signature)) {
      return true;
    }
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final list = prefs.getStringList(_processedSignaturesStorageKey) ?? [];
      if (list.contains(signature)) {
        _processedSignatures.add(signature);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Marks a signature as processed to prevent duplicate processing.
  void markProcessed(String signature) {
    _processedSignatures.add(signature);
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final list = prefs.getStringList(_processedSignaturesStorageKey) ?? [];
      if (!list.contains(signature)) {
        final updated = [...list, signature];
        // Retain last 100 signatures to avoid unbounded storage growth
        if (updated.length > 100) {
          updated.removeRange(0, updated.length - 100);
        }
        prefs.setStringList(_processedSignaturesStorageKey, updated);
      }
    } catch (_) {}
  }

  /// Main entry point: Parses the transcribed voice note into Diary & Tasks.
  Future<VoiceNoteExtractionResult> processVoiceNote(
    String transcript, {
    DateTime? referenceDate,
  }) async {
    final clean = transcript.trim();
    if (clean.isEmpty) {
      return VoiceNoteExtractionResult(rawTranscript: transcript);
    }

    final now = referenceDate ?? DateTime.now();

    // 1. Retrieve real Timora user context (active projects, goals) if available
    List<String> knownProjectNames = [];
    Map<String, String> projectNameToId = {};
    List<String> knownGoalNames = [];
    Map<String, String> goalNameToId = {};

    try {
      final contextBuilder = _ref.read(aiContextBuilderProvider);
      final rawContext = await contextBuilder.buildContext();
      _extractKnownEntities(
        rawContext,
        knownProjectNames,
        projectNameToId,
        knownGoalNames,
        goalNameToId,
      );
    } catch (_) {
      // Fallback cleanly if context builder is not ready or offline
    }

    // 2. Perform semantic separation into Diary statements and Task statements
    return _parseTranscriptSemantically(
      transcript: clean,
      now: now,
      knownProjectNames: knownProjectNames,
      projectNameToId: projectNameToId,
      knownGoalNames: knownGoalNames,
      goalNameToId: goalNameToId,
    );
  }

  void _extractKnownEntities(
    String contextText,
    List<String> projectNames,
    Map<String, String> projectMap,
    List<String> goalNames,
    Map<String, String> goalMap,
  ) {
    final lines = contextText.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') && trimmed.contains(':') && !trimmed.contains('Priority:')) {
        // e.g. "- Mobile App: Description"
        final parts = trimmed.substring(2).split(':');
        final name = parts.first.trim();
        if (name.isNotEmpty && name.length >= 3) {
          projectNames.add(name);
          projectMap[name.toLowerCase()] = name;
        }
      } else if (trimmed.startsWith('- ') && trimmed.contains('(Progress:')) {
        // e.g. "- Finish API Documentation (Progress: 40%)"
        final name = trimmed.substring(2).split('(').first.trim();
        if (name.isNotEmpty) {
          goalNames.add(name);
          goalMap[name.toLowerCase()] = name;
        }
      }
    }
  }

  VoiceNoteExtractionResult _parseTranscriptSemantically({
    required String transcript,
    required DateTime now,
    required List<String> knownProjectNames,
    required Map<String, String> projectNameToId,
    required List<String> knownGoalNames,
    required Map<String, String> goalNameToId,
  }) {
    // Break transcript into candidate sentences or clauses
    final segments = _segmentTranscript(transcript);

    final diarySegments = <String>[];
    final taskItems = <ExtractedVoiceTask>[];

    for (final segment in segments) {
      final seg = segment.trim();
      if (seg.isEmpty) continue;

      final isDiary = _isDiarySegment(seg);
      final isTask = _isTaskSegment(seg);

      if (isDiary && !isTask) {
        diarySegments.add(seg);
      } else if (isTask && !isDiary) {
        final extracted = _extractTasksFromSegment(
          segment: seg,
          now: now,
          knownProjectNames: knownProjectNames,
          projectNameToId: projectNameToId,
          knownGoalNames: knownGoalNames,
          goalNameToId: goalNameToId,
        );
        taskItems.addAll(extracted);
      } else {
        // Ambiguous segment: check if it has past actions vs future actions
        if (_hasPastTenseOrJournalKeywords(seg)) {
          diarySegments.add(seg);
        } else if (_hasActionVerbOrFutureKeywords(seg)) {
          final extracted = _extractTasksFromSegment(
            segment: seg,
            now: now,
            knownProjectNames: knownProjectNames,
            projectNameToId: projectNameToId,
            knownGoalNames: knownGoalNames,
            goalNameToId: goalNameToId,
          );
          taskItems.addAll(extracted);
        } else {
          // If neither, treat as general note/diary if past/neutral, or task if imperative
          if (_startsWithImperativeVerb(seg)) {
            final extracted = _extractTasksFromSegment(
              segment: seg,
              now: now,
              knownProjectNames: knownProjectNames,
              projectNameToId: projectNameToId,
              knownGoalNames: knownGoalNames,
              goalNameToId: goalNameToId,
            );
            taskItems.addAll(extracted);
          } else {
            diarySegments.add(seg);
          }
        }
      }
    }

    // Build Diary Entry content if any diary segments were detected
    String? diaryContent;
    String? diaryTitle;
    String? diaryMoodKey;

    if (diarySegments.isNotEmpty) {
      diaryContent = diarySegments.join(' ');
      diaryContent = _capitalizeFirstLetter(diaryContent);

      final dateStr = DateFormat('EEEE, MMM d').format(now);
      diaryTitle = 'Voice Reflection — $dateStr';
      diaryMoodKey = _detectMood(diaryContent);
    }

    return VoiceNoteExtractionResult(
      rawTranscript: transcript,
      diaryContent: diaryContent,
      diaryTitle: diaryTitle,
      diaryMoodKey: diaryMoodKey,
      tasks: taskItems,
    );
  }

  /// Splits speech transcript into clauses/sentences.
  /// Handles both punctuation (".", "!", "?") and transitional conjunctions/time markers
  /// like "Today I ... Tomorrow I ..." or "... work and tomorrow I need to ...".
  List<String> _segmentTranscript(String text) {
    // Insert split markers before prominent temporal boundary markers and transitional conjunctions
    String preprocessed = text
        .replaceAll(RegExp(r'(?<=\w)\s+(?:and|also|but|then)?\s*(?=(?:tomorrow|yesterday|next week|tonight)\b)', caseSensitive: false), '.\n')
        .replaceAll(RegExp(r'(?<=\w)\s+(?:and|also|but|then)?\s*(?=(?:today i|earlier today)\b)', caseSensitive: false), '.\n')
        .replaceAll(RegExp(r"(?<=\w)\s+(?:and|also|but|then)\s+(?=(?:i need to|need to|i have to|have to|i plan to|plan to|i want to|want to|don't forget to|remind me to)\b)", caseSensitive: false), '.\n');

    final rawSentences = preprocessed.split(RegExp(r'[.!?\n]+'));
    final results = <String>[];

    for (final s in rawSentences) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) {
        results.add(trimmed);
      }
    }

    return results;
  }

  bool _isDiarySegment(String text) {
    final lower = text.toLowerCase();

    // Explicit past completed work or journal reflections
    final diaryPastPatterns = [
      RegExp(r'\btoday\s+i\s+(finished|completed|worked on|did|spent|went|read|coded|built|shipped|fixed|wrote|met)\b'),
      RegExp(r'\b(i\s+finished|i\s+completed|i\s+worked on|i\s+spent time|i\s+coded|i\s+shipped|i\s+logged)\b'),
      RegExp(r'\b(today\s+was\s+(a\s+)?(great|good|productive|busy|exhausting|calm|quiet|tough|challenging|fun|relaxing))\b'),
      RegExp(r'\b(had\s+a\s+(great|good|productive|busy|quiet)\s+day)\b'),
      RegExp(r'\b(felt\s+(great|good|tired|happy|awesome|stressed|exhausted|energized|accomplished))\b'),
      RegExp(r'\b(feeling\s+(great|good|tired|happy|awesome|stressed|exhausted|energized))\b'),
      RegExp(r'\b(grateful\s+for|thankful\s+for|proud\s+of|enjoyed\s+today)\b'),
      RegExp(r'\b(earlier\s+today|this\s+morning\s+i\s+(finished|completed|did|worked on))\b'),
      RegExp(r'\bjust\s+finished\b'),
    ];

    for (final p in diaryPastPatterns) {
      if (p.hasMatch(lower)) return true;
    }

    return false;
  }

  bool _isTaskSegment(String text) {
    final lower = text.toLowerCase();

    // Future actions or task markers
    final taskPatterns = [
      RegExp(r'\b(tomorrow|tonight|next\s+week|day\s+after\s+tomorrow|on\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday))\b'),
      RegExp(r"\b(need\s+to|have\s+to|must|plan\s+to|want\s+to|going\s+to|gotta|remember\s+to|don't\s+forget\s+to|remind\s+me\s+to)\b"),
      RegExp(r'\b(schedule|todo|task)\b'),
      RegExp(r'\bat\s+\d{1,2}(?::\d{2})?\s*(am|pm)?\b'),
      RegExp(r'\bfrom\s+\d{1,2}.*to\s+\d{1,2}\b'),
    ];

    for (final p in taskPatterns) {
      if (p.hasMatch(lower)) return true;
    }

    // Check if sentence starts with an imperative action verb
    return _startsWithImperativeVerb(text);
  }

  bool _hasPastTenseOrJournalKeywords(String text) {
    final lower = text.toLowerCase();
    return lower.contains('finished') ||
        lower.contains('completed') ||
        lower.contains('worked on') ||
        lower.contains('accomplished') ||
        lower.contains('was able to') ||
        lower.contains('felt') ||
        lower.contains('feeling') ||
        lower.contains('enjoyed');
  }

  bool _hasActionVerbOrFutureKeywords(String text) {
    final lower = text.toLowerCase();
    return lower.contains('tomorrow') ||
        lower.contains('need to') ||
        lower.contains('have to') ||
        lower.contains('schedule') ||
        lower.contains('call ') ||
        lower.contains('finish ') ||
        lower.contains('send ');
  }

  bool _startsWithImperativeVerb(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return false;
    final first = words.first.toLowerCase();

    const imperativeVerbs = {
      'finish',
      'call',
      'email',
      'send',
      'prepare',
      'buy',
      'review',
      'write',
      'fix',
      'update',
      'deploy',
      'meet',
      'check',
      'submit',
      'complete',
      'schedule',
      'create',
      'test',
      'read',
      'study',
      'clean',
      'pay',
      'order',
    };

    return imperativeVerbs.contains(first);
  }

  /// Extracts one or more [ExtractedVoiceTask]s from an actionable segment.
  /// Handles compound sentences joined with "and" or "then"
  /// (e.g. "Tomorrow I need to finish the API and call Ahmad about the project").
  List<ExtractedVoiceTask> _extractTasksFromSegment({
    required String segment,
    required DateTime now,
    required List<String> knownProjectNames,
    required Map<String, String> projectNameToId,
    required List<String> knownGoalNames,
    required Map<String, String> goalNameToId,
  }) {
    final tasks = <ExtractedVoiceTask>[];
    final lower = segment.toLowerCase();

    // 1. Detect explicit date
    DateTime? taskDueDate = _extractDueDate(lower, now);

    // 2. Detect explicit time or time range
    TimeOfDay? taskDueTime = _extractDueTime(lower);
    TimeOfDay? taskStartTime;
    TimeOfDay? taskEndTime;

    final range = _extractTimeRange(lower);
    if (range != null) {
      taskStartTime = range.$1;
      taskEndTime = range.$2;
      taskDueTime = taskEndTime;
    }

    // 3. Detect explicit priority
    TaskPriority priority = TaskPriority.medium;
    if (lower.contains('urgent') || lower.contains('asap') || lower.contains('critical') || lower.contains('emergency')) {
      priority = TaskPriority.urgent;
    } else if (lower.contains('high priority') || lower.contains('important')) {
      priority = TaskPriority.high;
    } else if (lower.contains('low priority') || lower.contains('trivial')) {
      priority = TaskPriority.low;
    }

    // 4. Strip temporal & modal prefixes to extract pure action phrases
    String cleanSegment = segment
        .replaceAll(RegExp(r'\b(tomorrow|today|tonight|next week|day after tomorrow)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r"\b(i\s+need\s+to|need\s+to|i\s+have\s+to|have\s+to|i\s+must|i\s+want\s+to|want\s+to|i\s+plan\s+to|going\s+to|gotta|remember\s+to|don't\s+forget\s+to|remind\s+me\s+to)\b", caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(urgent|asap|critical|high priority|important|low priority):?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(at\s+\d{1,2}(?::\d{2})?\s*(am|pm)?)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(from\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\s+to\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b', caseSensitive: false), '')
        .trim();

    // Check for compound tasks joined by " and " or " then "
    // e.g. "finish the API and call Ahmad about the project"
    final actionClauses = _splitCompoundActionClauses(cleanSegment);

    for (final clause in actionClauses) {
      final cleanedTitle = _cleanTaskTitle(clause);
      if (cleanedTitle.isEmpty) continue;

      // Match project or goal relationship
      String? matchedProjId;
      String? matchedProjName;
      String? matchedGId;
      String? matchedGName;

      final titleLower = cleanedTitle.toLowerCase();
      for (final pName in knownProjectNames) {
        if (titleLower.contains(pName.toLowerCase())) {
          matchedProjName = pName;
          matchedProjId = projectNameToId[pName.toLowerCase()];
          break;
        }
      }

      for (final gName in knownGoalNames) {
        if (titleLower.contains(gName.toLowerCase())) {
          matchedGName = gName;
          matchedGId = goalNameToId[gName.toLowerCase()];
          break;
        }
      }

      // Determine category based on keywords
      String category = 'Other';
      if (titleLower.contains('call') || titleLower.contains('email') || titleLower.contains('message') || titleLower.contains('meet')) {
        category = 'Communication';
      } else if (titleLower.contains('api') || titleLower.contains('database') || titleLower.contains('code') || titleLower.contains('bug') || titleLower.contains('flutter') || titleLower.contains('test')) {
        category = 'Work';
      } else if (titleLower.contains('study') || titleLower.contains('read') || titleLower.contains('learn')) {
        category = 'Education';
      } else if (titleLower.contains('gym') || titleLower.contains('run') || titleLower.contains('workout')) {
        category = 'Health';
      }

      tasks.add(
        ExtractedVoiceTask(
          id: _uuid.v4(),
          title: cleanedTitle,
          dueDate: taskDueDate,
          dueTime: taskDueTime,
          startTime: taskStartTime,
          endTime: taskEndTime,
          priority: priority,
          category: category,
          matchedProjectId: matchedProjId,
          matchedProjectName: matchedProjName,
          matchedGoalId: matchedGId,
          matchedGoalName: matchedGName,
          isSelected: true,
        ),
      );
    }

    return tasks;
  }

  List<String> _splitCompoundActionClauses(String text) {
    // Look for conjunctions between action verbs
    // e.g. "... and call Ahmad about the project" or "... then call Ahmad"
    final regex = RegExp(r'\b(?:and|then|also)\s+(?=(?:finish|call|email|send|prepare|buy|review|write|fix|update|deploy|meet|check|submit|complete|create|test|read|study|clean|pay|order)\b)', caseSensitive: false);

    final parts = text.split(regex);
    final list = <String>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty) list.add(t);
    }
    return list.isNotEmpty ? list : [text];
  }

  String _cleanTaskTitle(String raw) {
    var title = raw
        .replaceAll(RegExp(r'^(and|then|also|to|i need to|need to|schedule)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.,;:]+$'), '')
        .trim();

    if (title.isEmpty) return '';

    // Remove filler "the" if it sounds better, but retain natural nouns:
    // e.g. "finish the API" -> "Finish API" or "Finish the API"
    if (title.toLowerCase().startsWith('finish the ')) {
      title = 'Finish ${title.substring(11)}';
    } else if (title.toLowerCase().startsWith('call ')) {
      title = 'Call ${title.substring(5)}';
    }

    return _capitalizeFirstLetter(title);
  }

  DateTime? _extractDueDate(String lower, DateTime now) {
    if (lower.contains('tomorrow')) {
      final tom = now.add(const Duration(days: 1));
      return DateTime(tom.year, tom.month, tom.day);
    } else if (lower.contains('day after tomorrow')) {
      final dayAfter = now.add(const Duration(days: 2));
      return DateTime(dayAfter.year, dayAfter.month, dayAfter.day);
    } else if (lower.contains('today') || lower.contains('tonight')) {
      return DateTime(now.year, now.month, now.day);
    }

    // Check specific weekdays: e.g. "on friday", "on next monday"
    final days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (final entry in days.entries) {
      if (lower.contains('on ${entry.key}') || lower.contains('next ${entry.key}')) {
        int diff = entry.value - now.weekday;
        if (diff <= 0) diff += 7;
        final target = now.add(Duration(days: diff));
        return DateTime(target.year, target.month, target.day);
      }
    }

    return null;
  }

  TimeOfDay? _extractDueTime(String lower) {
    // Look for "at X [am|pm]" or "at X:XX"
    final regex = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b');
    final match = regex.firstMatch(lower);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final period = match.group(3);

      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  (TimeOfDay, TimeOfDay)? _extractTimeRange(String lower) {
    final rangeRegex = RegExp(
      r'\bfrom\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+to\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    );
    final match = rangeRegex.firstMatch(lower);
    if (match != null) {
      int startHour = int.parse(match.group(1)!);
      final startMin = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final startPeriod = match.group(3);

      int endHour = int.parse(match.group(4)!);
      final endMin = match.group(5) != null ? int.parse(match.group(5)!) : 0;
      final endPeriod = match.group(6);

      if (startPeriod == 'pm' && startHour < 12) startHour += 12;
      if (startPeriod == 'am' && startHour == 12) startHour = 0;

      if (endPeriod == 'pm' && endHour < 12) endHour += 12;
      if (endPeriod == 'am' && endHour == 12) endHour = 0;

      if (startPeriod == null && endPeriod == 'pm' && endHour >= 12 && startHour < 12) {
        if (startHour >= 1 && startHour <= 6) startHour += 12;
      }

      return (TimeOfDay(hour: startHour, minute: startMin), TimeOfDay(hour: endHour, minute: endMin));
    }

    return null;
  }

  String _detectMood(String content) {
    final lower = content.toLowerCase();
    if (lower.contains('great') || lower.contains('awesome') || lower.contains('excited') || lower.contains('celebrat')) {
      return 'excited';
    } else if (lower.contains('happy') || lower.contains('proud') || lower.contains('good') || lower.contains('accomplished')) {
      return 'happy';
    } else if (lower.contains('calm') || lower.contains('peaceful') || lower.contains('relaxed')) {
      return 'calm';
    } else if (lower.contains('tired') || lower.contains('exhausted') || lower.contains('sleepy')) {
      return 'tired';
    } else if (lower.contains('stressed') || lower.contains('anxious') || lower.contains('headwind')) {
      return 'stressed';
    }
    return 'good';
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
