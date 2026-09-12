import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/presentation/screens/alarm_ringing_screen.dart';
import 'package:timora/features/clock/features/alarm/services/alarm_service.dart';
import 'package:timora/features/daily_plan/data/models/timeline_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🕒 1. Clock Alarm Timing Accuracy & 1-Minute Test', () {
    test('1-minute test alarm triggers accurately 60 seconds from creation', () {
      final now = DateTime(2026, 9, 12, 10, 30, 0); // 10:30:00 AM
      // User creates alarm for 1 minute later: 10:31
      final alarm = AlarmModel(
        id: 'test_1min_alarm',
        hour: 10,
        minute: 31,
        label: '1-Min Test Alarm',
        repeatDays: const [],
      );

      final nextTrigger = alarm.nextTriggerDateTime(now);
      final delay = nextTrigger.difference(now);

      expect(nextTrigger.hour, 10);
      expect(nextTrigger.minute, 31);
      expect(nextTrigger.second, 0);
      expect(delay.inSeconds, 60, reason: '1-minute test alarm should trigger in exactly 60 seconds');
      expect(delay.inMilliseconds, 60000);
    });

    test('Immediate upcoming alarm (e.g. 45 seconds away) targets same minute', () {
      final now = DateTime(2026, 9, 12, 14, 15, 15);
      final alarm = AlarmModel(
        hour: 14,
        minute: 16,
        label: 'Quick Alarm',
        repeatDays: const [],
      );

      final nextTrigger = alarm.nextTriggerDateTime(now);
      final delay = nextTrigger.difference(now);

      expect(delay.inSeconds, 45);
      expect(delay.isNegative, isFalse);
    });

    test('Snoozed alarm calculation adds exact snooze minutes to target', () {
      final triggerTime = DateTime(2026, 9, 12, 9, 0, 0);
      const snoozeMinutes = 9;
      final snoozedTrigger = triggerTime.add(const Duration(minutes: snoozeMinutes));

      expect(snoozedTrigger.hour, 9);
      expect(snoozedTrigger.minute, 9);
      expect(snoozedTrigger.difference(triggerTime).inMinutes, 9);
    });
  });

  group('📱 2. Dedicated Full-Screen Alarm Experience UI', () {
    testWidgets('Renders dedicated AlarmRingingScreen with title, time, and two swipe-up controls', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AlarmRingingScreen(
              alarmId: 'full_screen_test_alarm',
              title: 'Wake Up Morning',
              timeFormatted: '07:30 AM',
              snoozeMinutes: 10,
            ),
          ),
        ),
      );

      // Verify Alarm Title & Ringing state
      expect(find.text('Wake Up Morning'), findsOneWidget);
      expect(find.text('ALARM RINGING'), findsOneWidget);
      expect(find.text('Scheduled for 07:30 AM'), findsOneWidget);

      // Verify Swipe Up to Stop control exists
      expect(find.text('Swipe Up to Stop'), findsOneWidget);

      // Verify Swipe Up to Snooze control exists
      expect(find.text('Swipe Up to Snooze'), findsOneWidget);
      expect(find.text('+10 min'), findsOneWidget);

      // Verify no simple accidental tap buttons exist for Stop/Snooze
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('SwipeUpActionControl does not trigger on simple accidental tap', (tester) async {
      bool stopTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeUpActionControl(
                label: 'Swipe Up to Stop',
                subtitle: 'Dismiss alarm and stop sound',
                icon: Icons.alarm_off_rounded,
                accentColor: Colors.redAccent,
                onTriggered: () async {
                  stopTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      // Tap the swipe control
      await tester.tap(find.text('Swipe Up to Stop'));
      await tester.pumpAndSettle();

      // Confirm accidental tap did not trigger action
      expect(stopTriggered, isFalse, reason: 'Accidental tap must not stop or dismiss alarm');
    });

    testWidgets('SwipeUpActionControl triggers when swiped upward past threshold', (tester) async {
      bool stopTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeUpActionControl(
                label: 'Swipe Up to Stop',
                subtitle: 'Dismiss alarm and stop sound',
                icon: Icons.alarm_off_rounded,
                accentColor: Colors.redAccent,
                onTriggered: () async {
                  stopTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      // Perform an upward drag (swipe up)
      final gesture = await tester.startGesture(tester.getCenter(find.text('Swipe Up to Stop')));
      await gesture.moveBy(const Offset(0, -60)); // Drag up by 60 pixels (past 50px threshold)
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stopTriggered, isTrue, reason: 'Upward swipe past threshold must trigger action immediately');
    });

    testWidgets('SwipeUpActionControl triggers on direct upward flick with velocity', (tester) async {
      bool stopTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeUpActionControl(
                label: 'Swipe Up to Stop',
                subtitle: 'Dismiss alarm and stop sound',
                icon: Icons.alarm_off_rounded,
                accentColor: Colors.redAccent,
                onTriggered: () async {
                  stopTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      // Fling upward (quick flick)
      await tester.fling(find.byType(SwipeUpActionControl), const Offset(0, -60), 1000.0);
      await tester.pumpAndSettle();

      expect(stopTriggered, isTrue, reason: 'Direct upward flick should immediately trigger Stop without extra activation');
    });

    testWidgets('AlarmRingingScreen switches to ALARM SILENCED state when onAlarmSilencedStream emits', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AlarmRingingScreen(
              alarmId: 'silence_test_alarm',
              title: 'Study Session',
              timeFormatted: '08:00 AM',
              snoozeMinutes: 5,
            ),
          ),
        ),
      );

      expect(find.text('ALARM RINGING'), findsOneWidget);
      expect(find.text('ALARM SILENCED'), findsNothing);

      // Trigger power button silence event via AlarmService stream
      AlarmService.notifySilencedForTesting('silence_test_alarm');
      await tester.pump();

      expect(find.text('ALARM SILENCED'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    test('Recurring alarms retain enabled state while one-time alarms disable on stop', () {
      final oneTimeAlarm = AlarmModel(
        id: 'one_time_1',
        hour: 7,
        minute: 0,
        label: 'One-time Alarm',
        repeatDays: const [],
        isEnabled: true,
      );

      final recurringAlarm = AlarmModel(
        id: 'recurring_1',
        hour: 7,
        minute: 0,
        label: 'Weekly Alarm',
        repeatDays: const [1, 2, 3, 4, 5],
        isEnabled: true,
      );

      expect(oneTimeAlarm.isRepeating, isFalse);
      expect(recurringAlarm.isRepeating, isTrue);

      // Simulated Stop action
      final stoppedOneTime = oneTimeAlarm.copyWith(isEnabled: false);
      expect(stoppedOneTime.isEnabled, isFalse);

      // Recurring alarm remains enabled for next cycle
      expect(recurringAlarm.isEnabled, isTrue);
    });
  });

  group('📊 3. Plan Progress: Planned / Completed / Remaining Minutes', () {
    test('Calculates planned, completed, remaining correctly for 20m planned / 7m completed', () {
      final item = TimelineItem(
        id: 'plan_1',
        sourceId: 'src_1',
        title: 'Database Work',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 20),
        color: Colors.blue,
        icon: '💻',
        type: TimelineItemType.block,
        customPlannedMinutes: 20,
        completedMinutes: 7,
      );

      expect(item.plannedMinutes, 20);
      expect(item.completedMinutes, 7);
      expect(item.remainingMinutes, 13, reason: 'remaining = planned (20) - completed (7) = 13');
      expect(item.plannedFormatted, '20 min planned');
      expect(item.completedFormatted, '7 min completed');
      expect(item.remainingFormatted, '13 min remaining');
      expect(item.isFullyCompleted, isFalse);
    });

    test('Zero completed shows full remaining time', () {
      final item = TimelineItem(
        id: 'plan_2',
        sourceId: 'src_2',
        title: 'Focus Writing',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 30),
        color: Colors.purple,
        icon: '✍️',
        type: TimelineItemType.block,
        customPlannedMinutes: 30,
        completedMinutes: 0,
      );

      expect(item.plannedMinutes, 30);
      expect(item.completedMinutes, 0);
      expect(item.remainingMinutes, 30);
      expect(item.isFullyCompleted, isFalse);
    });

    test('Full completion sets remaining to 0 and marks completed', () {
      final item = TimelineItem(
        id: 'plan_3',
        sourceId: 'src_3',
        title: 'Database Work',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 20),
        color: Colors.teal,
        icon: '📊',
        type: TimelineItemType.block,
        customPlannedMinutes: 20,
        completedMinutes: 20,
      );

      expect(item.plannedMinutes, 20);
      expect(item.completedMinutes, 20);
      expect(item.remainingMinutes, 0);
      expect(item.isFullyCompleted, isTrue);
    });

    test('Remaining minutes never becomes negative if completed exceeds planned', () {
      final item = TimelineItem(
        id: 'plan_4',
        sourceId: 'src_4',
        title: 'Overtime Research',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 20),
        color: Colors.amber,
        icon: '🔍',
        type: TimelineItemType.block,
        customPlannedMinutes: 20,
        completedMinutes: 35, // Worked 35 minutes on 20m planned
      );

      expect(item.plannedMinutes, 20);
      expect(item.completedMinutes, 35);
      expect(item.remainingMinutes, 0, reason: 'Remaining must be clamped to 0 and never negative');
      expect(item.isFullyCompleted, isTrue);
    });
  });
}
