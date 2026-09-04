import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/ai_assistant/data/models/ai_models.dart';
import 'package:timora/features/ai_assistant/services/ai_context_builder.dart';
import 'package:timora/features/ai_assistant/services/ai_service.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/habits/presentation/providers/habit_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Phase 8 — AI Foundation & Action Engine Tests', () {
    test('AI-1: AIContextBuilder generates structured markdown productivity context', () async {
      final builder = container.read(aiContextBuilderProvider);
      final context = await builder.buildContext();

      expect(context, contains('=== USER PRODUCTIVITY CONTEXT ==='));
      expect(context, contains('User Profile'));
      expect(context, contains('================================'));
    });

    test('AI-2: AIAction models payload correctly', () {
      final payload = AIActionPayload(
        summary: 'Scheduled 1 task and 1 habit',
        confidence: 'high',
        actions: [
          AIAction(
            id: 'act_1',
            type: AIActionType.createTask,
            data: {'title': 'Finish AI Foundation', 'priority': 'urgent'},
          ),
          AIAction(
            id: 'act_2',
            type: AIActionType.createHabit,
            data: {'title': 'Morning Deep Work', 'icon': '🧠', 'frequency': 'daily'},
          ),
        ],
      );

      expect(payload.summary, 'Scheduled 1 task and 1 habit');
      expect(payload.confidence, 'high');
      expect(payload.actions.length, 2);
      expect(payload.actions[0].type, AIActionType.createTask);
      expect(payload.actions[1].type, AIActionType.createHabit);
    });

    test('AI-3: AIActionService executes proposed task and habit actions', () async {
      final actionService = container.read(aiActionServiceProvider);

      final actions = [
        AIAction(
          id: 'action_t1',
          type: AIActionType.createTask,
          data: {'title': 'AI Generated Task 1', 'priority': 'high'},
        ),
        AIAction(
          id: 'action_h1',
          type: AIActionType.createHabit,
          data: {'title': 'AI Generated Habit 1', 'icon': '⭐'},
        ),
      ];

      await actionService.applyActions(actions);

      final tasks = await container.read(allTasksProvider.future);
      expect(tasks.any((t) => t.title == 'AI Generated Task 1'), isTrue);

      final habits = await container.read(allHabitsProvider.future);
      expect(habits.any((h) => h.title == 'AI Generated Habit 1'), isTrue);
    });
  });
}
