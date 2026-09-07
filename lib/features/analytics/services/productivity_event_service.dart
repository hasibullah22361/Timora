import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';
import '../../tasks/data/models/task_model.dart';
import '../../schedule/data/models/schedule_activity.dart';

final productivityEventServiceProvider = Provider<ProductivityEventService>((ref) {
  final repo = ref.watch(productivityEventRepositoryProvider);
  return ProductivityEventService(repo);
});

final allProductivityEventsProvider = FutureProvider<List<ProductivityEventModel>>((ref) async {
  final repo = ref.watch(productivityEventRepositoryProvider);
  return repo.getAllEvents();
});

class ProductivityEventService {
  final ProductivityEventRepository _repo;

  ProductivityEventService(this._repo);

  Future<void> logTaskCreated(TaskModel task) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.taskCreated,
      entityType: 'task',
      entityId: task.id,
      metadata: {
        'title': task.title,
        'priority': task.priority.name,
        'category': task.category,
      },
    ));
  }

  Future<void> logTaskCompleted(TaskModel task) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.taskCompleted,
      entityType: 'task',
      entityId: task.id,
      metadata: {
        'title': task.title,
        'priority': task.priority.name,
        'category': task.category,
        'completedAt': DateTime.now().toIso8601String(),
      },
    ));
  }

  Future<void> logActivityCompleted(ScheduleActivity activity) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.activityCompleted,
      entityType: 'activity',
      entityId: activity.id,
      metadata: {
        'title': activity.title,
        'category': activity.category,
        'durationMinutes': activity.endTime.difference(activity.startTime).inMinutes,
      },
    ));
  }

  Future<void> logActivityMissed(ScheduleActivity activity) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.activityMissed,
      entityType: 'activity',
      entityId: activity.id,
      metadata: {
        'title': activity.title,
        'category': activity.category,
        'scheduledStart': activity.startTime.toIso8601String(),
        'scheduledEnd': activity.endTime.toIso8601String(),
      },
    ));
  }

  Future<void> logTaskRecovered(String taskId, String title, DateTime newSlot) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.taskRecovered,
      entityType: 'task',
      entityId: taskId,
      metadata: {
        'title': title,
        'newSlot': newSlot.toIso8601String(),
      },
    ));
  }

  Future<void> logRoutineCompleted(String routineId, String name) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.routineCompleted,
      entityType: 'routine',
      entityId: routineId,
      metadata: {'name': name},
    ));
  }

  Future<void> logAutopilotAction({
    required String actionType,
    required String entityId,
    required String title,
    required String reason,
    Map<String, dynamic>? details,
  }) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.autopilotAction,
      entityType: 'autopilot',
      entityId: entityId,
      metadata: {
        'actionType': actionType,
        'title': title,
        'reason': reason,
        if (details != null) ...details,
      },
    ));
  }

  Future<void> logCareerMilestoneCompleted(String milestoneId, String title) async {
    await _repo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.careerMilestoneCompleted,
      entityType: 'career_milestone',
      entityId: milestoneId,
      metadata: {'title': title},
    ));
  }
}
