import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/routine/application/routine_scheduler_service.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';

final currentTimeProvider = StateNotifierProvider<CurrentTimeNotifier, DateTime>((ref) {
  return CurrentTimeNotifier();
});

class CurrentTimeNotifier extends StateNotifier<DateTime> {
  Timer? _timer;

  CurrentTimeNotifier({bool? startTimer}) : super(DateTime.now()) {
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final shouldStart = startTimer ?? (!inTest);
    if (shouldStart) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        state = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final greetingProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  final hour = now.hour;
  if (hour < 12) {
    return 'Good Morning';
  } else if (hour < 17) {
    return 'Good Afternoon';
  } else {
    return 'Good Evening';
  }
});

final formattedDateProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  return DateFormat('EEEE, MMMM d').format(now);
});

final formattedTimeProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  return DateFormat('h:mm a').format(now);
});

final dailyScheduleProvider = FutureProvider<List<ScheduleActivity>>((ref) async {
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day);
  final scheduler = ref.watch(routineSchedulerServiceProvider);
  await scheduler.generateScheduleForDate(date);
  final repo = ref.watch(scheduleRepositoryProvider);
  return await repo.getActivitiesForDate(date);
});

final currentActivityProvider = Provider<AsyncValue<ScheduleActivity?>>((ref) {
  final now = ref.watch(currentTimeProvider);
  final scheduleAsync = ref.watch(dailyScheduleProvider);
  
  return scheduleAsync.whenData((schedule) {
    try {
      return schedule.firstWhere((activity) {
        return (now.isAfter(activity.startTime) || now.isAtSameMomentAs(activity.startTime)) &&
            now.isBefore(activity.endTime);
      });
    } catch (_) {
      return null;
    }
  });
});

final nextActivityProvider = Provider<AsyncValue<ScheduleActivity?>>((ref) {
  final now = ref.watch(currentTimeProvider);
  final scheduleAsync = ref.watch(dailyScheduleProvider);
  
  return scheduleAsync.whenData((schedule) {
    try {
      return schedule.firstWhere((activity) => activity.startTime.isAfter(now));
    } catch (_) {
      return null;
    }
  });
});


