import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../../../routine/presentation/screens/routines_screen.dart';
import '../../../others/presentation/screens/others_screen.dart';
import '../providers/navigation_provider.dart';
import '../../../notifications/application/engine/platform_notification_factory.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../widget/services/widget_update_service.dart';
import '../../../cloud_sync/services/sync_service.dart';


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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh Home Screen widgets on startup on native platforms
      _updateWidgets();

      // Initialize NotificationEngine (Web scheduler or native Android notification channels)
      final engine = ref.read(notificationEngineProvider);
      engine.initialize();

      // On Web, start in-app schedule monitoring loop via NotificationEngine
      if (kIsWeb) {
        final scheduleRepo = ref.read(scheduleRepositoryProvider);
        final taskRepo = ref.read(taskRepositoryProvider);

        engine.startScheduleMonitoring(
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

      // Automatically trigger sync on layout load to ensure cloud data is fresh
      ref.read(syncServiceProvider).syncNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidgets();
    }
  }

  void _updateWidgets() {
    if (!kIsWeb) {
      try {
        ref.read(widgetUpdateServiceProvider).updateWidgets();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      ref.read(notificationEngineProvider).stopScheduleMonitoring();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 900;

        if (isWideScreen) {
          final isExpanded = constraints.maxWidth >= 1100;
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) {
                    ref.read(navigationIndexProvider.notifier).state = index;
                  },
                  extended: isExpanded,
                  minExtendedWidth: 200,
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const SizedBox(width: 12),
                          Text(
                            'TIMORA',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today_rounded),
                      label: Text('Schedule'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.task_alt_outlined),
                      selectedIcon: Icon(Icons.task_alt_rounded),
                      label: Text('Tasks'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.repeat_outlined),
                      selectedIcon: Icon(Icons.repeat_rounded),
                      label: Text('Routines'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: Text('Others'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1300),
                      child: IndexedStack(
                        index: currentIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isDark = theme.brightness == Brightness.dark;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF070B14) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF131B2C) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  ref.read(navigationIndexProvider.notifier).state = index;
                },
                backgroundColor: isDark ? const Color(0xFF070B14) : Colors.white,
                elevation: 0,
                height: 65,
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
                    icon: Icon(Icons.check_box_outlined),
                    selectedIcon: Icon(Icons.check_box_rounded),
                    label: 'Tasks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.sync_rounded),
                    selectedIcon: Icon(Icons.sync_rounded),
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
          ),
        );
      },
    );
  }
}
