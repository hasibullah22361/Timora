import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/biometric_security_provider.dart';
import '../screens/biometric_lock_screen.dart';

/// Wraps the root application with Android lifecycle monitoring and privacy shielding.
/// Automatically locks Timora when returning from background if Fingerprint Lock is enabled.
class AppLockLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockLifecycleWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLockLifecycleWrapper> createState() =>
      _AppLockLifecycleWrapperState();
}

class _AppLockLifecycleWrapperState extends ConsumerState<AppLockLifecycleWrapper>
    with WidgetsBindingObserver {
  DateTime? _pausedTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedTimestamp;
      _pausedTimestamp = null;

      final securityNotifier = ref.read(biometricSecurityProvider.notifier);
      final securityState = ref.read(biometricSecurityProvider);

      if (securityState.isEnabled) {
        // Lock app upon returning from background
        if (pausedAt != null) {
          securityNotifier.lockApp();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(biometricSecurityProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Completely shield private content when locked while maintaining navigation state
        Visibility(
          visible: !securityState.isLocked,
          maintainState: true,
          child: widget.child,
        ),
        if (securityState.isLocked)
          const Positioned.fill(
            child: BiometricLockScreen(),
          ),
      ],
    );
  }
}
