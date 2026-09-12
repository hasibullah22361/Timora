import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/biometric_security_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Automatically prompt biometrics when lock screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(biometricSecurityProvider.notifier).authenticateAndUnlock();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final securityState = ref.watch(biometricSecurityProvider);
    final primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: false, // Prevent Android back button bypass
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Fingerprint Container
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 68,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Lock Title
                  Text(
                    'Timora is Locked',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Lock Subtitle
                  Text(
                    'Touch the fingerprint sensor to verify your identity and access your schedule and tasks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status / Error feedback message
                  if (securityState.statusMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              securityState.statusMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(flex: 3),

                  // "Unlock with Biometrics" Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 24),
                      label: Text(
                        securityState.isAuthenticating
                            ? 'Scanning...'
                            : 'Unlock with Biometrics',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      onPressed: securityState.isAuthenticating
                          ? null
                          : () {
                              ref
                                  .read(biometricSecurityProvider.notifier)
                                  .authenticateAndUnlock();
                            },
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
