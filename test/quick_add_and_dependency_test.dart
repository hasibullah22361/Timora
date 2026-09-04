import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/quick_add/services/quick_add_parser.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late TaskRepository taskRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    taskRepo = TaskRepository(prefs, userId: 'test_user_nlp');
  });

  group('Phase 2 — QuickAddParser Natural Language Tests', () {
    test('NLP-1: Parses time slot, date, duration, and study category', () {
      final res = QuickAddParser.parse('Study AI tomorrow from 9 AM to 11 AM');

      expect(res.title.toLowerCase(), contains('study ai'));
      expect(res.category, 'Study');
      expect(res.date, isNotNull);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(res.date!.day, tomorrow.day);
      expect(res.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(res.endTime, const TimeOfDay(hour: 11, minute: 0));
      expect(res.estimatedDurationMinutes, 120);
    });

    test('NLP-2: Parses recurring days, recurrence, and time', () {
      final res = QuickAddParser.parse('Work on research every Monday and Wednesday at 8 PM');

      expect(res.title.toLowerCase(), contains('research'));
      expect(res.category, 'Work');
      expect(res.recurrence, 'weekly');
      expect(res.daysOfWeek, containsAll([1, 3]));
      expect(res.startTime, const TimeOfDay(hour: 20, minute: 0));
    });

    test('NLP-3: Parses urgency and priority keyword prefix', () {
      final res = QuickAddParser.parse('Urgent: Complete quarterly report by 5 PM');

      expect(res.title.toLowerCase(), contains('complete quarterly report'));
      expect(res.priority, TaskPriority.urgent);
      expect(res.category, 'Work');
      expect(res.dueTime, const TimeOfDay(hour: 17, minute: 0));
    });

    test('NLP-4: Parses tonight keyword and explicit minute duration', () {
      final res = QuickAddParser.parse('Read 30 pages tonight for 45 mins');

      expect(res.title.toLowerCase(), contains('read 30 pages'));
      expect(res.category, 'Study');
      expect(res.startTime, const TimeOfDay(hour: 20, minute: 0));
      expect(res.estimatedDurationMinutes, 45);
    });

    test('NLP-5: Parses daily fitness workout', () {
      final res = QuickAddParser.parse('Gym workout daily at 7 AM');

      expect(res.title.toLowerCase(), contains('gym workout'));
      expect(res.category, 'Fitness');
      expect(res.recurrence, 'daily');
      expect(res.startTime, const TimeOfDay(hour: 7, minute: 0));
    });
  });

  group('Phase 2 — Task Dependencies & Blocked State Tests', () {
    test('DEP-1: Task with incomplete prerequisite is blocked', () async {
      final prereq = TaskModel(
        id: 'task_prereq_1',
        title: 'Prerequisite Task',
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );

      final dependent = TaskModel(
        id: 'task_dep_1',
        title: 'Dependent Task',
        status: TaskStatus.pending,
        dependsOnTaskIds: ['task_prereq_1'],
        createdAt: DateTime.now(),
      );

      await taskRepo.createTask(prereq);
      await taskRepo.createTask(dependent);

      expect(taskRepo.isTaskBlocked('task_dep_1'), isTrue);
      expect(taskRepo.getPrerequisitesForTask('task_dep_1').length, 1);
      expect(taskRepo.getDependentTasks('task_prereq_1').length, 1);

      // Complete prerequisite task -> dependent unblocks!
      await taskRepo.updateTask(prereq.copyWith(status: TaskStatus.completed));
      expect(taskRepo.isTaskBlocked('task_dep_1'), isFalse);
    });

    test('DEP-2: Direct circular dependency is prevented', () async {
      final taskA = TaskModel(
        id: 'task_a',
        title: 'Task A',
        dependsOnTaskIds: ['task_b'],
        createdAt: DateTime.now(),
      );

      await taskRepo.createTask(taskA);

      // Attempting to make Task B depend on Task A (creating A -> B -> A cycle)
      expect(taskRepo.validateNoCircularDependencies('task_b', ['task_a']), isFalse);

      // Attempting self-dependency
      expect(taskRepo.validateNoCircularDependencies('task_a', ['task_a']), isFalse);
    });

    test('DEP-3: Multi-step circular dependency is prevented', () async {
      // A -> B -> C -> A cycle
      final taskA = TaskModel(id: 'task_1', title: 'Task 1', dependsOnTaskIds: ['task_2'], createdAt: DateTime.now());
      final taskB = TaskModel(id: 'task_2', title: 'Task 2', dependsOnTaskIds: ['task_3'], createdAt: DateTime.now());

      await taskRepo.createTask(taskA);
      await taskRepo.createTask(taskB);

      // Making Task 3 depend on Task 1 would cause Task 1 -> Task 2 -> Task 3 -> Task 1
      expect(taskRepo.validateNoCircularDependencies('task_3', ['task_1']), isFalse);
    });
  });
}
