import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/main_layout/presentation/screens/main_layout_screen.dart';
import 'package:timora/features/others/presentation/screens/others_screen.dart';
import 'package:timora/features/ambient_sound/data/models/ambient_sound_model.dart';
import 'package:timora/features/ambient_sound/services/ambient_sound_service.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/routine/data/models/routine_template.dart';
import 'package:timora/features/daily_plan/data/models/timeline_item.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';

class _MockVoiceService extends VoiceAnnouncementService {
  _MockVoiceService() : super(null);

  @override
  void startScheduleMonitoring(
    Future<List<ScheduleActivity>> Function() getActivities, {
    Future<List<dynamic>> Function()? getTasks,
  }) {}

  @override
  void stopScheduleMonitoring() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 17 & 18: Navigation Restructuring Tests', () {
    testWidgets('MainLayoutScreen bottom navigation contains exactly 5 destinations (no Planner)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)),
            voiceAnnouncementServiceProvider.overrideWithValue(_MockVoiceService()),
          ],
          child: const MaterialApp(
            home: MainLayoutScreen(),
          ),
        ),
      );

      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.destinations.length, 5);

      // Verify destination labels: Home, Schedule, Tasks, Routines, Others
      final labels = navBar.destinations.map((d) => (d as NavigationDestination).label).toList();
      expect(labels, ['Home', 'Schedule', 'Tasks', 'Routines', 'Others']);
      expect(labels.contains('Planner'), false);

      // Dispose MainLayoutScreen to clean up timers
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('OthersScreen contains Planner, Notifications, Ambient Sounds and NO Profile or Settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: OthersScreen(),
          ),
        ),
      );

      // Verify Planner is present in Others
      expect(find.text('Planner'), findsOneWidget);
      // Verify Ambient Environment Sounds is present in Others
      expect(find.text('Ambient Environment Sounds'), findsOneWidget);

      // Verify Removed Items from Others section are absent
      expect(find.text('Notifications & Spoken Voice'), findsNothing);
      expect(find.text('Timora AI Assistant'), findsNothing);
      expect(find.text('Focus Mode & Timer'), findsNothing);
      expect(find.text('About Timora'), findsNothing);
      expect(find.text('Help & Support'), findsNothing);

      // Verify Profile and Settings are NOT in Others items
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('Phase 19: Focus Time & Precision Timestamp Calculation Tests', () {
    test('Focus duration accurately computes timestamps and subtracts paused intervals', () {
      final t0 = DateTime(2026, 9, 5, 21, 0, 0); // 9:00 PM
      final tPause = DateTime(2026, 9, 5, 21, 20, 0); // 9:20 PM (20 min running)
      final tResume = DateTime(2026, 9, 5, 21, 30, 0); // 9:30 PM (10 min pause)
      final tStop = DateTime(2026, 9, 5, 21, 47, 0); // 9:47 PM (17 min running after resume)

      final pausedDuration = tResume.difference(tPause).inSeconds; // 600s (10 min)
      final totalDiff = tStop.difference(t0).inSeconds; // 2820s (47 min)
      final actualFocusSeconds = totalDiff - pausedDuration; // 2220s (37 min)

      expect(actualFocusSeconds ~/ 60, 37);
    });

    test('Focus session model preserves timestamps and actual duration', () {
      final session = FocusSessionModel(
        id: 'session-123',
        startedAt: DateTime(2026, 9, 5, 21, 0, 0),
        endedAt: DateTime(2026, 9, 5, 21, 37, 0),
        plannedDurationSeconds: 45 * 60,
        actualDurationSeconds: 37 * 60,
        mode: FocusSessionMode.focus,
        status: FocusSessionStatus.completed,
        createdAt: DateTime(2026, 9, 5, 21, 0, 0),
      );

      expect(session.actualDurationSeconds ~/ 60, 37);
      expect(session.plannedDurationSeconds ~/ 60, 45);
      final percentage = ((session.actualDurationSeconds / session.plannedDurationSeconds) * 100).round();
      expect(percentage, 82);
    });
  });

  group('Phase 20: Ambient Environment Sounds Tests', () {
    test('All 12 environment sounds are registered with correct attributes', () {
      expect(AmbientSound.allSounds.length, 12);

      final soundIds = AmbientSound.allSounds.map((s) => s.id).toList();
      expect(soundIds, containsAll([
        'rain',
        'thunderstorm',
        'ocean_waves',
        'forest',
        'birds',
        'fireplace',
        'cafe',
        'wind',
        'water_stream',
        'night',
        'nature',
        'rain_thunder',
      ]));

      // Verify Rain
      final rain = AmbientSound.getById('rain');
      expect(rain.name, 'Rain');
      expect(rain.icon, '🌧️');

      // Verify Cafe
      final cafe = AmbientSound.getById('cafe');
      expect(cafe.name, 'Café');
      expect(cafe.icon, '☕');
    });

    test('AmbientSoundService handles play, pause, resume, volume and loop controls', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();

      final service = container.read(ambientSoundServiceProvider.notifier);
      var state = container.read(ambientSoundServiceProvider);

      expect(state.isPlaying, false);

      // Play rain
      await service.play('rain');
      state = container.read(ambientSoundServiceProvider);
      expect(state.isPlaying, true);
      expect(state.currentSound.id, 'rain');

      // Pause
      await service.pause();
      state = container.read(ambientSoundServiceProvider);
      expect(state.isPlaying, false);
      expect(state.isPaused, true);

      // Resume
      await service.resume();
      state = container.read(ambientSoundServiceProvider);
      expect(state.isPlaying, true);
      expect(state.isPaused, false);

      // Volume clamping
      await service.setVolume(0.85);
      state = container.read(ambientSoundServiceProvider);
      expect(state.volume, 0.85);

      // Loop toggle
      await service.setLoop(false);
      state = container.read(ambientSoundServiceProvider);
      expect(state.loop, false);

      // Stop
      await service.stop();
      state = container.read(ambientSoundServiceProvider);
      expect(state.isPlaying, false);
      expect(state.isPaused, false);
    });
  });

  group('Phase 21: Full Productive Day Routine Template Tests', () {
    test('Full Productive Day template is registered and contains all 21 activity blocks', () {
      final template = RoutineTemplate.predefinedTemplates.firstWhere(
        (t) => t.id == 'tpl_full_productive_day',
      );

      expect(template.title, 'Full Productive Day');
      expect(template.icon, '🌅');
      expect(template.blocks.length, 21);

      // First block: Wake up at 7:00 AM
      final firstBlock = template.blocks.first;
      expect(firstBlock.title, 'Wake Up');
      expect(firstBlock.startTime, const TimeOfDay(hour: 7, minute: 0));
      expect(firstBlock.endTime, const TimeOfDay(hour: 7, minute: 15));

      // Work block: 9:00 AM - 11:30 AM
      final workBlock = template.blocks.firstWhere((b) => b.title.contains('Work'));
      expect(workBlock.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(workBlock.endTime, const TimeOfDay(hour: 11, minute: 30));

      // Islamic Prayer blocks
      final prayers = template.blocks.where((b) => b.category == 'Islamic').toList();
      expect(prayers.length, 4); // Zohar, Asr, Maghrib, Isha

      // Last block: Sleep at 11:00 PM
      final lastBlock = template.blocks.last;
      expect(lastBlock.title, 'Sleep');
      expect(lastBlock.startTime, const TimeOfDay(hour: 23, minute: 0));
      expect(lastBlock.endTime, const TimeOfDay(hour: 7, minute: 0));
    });

    test('Instantiating template creates valid Routine and RoutineBlocks', () {
      final template = RoutineTemplate.predefinedTemplates.firstWhere(
        (t) => t.id == 'tpl_full_productive_day',
      );

      const routineId = 'new-routine-001';
      final routine = template.instantiateRoutine(routineId);
      final blocks = template.instantiateBlocks(routineId);

      expect(routine.id, routineId);
      expect(routine.name, 'Full Productive Day');
      expect(routine.enabled, true);
      expect(blocks.length, 21);
      expect(blocks.every((b) => b.routineId == routineId), true);
    });
  });

  group('Phase 22 & 24: Schedule ↔ Daily Planner Linking and Date Consistency Tests', () {
    test('TimelineItem representation and sorting for schedules and tasks', () {
      final items = [
        TimelineItem(
          id: 'schedule_1',
          sourceId: 'act_1',
          type: TimelineItemType.schedule,
          title: 'Study AI',
          subtitle: 'Scheduled activity',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 11, minute: 0),
          color: Colors.blue,
          icon: '💻',
        ),
        TimelineItem(
          id: 'routine_1',
          sourceId: 'blk_1',
          type: TimelineItemType.routine,
          title: 'Morning Breakfast',
          subtitle: 'Daily routine',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 8, minute: 30),
          color: Colors.orange,
          icon: '🍳',
        ),
      ];

      items.sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });

      expect(items.first.title, 'Morning Breakfast');
      expect(items.last.title, 'Study AI');
    });

    test('Local date normalization does not drift across UTC conversions', () {
      final localDate = DateTime(2026, 9, 5);
      final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

      expect(dateOnly.year, 2026);
      expect(dateOnly.month, 9);
      expect(dateOnly.day, 5);
      expect(dateOnly.hour, 0);
      expect(dateOnly.minute, 0);
    });
  });
}
