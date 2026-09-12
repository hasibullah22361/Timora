import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../security/presentation/providers/biometric_security_provider.dart';
import '../../../security/services/biometric_auth_service.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final securityState = ref.watch(biometricSecurityProvider);
    final securityNotifier = ref.read(biometricSecurityProvider.notifier);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Security & App Lock',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'BIOMETRIC PROTECTION',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Main Fingerprint Lock Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : theme.colorScheme.surface,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: securityState.isEnabled,
                  activeThumbColor: theme.colorScheme.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  title: const Text(
                    'Fingerprint Lock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    securityState.isEnabled
                        ? 'Biometric verification required on launch & resume'
                        : 'Unlock Timora instantly without biometrics',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  onChanged: (bool enable) async {
                    if (enable) {
                      final success = await securityNotifier.enableLock();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Fingerprint Lock enabled.'
                                : securityState.statusMessage ??
                                    'Authentication required to enable lock.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      final success = await securityNotifier.disableLock();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Fingerprint Lock disabled.'
                                : securityState.statusMessage ??
                                    'Authentication required to disable lock.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                // Device Hardware & Enrollment Status Banner
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildHardwareStatusRow(
                    context,
                    securityState.availability,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Informational Security Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secure Native Biometrics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timora delegates authentication directly to Android’s hardware-backed BiometricPrompt system. Fingerprints, biometric patterns, or passwords are never accessed, saved, or uploaded by Timora.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // "Lock Timora Now" quick test button
          if (securityState.isEnabled)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              leading: const Icon(Icons.lock_clock_rounded, color: Colors.amber),
              title: const Text('Lock Timora Now'),
              subtitle: const Text('Test your fingerprint lock immediately'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                securityNotifier.lockApp();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusRow(
    BuildContext context,
    BiometricAvailability availability,
  ) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (availability) {
      case BiometricAvailability.available:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        title = 'Fingerprint Sensor Ready';
        subtitle = 'Device biometric hardware is supported and enrolled.';
        break;
      case BiometricAvailability.noneEnrolled:
        icon = Icons.warning_amber_rounded;
        color = const Color(0xFFF59E0B);
        title = 'No Fingerprints Enrolled';
        subtitle =
            'Register a fingerprint in your device Settings → Security to enable.';
        break;
      case BiometricAvailability.noHardware:
        icon = Icons.highlight_off_rounded;
        color = const Color(0xFFEF4444);
        title = 'No Biometric Sensor Found';
        subtitle =
            'This device does not have hardware-backed biometric authentication.';
        break;
      case BiometricAvailability.notSupported:
        icon = Icons.info_outline_rounded;
        color = Colors.grey;
        title = 'Biometrics Unavailable';
        subtitle =
            'Biometric authentication is not supported in this environment.';
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
