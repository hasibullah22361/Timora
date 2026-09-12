import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/home/presentation/screens/home_screen.dart';
import 'package:timora/features/home/presentation/screens/timora_search_screen.dart';
import 'package:timora/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:timora/features/settings/presentation/screens/settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Home Notification Button & Search Verification', () {
    testWidgets('1. Home header contains Profile, Search, and Notifications buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Profile avatar button is present
      expect(find.byKey(const Key('home_profile_button')), findsOneWidget);

      // Search button is present
      expect(find.byKey(const Key('home_search_button')), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsWidgets);

      // Notifications button is present
      expect(find.byKey(const Key('home_notifications_button')), findsOneWidget);
    });

    testWidgets('2. Tapping Home notification button navigates to NotificationsScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('home_notifications_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('3. Notification Center contains Clear All and does NOT contain Notification Settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clear All button is present in Notification Center
      expect(find.byKey(const Key('clear_all_notifications_button')), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Notification Settings (tune icon) is NOT inside Notification Center
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      expect(find.byType(NotificationSettingsScreen), findsNothing);
    });

    testWidgets('4. Notification Settings remains accessible in Main Settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Notifications & Spoken Announcements tile exists in Main Settings
      expect(find.text('Notifications & Spoken Announcements'), findsOneWidget);
    });

    testWidgets('5. Tapping Search button on Home opens TimoraSearchScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('home_search_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TimoraSearchScreen), findsOneWidget);
      expect(find.byKey(const Key('global_search_input')), findsOneWidget);
    });

    testWidgets('6. TimoraSearchScreen displays real search results for tasks and features', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final task = TaskModel(
        id: 'test_task_search_1',
        title: 'Complete Architecture Spec',
        description: 'Review system design guidelines for Timora',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        status: TaskStatus.pending,
        category: 'Work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            allTasksProvider.overrideWith((ref) async => [task]),
          ],
          child: const MaterialApp(
            home: TimoraSearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byKey(const Key('global_search_input')), 'Architecture');
      await tester.pumpAndSettle();

      expect(find.text('Complete Architecture Spec'), findsOneWidget);

      // Search for an app tool
      await tester.enterText(find.byKey(const Key('global_search_input')), 'Clock');
      await tester.pumpAndSettle();

      expect(find.text('⏰ Clock Suite'), findsOneWidget);
    });

    testWidgets('7. Profile button is positioned at the far right of the Home header and tapping it opens ProfileScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final profileOffset = tester.getTopLeft(find.byKey(const Key('home_profile_button')));
      final searchOffset = tester.getTopLeft(find.byKey(const Key('home_search_button')));
      final notificationsOffset = tester.getTopLeft(find.byKey(const Key('home_notifications_button')));

      // Profile is at the far right: profileOffset.dx > notificationsOffset.dx > searchOffset.dx
      expect(profileOffset.dx > notificationsOffset.dx, isTrue, reason: 'Profile must be to the right of Notifications');
      expect(notificationsOffset.dx > searchOffset.dx, isTrue, reason: 'Notifications must be to the right of Search');

      // Tapping opens ProfileScreen
      await tester.tap(find.byKey(const Key('home_profile_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
