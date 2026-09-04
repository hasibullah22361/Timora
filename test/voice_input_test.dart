import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';

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

  group('Phase 12 — Voice Input & Natural Audio Interface Tests', () {
    test('VOICE-1: VoiceInputService determines routing target accurately', () {
      expect(
        VoiceInputService.determineTarget('Urgent submit proposal today at 4pm'),
        VoiceRoutingTarget.task,
      );

      expect(
        VoiceInputService.determineTarget('Ask AI how can I organize my morning?'),
        VoiceRoutingTarget.aiAssistant,
      );

      expect(
        VoiceInputService.determineTarget('Plan my day around deep work'),
        VoiceRoutingTarget.aiAssistant,
      );

      expect(
        VoiceInputService.determineTarget('Workout session tomorrow at 7am'),
        VoiceRoutingTarget.task,
      );
    });

    test('VOICE-2: VoiceInputService parses natural speech and creates TaskModel', () async {
      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Urgent finish Flutter release tonight at 8pm',
        target: VoiceRoutingTarget.task,
      );

      expect(result.target, VoiceRoutingTarget.task);
      expect(result.parsedTask, isNotNull);
      expect(result.parsedTask!.title, contains('Flutter release'));
      expect(result.parsedTask!.priority, TaskPriority.urgent);

      final tasks = await container.read(allTasksProvider.future);
      expect(tasks.any((t) => t.title.contains('Flutter release')), isTrue);
    });
  });
}
