import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tasks/presentation/screens/task_details_screen.dart';
import '../../focus/presentation/screens/focus_screen.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';

class WidgetNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const MethodChannel _channel = MethodChannel('timora/widget');
  static bool _initialized = false;

  /// Initializes the widget action listener and checks for initial launch actions.
  static void initialize() {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final action = args['action'] as String?;
          final taskId = args['taskId'] as String?;
          handleAction(action, taskId);
        }
      }
    });

    // Check for initial action if app was launched via widget click
    _checkInitialAction();
  }

  static Future<void> _checkInitialAction() async {
    try {
      final dynamic result = await _channel.invokeMethod('getInitialAction');
      if (result is Map) {
        final action = result['action'] as String?;
        final taskId = result['taskId'] as String?;
        if (action != null) {
          // Delay briefly to allow Navigator to attach
          Future.delayed(const Duration(milliseconds: 600), () {
            handleAction(action, taskId);
          });
        }
      }
    } catch (e) {
      debugPrint('[TimoraWidget] Error checking initial widget action: $e');
    }
  }

  static void handleAction(String? action, String? taskId) {
    if (action == null) return;
    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      // Retry once after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleAction(action, taskId);
      });
      return;
    }

    debugPrint('[TimoraWidget] Executing widget action: $action (taskId: $taskId)');

    switch (action) {
      case 'open_task':
        if (taskId != null && taskId.isNotEmpty) {
          Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(taskId: taskId),
            ),
          );
        }
        break;

      case 'start_focus':
        Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => const FocusScreen(),
          ),
        );
        break;

      case 'open_notifications':
        Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        );
        break;

      case 'open_home':
        Navigator.of(navContext).popUntil((route) => route.isFirst);
        break;
    }
  }
}
