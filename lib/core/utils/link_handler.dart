import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/main_layout/presentation/providers/navigation_provider.dart';
import '../../features/clock/presentation/screens/clock_home_screen.dart';
import '../../features/analytics/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/tasks/presentation/screens/task_details_screen.dart';

class LinkHandler {
  LinkHandler._();

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s\)]+)',
    caseSensitive: false,
  );

  /// Checks if a given string is an HTTP or HTTPS URL.
  static bool isExternalUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Extracts external URLs embedded within text.
  static List<String> extractUrls(String text) {
    if (text.isEmpty) return [];
    return _urlRegex
        .allMatches(text)
        .map((m) => m.group(0) ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Opens an external URL in the system browser.
  static Future<bool> launchExternalUrl(
    String rawUrl, {
    BuildContext? context,
  }) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;

    Uri? uri;
    try {
      uri = Uri.tryParse(trimmed);
      if (uri == null ||
          (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
        debugPrint('[LinkHandler] Invalid HTTP/S URL: $rawUrl');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid link address.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return false;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        debugPrint('[LinkHandler] Could not launch URL: $uri');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open web browser for this link.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[LinkHandler] Exception launching $rawUrl: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Unable to open link: ${e.toString().split('\n').first}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  /// Unified router that handles both external HTTP/S links and internal Timora deep links.
  static Future<void> handleLink(
    BuildContext context,
    WidgetRef ref,
    String? rawLink,
  ) async {
    if (rawLink == null || rawLink.trim().isEmpty) return;
    final trimmed = rawLink.trim();

    // 1. Check if external URL
    if (isExternalUrl(trimmed)) {
      await launchExternalUrl(trimmed, context: context);
      return;
    }

    // 2. Handle Timora internal deep link or keyword route
    final clean = trimmed.replaceFirst('timora://', '').toLowerCase().trim();

    if (clean.startsWith('clock') || clean.startsWith('alarm')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClockHomeScreen()),
      );
      return;
    }

    if (clean.startsWith('report')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportsScreen()),
      );
      return;
    }

    if (clean.startsWith('notification')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }

    if (clean.startsWith('setting')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
      );
      return;
    }

    if (clean.startsWith('task')) {
      final parts = clean.split('/');
      if (parts.length > 1 && parts[1].isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(taskId: parts[1])),
        );
        return;
      }
      ref.read(navigationIndexProvider.notifier).state = 2; // Tasks tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (clean.startsWith('schedule') || clean.startsWith('activit')) {
      ref.read(navigationIndexProvider.notifier).state = 1; // Schedule tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (clean.startsWith('routine')) {
      ref.read(navigationIndexProvider.notifier).state = 3; // Routine tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (clean.startsWith('home')) {
      ref.read(navigationIndexProvider.notifier).state = 0; // Home tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (clean.startsWith('clock') ||
        clean.startsWith('alarm') ||
        clean.startsWith('timer') ||
        clean.startsWith('stopwatch')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClockHomeScreen()),
      );
      return;
    }

    if (clean.startsWith('other')) {
      ref.read(navigationIndexProvider.notifier).state = 4; // Others tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // Fallback: If it has an embedded URL inside text, launch it
    final embedded = extractUrls(trimmed);
    if (embedded.isNotEmpty) {
      await launchExternalUrl(embedded.first, context: context);
      return;
    }

    debugPrint('[LinkHandler] Unrecognized link format: $trimmed');
  }
}
