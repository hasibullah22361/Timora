import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../data/models/autopilot_action_model.dart';
import '../data/models/schedule_activity.dart';
import '../data/repositories/autopilot_action_repository.dart';
import '../../tasks/data/models/task_model.dart';
import '../../settings/data/models/settings_models.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../notifications/application/voice_announcement_service.dart';
import '../../analytics/services/productivity_event_service.dart';
import 'missed_task_recovery_service.dart';

final timoraAutopilotServiceProvider = Provider<TimoraAutopilotService>((ref) {
  final service = TimoraAutopilotService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class TimoraAutopilotService {
  final Ref _ref;
  Timer? _evaluationTimer;
  bool _isEvaluating = false;

  TimoraAutopilotService(this._ref) {
    _startObservationLoop();
  }

  void _startObservationLoop() {
    _evaluationTimer?.cancel();
    // Run autopilot observation cycle every 2 minutes
    _evaluationTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      runAutopilotCycle();
    });
  }

  void dispose() {
    _evaluationTimer?.cancel();
  }

  /// Runs an active observation and adjustment pass
  Future<void> runAutopilotCycle() async {
    if (_isEvaluating) return;
    _isEvaluating = true;

    try {
      final settings = _ref.read(settingsProvider);
      final mode = settings.autopilotMode;

      if (mode == AutopilotMode.off) {
        _isEvaluating = false;
        return;
      }

      final recoveryService = _ref.read(missedTaskRecoveryServiceProvider);
      final recommendations = await recoveryService.generateRecoveryRecommendations();

      if (recommendations.isEmpty) {
        _isEvaluating = false;
        return;
      }

      // 1. Deduplicated missed task notification generation
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      SharedPreferences? prefs;
      try {
        prefs = _ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs ??= await SharedPreferences.getInstance();

      final notifiedList = prefs.getStringList('timora_autopilot_notified_missed_ids') ?? [];
      bool hasNewNotification = false;

      for (final rec in recommendations) {
        final entityId = rec.activity?.id ?? rec.task?.id;
        if (entityId == null) continue;

        // Verify task or activity is not completed or skipped
        if (rec.activity != null) {
          if (rec.activity!.status == ActivityStatus.completed || rec.activity!.status == ActivityStatus.skipped) {
            continue;
          }
        } else if (rec.task != null) {
          if (rec.task!.isCompleted || rec.task!.isDeleted || rec.task!.status == TaskStatus.cancelled) {
            continue;
          }
        }

        final dedupeKey = '${dateStr}_$entityId';
        if (!notifiedList.contains(dedupeKey)) {
          notifiedList.add(dedupeKey);
          hasNewNotification = true;

          if (rec.activity != null) {
            await _ref.read(productivityEventServiceProvider).logActivityMissed(rec.activity!);
          } else if (rec.task != null) {
            await _ref.read(productivityEventServiceProvider).logTaskMissed(rec.task!);
          }
        }
      }

      if (hasNewNotification) {
        await prefs.setStringList('timora_autopilot_notified_missed_ids', notifiedList);
        _ref.invalidate(allProductivityEventsProvider);
      }

      // 2. Autopilot actions
      final autopilotRepo = _ref.read(autopilotActionRepositoryProvider);

      for (final rec in recommendations) {
        final entityId = rec.activity?.id ?? rec.task?.id;
        if (entityId == null) continue;

        // Guard against moving tasks repeatedly (max 2 autopilot moves per entity)
        final moveCount = await autopilotRepo.getActionCountForEntity(entityId);
        if (moveCount >= 2) {
          continue;
        }

        if (mode == AutopilotMode.fullAutopilot) {
          // Autonomous execution
          await recoveryService.applyRecovery(rec);

          // Record action in history
          final action = AutopilotActionModel(
            actionType: 'reschedule_missed',
            entityId: entityId,
            title: rec.title,
            originalStart: rec.originalStart,
            originalEnd: rec.originalEnd,
            newStart: rec.proposedStart,
            newEnd: rec.proposedEnd,
            reason: 'Autopilot detected missed "${rec.title}" and found an open recovery slot.',
            status: AutopilotActionStatus.applied,
          );
          await autopilotRepo.recordAction(action);

          // Log productivity event
          await _ref.read(productivityEventServiceProvider).logAutopilotAction(
                actionType: 'reschedule_missed',
                entityId: entityId,
                title: rec.title,
                reason: action.reason,
              );

          // Announce to user
          try {
            final voice = _ref.read(voiceAnnouncementServiceProvider);
            voice.speakNotification(
              title: 'Timora Autopilot',
              body: 'Moved "${rec.title}" to ${_formatTime(rec.proposedStart)}.',
            );
          } catch (_) {}

          debugPrint('[Autopilot] Automatically rescheduled "${rec.title}" to ${rec.proposedStart}');
        } else if (mode == AutopilotMode.assisted) {
          // In assisted mode, recommendations remain available in recoveryRecommendationsProvider
          debugPrint('[Autopilot Assisted] Recommended recovery for "${rec.title}" at ${rec.proposedStart}');
        }
      }
    } catch (e) {
      debugPrint('[Autopilot] Cycle error: $e');
    } finally {
      _isEvaluating = false;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
