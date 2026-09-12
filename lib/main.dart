import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/config/supabase_config.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/services/ad_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/application/notification_service.dart';
import 'features/security/presentation/widgets/app_lock_lifecycle_wrapper.dart';
import 'features/settings/data/repositories/notification_settings_repository.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/widget/services/widget_navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Notifications on Android / native
  final notificationService = NotificationService();
  if (!kIsWeb) {
    try {
      await notificationService.initialize();
    } catch (e) {
      debugPrint('Notification service initialization notice: $e');
    }

    // Initialize Home Screen Widget navigation listener on Android
    WidgetNavigationService.initialize();

    // Initialize Google Mobile Ads SDK safely in background without blocking UI
    unawaited(AdService.initialize());
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSettingsRepositoryProvider
            .overrideWithValue(NotificationSettingsRepository(prefs)),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const TimoraApp(),
    ),
  );
}

class TimoraApp extends ConsumerWidget {
  const TimoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Timora',
      navigatorKey: WidgetNavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        return AppLockLifecycleWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
