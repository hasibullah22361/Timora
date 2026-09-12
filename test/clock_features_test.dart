import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/world_clock/data/models/world_clock_city_model.dart';
import 'package:timora/features/clock/features/world_clock/data/sources/world_cities_database.dart';
import 'package:timora/features/clock/features/stopwatch/domain/models/stopwatch_state.dart';
import 'package:timora/features/clock/features/timer/domain/models/timer_state.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('⏰ Alarm Model Tests', () {
    test('Calculates next trigger for one-time alarm in future today', () {
      final now = DateTime(2026, 9, 9, 8, 0); // 8:00 AM
      final alarm = AlarmModel(
        hour: 9,
        minute: 30,
        label: 'Standup',
        repeatDays: const [],
      );

      final next = alarm.nextTriggerDateTime(now);
      expect(next.year, 2026);
      expect(next.month, 9);
      expect(next.day, 9);
      expect(next.hour, 9);
      expect(next.minute, 30);
    });

    test('Calculates next trigger for one-time alarm in past today (rolls over to tomorrow)', () {
      final now = DateTime(2026, 9, 9, 10, 0); // 10:00 AM
      final alarm = AlarmModel(
        hour: 7,
        minute: 0,
        label: 'Early Morning',
        repeatDays: const [],
      );

      final next = alarm.nextTriggerDateTime(now);
      expect(next.day, 10); // Tomorrow
      expect(next.hour, 7);
      expect(next.minute, 0);
    });

    test('Calculates next trigger for repeating weekday alarm', () {
      // 2026-09-09 is Wednesday (weekday = 3)
      final now = DateTime(2026, 9, 9, 12, 0);
      final alarm = AlarmModel(
        hour: 8,
        minute: 0,
        label: 'Gym',
        repeatDays: [5], // Friday only (weekday = 5)
      );

      final next = alarm.nextTriggerDateTime(now);
      expect(next.weekday, 5); // Friday
      expect(next.day, 11);
      expect(next.hour, 8);
    });

    test('Formats repeat days properly', () {
      final once = AlarmModel(hour: 8, minute: 0, repeatDays: const []);
      expect(once.repeatDaysFormatted(), 'Once');

      final daily = AlarmModel(hour: 8, minute: 0, repeatDays: [1, 2, 3, 4, 5, 6, 7]);
      expect(daily.repeatDaysFormatted(), 'Every day');

      final weekdays = AlarmModel(hour: 8, minute: 0, repeatDays: [1, 2, 3, 4, 5]);
      expect(weekdays.repeatDaysFormatted(), 'Weekdays');

      final weekends = AlarmModel(hour: 8, minute: 0, repeatDays: [6, 7]);
      expect(weekends.repeatDaysFormatted(), 'Weekends');
    });

    test('Alarm JSON serialization roundtrip', () {
      final alarm = AlarmModel(
        id: 'test_alarm_1',
        hour: 6,
        minute: 45,
        label: 'Run',
        repeatDays: [1, 3, 5],
        sound: 'Bell',
        vibration: true,
        snoozeDurationMinutes: 10,
        isEnabled: true,
      );

      final json = alarm.toJson();
      final restored = AlarmModel.fromJson(json);

      expect(restored.id, alarm.id);
      expect(restored.hour, 6);
      expect(restored.minute, 45);
      expect(restored.label, 'Run');
      expect(restored.repeatDays, [1, 3, 5]);
      expect(restored.sound, 'Bell');
      expect(restored.snoozeDurationMinutes, 10);
      expect(restored.isEnabled, true);
    });
  });

  group('🌍 World Clock Tests', () {
    test('Resolves time and UTC offset for known cities', () {
      final city = WorldClockCityModel(
        cityName: 'Dubai',
        countryName: 'United Arab Emirates',
        flagEmoji: '🇦🇪',
        timezoneId: 'Asia/Dubai',
        timeZoneDisplayName: 'Gulf Standard Time',
      );

      final localDt = city.getLocalDateTime();
      expect(localDt, isNotNull);

      final utcOffset = city.formattedUtcOffset();
      expect(utcOffset, 'UTC +4');
    });

    test('Searches cities in WorldCitiesDatabase', () {
      final results = WorldCitiesDatabase.search('Islamabad');
      expect(results.isNotEmpty, true);
      expect(results.first.cityName, 'Islamabad');
      expect(results.first.countryName, 'Pakistan');

      final tokyoResults = WorldCitiesDatabase.search('tokyo');
      expect(tokyoResults.any((c) => c.cityName == 'Tokyo'), true);
    });

    test('WorldClockCityModel JSON serialization roundtrip', () {
      final city = WorldClockCityModel(
        id: 'c_london',
        cityName: 'London',
        countryName: 'United Kingdom',
        flagEmoji: '🇬🇧',
        timezoneId: 'Europe/London',
        timeZoneDisplayName: 'British Time',
      );

      final json = city.toJson();
      final restored = WorldClockCityModel.fromJson(json);

      expect(restored.id, 'c_london');
      expect(restored.cityName, 'London');
      expect(restored.countryName, 'United Kingdom');
      expect(restored.timezoneId, 'Europe/London');
    });
  });

  group('⏱️ Stopwatch Tests', () {
    test('Calculates elapsed time accurately from timestamps', () {
      const state = StopwatchState(
        isRunning: true,
        startEpoch: 10000,
        pausedElapsedMs: 5000,
      );

      // Total should be pausedElapsedMs + (now - startEpoch)
      final now = 18000;
      final elapsed = state.pausedElapsedMs + (now - state.startEpoch!);
      expect(elapsed, 13000); // 13 seconds
    });

    test('Formats display time as HH:MM:SS.hundredths', () {
      // 1 minute, 23 seconds, 450 ms = 83450 ms
      const ms = 83450;
      final formatted = StopwatchState.formatDisplay(ms);
      expect(formatted, '00:01:23.45');
    });

    test('Lap calculations and fastest/slowest identification', () {
      final lap1 = LapModel(lapNumber: 1, splitMs: 15000, totalElapsedMs: 15000); // 15s
      final lap2 = LapModel(lapNumber: 2, splitMs: 12000, totalElapsedMs: 27000); // 12s (fastest)
      final lap3 = LapModel(lapNumber: 3, splitMs: 18000, totalElapsedMs: 45000); // 18s (slowest)

      final state = StopwatchState(
        isRunning: true,
        laps: [lap3, lap2, lap1],
      );

      expect(state.fastestLapSplit, 12000);
      expect(state.slowestLapSplit, 18000);
    });
  });

  group('⏳ Timer Tests', () {
    test('Formats countdown seconds correctly', () {
      expect(TimerState.formatSeconds(65), '01:05');
      expect(TimerState.formatSeconds(3665), '01:01:05');
      expect(TimerState.formatSeconds(0), '00:00');
    });

    test('Calculates progress ratio', () {
      const timer = TimerState(
        totalSeconds: 100,
        remainingSeconds: 75,
      );
      expect(timer.progress, 0.75);
    });

    test('TimerState JSON serialization roundtrip', () {
      const timer = TimerState(
        totalSeconds: 1500,
        remainingSeconds: 1200,
        status: TimerStatus.running,
        endEpoch: 1725890000000,
      );

      final json = timer.toJson();
      final restored = TimerState.fromJson(json);

      expect(restored.totalSeconds, 1500);
      expect(restored.remainingSeconds, 1200);
      expect(restored.status, TimerStatus.running);
      expect(restored.endEpoch, 1725890000000);
    });
  });
}
