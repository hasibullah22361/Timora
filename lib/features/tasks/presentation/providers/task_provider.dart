import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/models/subtask_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import '../../../notifications/application/notification_service.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';
import 'package:timora/features/projects/presentation/providers/project_provider.dart';

final taskSearchQueryProvider = StateProvider<String>((ref) => '');

final allTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  final tasks = await repo.getTasks();
  
  final query = ref.watch(taskSearchQueryProvider).toLowerCase();
  if (query.isNotEmpty) {
    return tasks.where((t) => t.title.toLowerCase().contains(query) || t.description.toLowerCase().contains(query)).toList();
  }
  return tasks;
});

final todayTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.status == TaskStatus.completed && t.completedAt != null) {
      return t.completedAt!.year == now.year && t.completedAt!.month == now.month && t.completedAt!.day == now.day;
    }
    if (t.dueDate != null) {
      return t.dueDate!.year == now.year && t.dueDate!.month == now.month && t.dueDate!.day == now.day;
    }
    return false; // If no due date and not completed today, it's not a "today" task unless we force it.
  }).toList();
});

final overdueTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.status == TaskStatus.completed || t.status == TaskStatus.cancelled) return false;
    if (t.dueDate == null) return false;
    
    // Check if it's strictly before today
    final due = t.dueDate!;
    if (due.year < now.year) return true;
    if (due.year == now.year && due.month < now.month) return true;
    if (due.year == now.year && due.month == now.month && due.day < now.day) return true;
    
    // If due today, check time
    if (due.year == now.year && due.month == now.month && due.day == now.day && t.dueTime != null) {
       final dueTimeMins = t.dueTime!.hour * 60 + t.dueTime!.minute;
       final nowMins = now.hour * 60 + now.minute;
       return dueTimeMins < nowMins;
    }
    return false;
  }).toList();
});

final upcomingTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.status == TaskStatus.completed || t.status == TaskStatus.cancelled) return false;
    if (t.dueDate == null) return false;
    
    final due = t.dueDate!;
    if (due.year > now.year) return true;
    if (due.year == now.year && due.month > now.month) return true;
    if (due.year == now.year && due.month == now.month && due.day > now.day) return true;
    return false;
  }).toList();
});

final subtasksProvider = FutureProvider.family<List<SubtaskModel>, String>((ref, taskId) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getSubtasksForTask(taskId);
});

class TaskNotifier extends StateNotifier<AsyncValue<void>> {
  final TaskRepository _repo;
  final NotificationService _notif;
  final Ref _ref;

  TaskNotifier(this._repo, this._notif, this._ref) : super(const AsyncValue.data(null));

  void _syncNotification(TaskModel task) {
    final id = task.id.hashCode.abs();
    _notif.cancelNotification(id);
    
    if (!task.isDeleted && task.status == TaskStatus.pending && task.reminderEnabled && task.dueDate != null && task.dueTime != null) {
      final scheduledTime = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day,
        task.dueTime!.hour, task.dueTime!.minute
      ).subtract(Duration(minutes: task.reminderMinutesBefore));
      
      if (scheduledTime.isAfter(DateTime.now())) {
        _notif.scheduleNotification(id, 'Task Reminder', task.title, scheduledTime, channelId: 'timora_daily');
      }
    }
  }

  void _notifyRelated(TaskModel task) {
    _ref.invalidate(allTasksProvider);
    _ref.invalidate(dailyScheduleProvider);
    if (task.goalId != null && task.goalId!.isNotEmpty) {
      _ref.invalidate(allGoalsProvider);
      _ref.invalidate(goalProgressProvider(task.goalId!));
    }
    if (task.projectId != null && task.projectId!.isNotEmpty) {
      _ref.invalidate(allProjectsProvider);
      _ref.invalidate(projectProgressProvider(task.projectId!));
    }
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> createTask(TaskModel task) async {
    await _repo.createTask(task);
    _syncNotification(task);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.create,
    );
    _notifyRelated(task);
  }

  Future<void> updateTask(TaskModel task) async {
    await _repo.updateTask(task);
    _syncNotification(task);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(task);
  }

  Future<void> completeTask(TaskModel task) async {
    final completed = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
    await _repo.updateTask(completed);
    _syncNotification(completed); // will cancel
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(completed);
  }

  Future<void> undoCompleteTask(TaskModel task) async {
    final pending = task.copyWith(
      status: TaskStatus.pending,
      completedAt: null,
    );
    await _repo.updateTask(pending);
    _syncNotification(pending); // will reschedule if it has future reminders
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(pending);
  }

  Future<void> softDeleteTask(TaskModel task) async {
    await _repo.deleteTask(task.id);
    _syncNotification(task.copyWith(isDeleted: true)); // cancels
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(task);
  }
  
  Future<void> restoreTask(TaskModel task) async {
    await _repo.restoreTask(task.id);
    _syncNotification(task.copyWith(isDeleted: false)); // reschedules
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'tasks',
      entityId: task.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(task);
  }

  // Subtasks
  Future<void> createSubtask(SubtaskModel subtask) async {
    await _repo.createSubtask(subtask);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'subtasks',
      entityId: subtask.id,
      operation: SyncOperation.create,
    );
    _ref.invalidate(subtasksProvider(subtask.taskId));
    _ref.invalidate(allTasksProvider);
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> updateSubtask(SubtaskModel subtask) async {
    await _repo.updateSubtask(subtask);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'subtasks',
      entityId: subtask.id,
      operation: SyncOperation.update,
    );
    _ref.invalidate(subtasksProvider(subtask.taskId));
    _ref.invalidate(allTasksProvider);
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> deleteSubtask(String id, String taskId) async {
    await _repo.deleteSubtask(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'subtasks',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _ref.invalidate(subtasksProvider(taskId));
    _ref.invalidate(allTasksProvider);
    _ref.read(syncServiceProvider).autoSync();
  }
}

final taskNotifierProvider = Provider<TaskNotifier>((ref) {
  return TaskNotifier(
    ref.watch(taskRepositoryProvider),
    ref.watch(notificationServiceProvider),
    ref,
  );
});
