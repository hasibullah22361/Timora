import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../../../routine/presentation/screens/routines_screen.dart';
import '../../../others/presentation/screens/others_screen.dart';
import '../providers/navigation_provider.dart';
import '../../../notifications/application/voice_announcement_service.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../widget/services/widget_update_service.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> with WidgetsBindingObserver {
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const TasksScreen(),
    const RoutinesScreen(),
    const OthersScreen(),
  ];

  VoiceAnnouncementService? _voiceService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _voiceService = ref.read(voiceAnnouncementServiceProvider);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh Home Screen widgets on startup
      _updateWidgets();

      // On Android, scheduled speaking notifications are handled natively by
      // AlarmManager + TimoraSpeakingService in all app states (foreground & background).
      // On other platforms, fallback to in-app polling.
      if (!Platform.isAndroid && _voiceService != null) {
        final scheduleRepo = ref.read(scheduleRepositoryProvider);
        final taskRepo = ref.read(taskRepositoryProvider);

        _voiceService!.startScheduleMonitoring(
          () async {
            final now = DateTime.now();
            final date = DateTime(now.year, now.month, now.day);
            return await scheduleRepo.getActivitiesForDate(date);
          },
          getTasks: () async {
            return await taskRepo.getTasks();
          },
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidgets();
    }
  }

  void _updateWidgets() {
    try {
      ref.read(widgetUpdateServiceProvider).updateWidgets();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _voiceService?.stopScheduleMonitoring();
    } catch (_) {}
    super.dispose();
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) return;

    final currentIndex = ref.read(navigationIndexProvider);
    // If on a secondary tab, return to Home (Tab 0)
    if (currentIndex != 0) {
      ref.read(navigationIndexProvider.notifier).state = 0;
      return;
    }

    // If on Home (Tab 0), require double back-press to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit Timora'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = ref.watch(navigationIndexProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(navigationIndexProvider.notifier).state = index;
          },
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.task_alt_outlined),
              selectedIcon: Icon(Icons.task_alt_rounded),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.repeat_outlined),
              selectedIcon: Icon(Icons.repeat_rounded),
              label: 'Routines',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Others',
            ),
          ],
        ),
      ),
    );
  }
}
