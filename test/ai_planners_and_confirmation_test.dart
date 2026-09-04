import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/ai_assistant/data/models/ai_models.dart';
import 'package:timora/features/ai_assistant/data/providers/mock_ai_provider.dart';
import 'package:timora/features/ai_assistant/services/ai_service.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

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

  group('Phase 9 — AI Actions & Planners Architecture Tests', () {
    test('PLANNER-1: Dynamic AI generates daily plan with action payload for "Plan my day"', () async {
      final ai = container.read(aiProvider);
      final response = await ai.generateResponse(
        prompt: 'Plan my day',
        contextContext: 'User Profile: Hasib\n- [Priority: high] Master Flutter Testing',
        history: [],
      );

      expect(response.content, contains('Morning'));
      expect(response.actionPayload, isNotNull);
      expect(response.actionPayload!.actions.length, greaterThanOrEqualTo(1));
    });

    test('PLANNER-2: Dynamic AI generates goal breakdown for "Help me complete my goals"', () async {
      final ai = container.read(aiProvider);
      final response = await ai.generateResponse(
        prompt: 'Help me complete my goals',
        contextContext: 'Active Goals:\n- Launch Timora Pro (Progress: 40%)',
        history: [],
      );

      expect(response.content, contains('Step 1'));
      expect(response.actionPayload, isNotNull);
      expect(response.actionPayload!.actions.any((a) => a.type == AIActionType.createTask), isTrue);
    });

    test('CONFIRM-1: Selective action execution applies only chosen items', () async {
      final actionService = container.read(aiActionServiceProvider);

      final payload = AIActionPayload(
        summary: 'Suggested 2 tasks',
        confidence: 'high',
        actions: [
          AIAction(id: 't1', type: AIActionType.createTask, data: {'title': 'Accepted Task'}),
          AIAction(id: 't2', type: AIActionType.createTask, data: {'title': 'Rejected Task'}),
        ],
      );

      // Simulate user unchecking 't2' and applying only 't1'
      final userSelectedActions = payload.actions.where((a) => a.id == 't1').toList();
      await actionService.applyActions(userSelectedActions);

      final tasks = await container.read(allTasksProvider.future);
      expect(tasks.any((t) => t.title == 'Accepted Task'), isTrue);
      expect(tasks.any((t) => t.title == 'Rejected Task'), isFalse);
    });
  });
}
