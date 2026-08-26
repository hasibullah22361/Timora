import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/main.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';

void main() {
  testWidgets('Timora App Smoke Test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationSettingsRepositoryProvider.overrideWithValue(
            NotificationSettingsRepository(prefs),
          ),
        ],
        child: const TimoraApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(TimoraApp), findsOneWidget);
  });
}
