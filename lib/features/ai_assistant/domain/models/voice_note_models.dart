import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../tasks/data/models/task_model.dart';

/// Represents an individual task extracted by Timora AI from a voice note.
class ExtractedVoiceTask {
  final String id;
  String title;
  DateTime? dueDate;
  TimeOfDay? dueTime;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int estimatedDurationMinutes;
  TaskPriority priority;
  String category;
  String? matchedProjectId;
  String? matchedProjectName;
  String? matchedGoalId;
  String? matchedGoalName;
  bool isSelected;

  ExtractedVoiceTask({
    String? id,
    required this.title,
    this.dueDate,
    this.dueTime,
    this.startTime,
    this.endTime,
    this.estimatedDurationMinutes = 30,
    this.priority = TaskPriority.medium,
    this.category = 'Other',
    this.matchedProjectId,
    this.matchedProjectName,
    this.matchedGoalId,
    this.matchedGoalName,
    this.isSelected = true,
  }) : id = id ?? const Uuid().v4();

  /// Converts this extracted task into a real Timora [TaskModel].
  TaskModel toTaskModel({String? scheduleActivityId}) {
    return TaskModel(
      id: id,
      title: title.trim().isNotEmpty ? title.trim() : 'Voice Task',
      description: 'Extracted from Timora Quick Voice Note',
      status: TaskStatus.pending,
      priority: priority,
      category: category,
      dueDate: dueDate,
      dueTime: dueTime ?? startTime,
      startTime: startTime,
      endTime: endTime,
      reminderEnabled: dueTime != null || startTime != null,
      reminderMinutesBefore: 15,
      scheduleActivityId: scheduleActivityId,
      projectId: matchedProjectId,
      goalId: matchedGoalId,
      estimatedDurationMinutes: estimatedDurationMinutes,
      createdAt: DateTime.now(),
    );
  }
}

/// The structured result produced by Timora AI understanding from a voice note.
class VoiceNoteExtractionResult {
  final String rawTranscript;
  final String? diaryContent;
  final String? diaryTitle;
  final String? diaryMoodKey;
  final List<ExtractedVoiceTask> tasks;
  final String signature;
  final DateTime processedAt;

  VoiceNoteExtractionResult({
    required this.rawTranscript,
    this.diaryContent,
    this.diaryTitle,
    this.diaryMoodKey,
    this.tasks = const [],
    String? signature,
    DateTime? processedAt,
  })  : signature = signature ?? _computeSignature(rawTranscript),
        processedAt = processedAt ?? DateTime.now();

  bool get hasDiary => diaryContent != null && diaryContent!.trim().isNotEmpty;
  bool get hasTasks => tasks.isNotEmpty;

  static String _computeSignature(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
