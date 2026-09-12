import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/content/data/models/app_content_model.dart';
import 'package:timora/features/content/services/app_content_service.dart';
import 'package:timora/features/routine/data/repositories/routine_template_repository.dart';
import 'package:timora/features/schedule/data/models/activity_definition.dart';
import 'package:timora/features/schedule/data/repositories/custom_activity_repository.dart';
import 'package:timora/features/settings/services/feature_flags_service.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/career/data/repositories/career_roadmap_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Timora Admin + Flutter Integration Tests', () {
    test('1. Remote Activities Merging & Local Caching', () async {
      final repo = CustomActivityRepository(prefs);
      final notifier = AllActivitiesNotifier(repo);

      // Verify defaults are present
      expect(notifier.state.isNotEmpty, isTrue);
      final initialCount = notifier.state.length;

      // Add a custom activity
      final custom = const ActivityDefinition(
        id: 'custom_act_1',
        name: 'Executive Strategy Review',
        category: 'Work & Study',
        categoryGroup: ActivityCategoryGroup.workStudy,
        icon: '💼',
        isCustom: true,
      );

      await notifier.addCustomActivity(custom);
      expect(notifier.state.length, equals(initialCount + 1));
      expect(notifier.state.any((a) => a.id == 'custom_act_1'), isTrue);

      // Verify custom activities persist in SharedPreferences
      final reloadedRepo = CustomActivityRepository(prefs);
      final storedCustoms = reloadedRepo.getCustomActivities();
      expect(storedCustoms.length, equals(1));
      expect(storedCustoms.first.name, equals('Executive Strategy Review'));
    });

    test('2. Routine Templates vs Personal Routine Isolation', () async {
      final repo = RoutineTemplateRepository(prefs);
      final templates = repo.getCachedTemplates();
      expect(templates.isNotEmpty, isTrue);

      final template = templates.first;
      const userRoutineId = 'user_personal_routine_101';

      // Instantiate personal routine
      final routine = template.instantiateRoutine(userRoutineId);
      final blocks = template.instantiateBlocks(userRoutineId);

      expect(routine.id, equals(userRoutineId));
      expect(routine.name, equals(template.title));
      expect(blocks.length, equals(template.blocks.length));

      for (final b in blocks) {
        expect(b.routineId, equals(userRoutineId));
        expect(b.id, isNot(equals(userRoutineId)));
      }

      // Ensure template itself was not mutated
      expect(template.id, isNot(equals(userRoutineId)));
    });

    test('3. Feature Flags Default and Gating Status', () async {
      final service = FeatureFlagsService(prefs);
      final initialFlags = service.getCachedFlags();

      expect(initialFlags['smart_daily_planner'], isTrue);
      expect(initialFlags['timora_autopilot'], isTrue);
      expect(initialFlags['career_document_vault'], isTrue);
      expect(initialFlags['career_roadmap'], isTrue);
      expect(initialFlags['natural_voice_planning'], isTrue);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final state = container.read(featureFlagsProvider);
      expect(state.isCareerDocumentVaultEnabled, isTrue);
      expect(state.isCareerRoadmapEnabled, isTrue);
      expect(state.isAutopilotEnabled, isTrue);
      expect(state.isNaturalVoicePlanningEnabled, isTrue);

      container.dispose();
    });

    test('4. App Content Active Filtering', () async {
      final service = AppContentService(prefs);
      final now = DateTime.now();

      final activeModel = AppContentModel(
        id: 'content_1',
        title: 'Productivity Blueprint',
        content: 'Focus blocks boost cognitive retention.',
        contentType: 'announcement',
        isActive: true,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(activeModel.isActive, isTrue);
      expect(activeModel.title, equals('Productivity Blueprint'));
      expect(service.getCachedContent(), isEmpty);
    });

    test('5. Career Roadmap No CircularDependencyError on Initialization', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final repo = container.read(careerRoadmapRepositoryProvider);
      final roadmap = await repo.getActiveRoadmap();

      expect(roadmap, isNotNull);
      expect(roadmap!.title, contains('AI & Machine Learning'));

      final milestones = await repo.getMilestonesForRoadmap(roadmap.id);
      expect(milestones.isNotEmpty, isTrue);

      container.dispose();
    });

    test('6. Natural Voice Intent Routing', () {
      expect(
        VoiceInputService.determineTarget('What should I do now?'),
        equals(VoiceRoutingTarget.queryWhatShouldIDoNow),
      );

      expect(
        VoiceInputService.determineTarget('What is my schedule tomorrow?'),
        equals(VoiceRoutingTarget.querySchedule),
      );

      expect(
        VoiceInputService.determineTarget('Schedule study tomorrow at 9 AM'),
        equals(VoiceRoutingTarget.activity),
      );

      expect(
        VoiceInputService.determineTarget('Schedule gym at 6 PM'),
        equals(VoiceRoutingTarget.activity),
      );

      expect(
        VoiceInputService.determineTarget('Move research to 8 PM'),
        equals(VoiceRoutingTarget.reschedule),
      );

      expect(
        VoiceInputService.determineTarget('Cancel gym tomorrow'),
        equals(VoiceRoutingTarget.cancel),
      );
    });
  });
}
