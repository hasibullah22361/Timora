import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/presentation/providers/alarm_provider.dart';
import 'package:timora/features/clock/features/alarm/services/alarm_service.dart';

class AlarmRingingScreen extends ConsumerStatefulWidget {
  final String alarmId;
  final String title;
  final String timeFormatted;
  final int snoozeMinutes;

  const AlarmRingingScreen({
    super.key,
    required this.alarmId,
    this.title = 'Alarm',
    this.timeFormatted = '',
    this.snoozeMinutes = 5,
  });

  @override
  ConsumerState<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends ConsumerState<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _currentTime;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHandlingAction = false;
  bool _isSilenced = false;
  StreamSubscription? _silenceSubscription;
  StreamSubscription? _dismissSubscription;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to native Power button / screen off silencing events
    _silenceSubscription =
        AlarmService.onAlarmSilencedStream.listen((silencedId) {
      if ((silencedId == widget.alarmId || silencedId.isEmpty) && mounted) {
        setState(() {
          _isSilenced = true;
        });
        _pulseController.stop();
      }
    });

    // Listen to native notification STOP / SNOOZE actions to keep shared state
    _dismissSubscription =
        AlarmService.onAlarmDismissedStream.listen((data) {
      if (data['alarmId'] == widget.alarmId && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _silenceSubscription?.cancel();
    _dismissSubscription?.cancel();
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleStop() async {
    if (_isHandlingAction) return;
    _isHandlingAction = true;
    HapticFeedback.heavyImpact();

    final alarmService = ref.read(alarmServiceProvider);
    await alarmService.stopAlarmSound();

    // Disable one-time alarm in the repository/notifier
    final alarms = ref.read(alarmsListProvider);
    final current = alarms.where((a) => a.id == widget.alarmId).firstOrNull;
    if (current != null && !current.isRepeating) {
      final disabled = current.copyWith(isEnabled: false);
      await ref.read(alarmsListProvider.notifier).updateAlarm(disabled);
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _handleSnooze() async {
    if (_isHandlingAction) return;
    _isHandlingAction = true;
    HapticFeedback.mediumImpact();

    final alarmService = ref.read(alarmServiceProvider);
    await alarmService.stopAlarmSound();

    final alarms = ref.read(alarmsListProvider);
    final current = alarms.where((a) => a.id == widget.alarmId).firstOrNull;
    if (current != null) {
      await ref
          .read(alarmsListProvider.notifier)
          .snooze(current, minutes: widget.snoozeMinutes);
    } else {
      // Fallback snooze directly on service
      final tempAlarm = AlarmModel(
        id: widget.alarmId,
        hour: _currentTime.hour,
        minute: _currentTime.minute,
        label: widget.title,
        snoozeDurationMinutes: widget.snoozeMinutes,
      );
      await alarmService.snoozeAlarm(tempAlarm,
          snoozeMinutes: widget.snoozeMinutes);
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm').format(_currentTime);
    final amPmStr = DateFormat('a').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(_currentTime);

    final statusColor =
        _isSilenced ? const Color(0xFFF59E0B) : Colors.redAccent;
    final statusText = _isSilenced ? 'ALARM SILENCED' : 'ALARM RINGING';

    return PopScope(
      canPop: false, // Prevent back button accidental dismissal
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0F18),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Ringing / Silenced Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isSilenced)
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.volume_off_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                              const SizedBox(width: 10),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Bell Icon Hero (Pulsing when ringing, steady when silenced)
                        ScaleTransition(
                          scale: _isSilenced
                              ? const AlwaysStoppedAnimation(1.0)
                              : _pulseAnimation,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor.withValues(alpha: 0.12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor.withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                  boxShadow: _isSilenced
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: statusColor
                                                .withValues(alpha: 0.3),
                                            blurRadius: 24,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                ),
                                child: Icon(
                                  _isSilenced
                                      ? Icons.notifications_off_rounded
                                      : Icons.alarm_on_rounded,
                                  size: 42,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Alarm Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            widget.title.isNotEmpty ? widget.title : 'Alarm',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Scheduled Time
                        if (widget.timeFormatted.isNotEmpty)
                          Text(
                            'Scheduled for ${widget.timeFormatted}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                        const Spacer(),

                        // Live Current Time Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              amPmStr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        // Two Large Swipe Controls: SNOOZE and STOP
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Swipe Up to Snooze
                              Expanded(
                                child: SwipeUpActionControl(
                                  label: 'Swipe Up to Snooze',
                                  subtitle: '+${widget.snoozeMinutes} min',
                                  accentColor: const Color(0xFFF59E0B),
                                  icon: Icons.snooze_rounded,
                                  onTriggered: _handleSnooze,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Swipe Up to Stop
                              Expanded(
                                child: SwipeUpActionControl(
                                  label: 'Swipe Up to Stop',
                                  subtitle: 'Dismiss',
                                  accentColor: const Color(0xFFEF4444),
                                  icon: Icons.alarm_off_rounded,
                                  onTriggered: _handleStop,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Large vertical swipe-up control with direct, zero-friction upward swipe.
/// Triggers directly on upward drag past threshold or upward flick with velocity.
class SwipeUpActionControl extends StatefulWidget {
  final String label;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final Future<void> Function() onTriggered;

  const SwipeUpActionControl({
    super.key,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    required this.onTriggered,
  });

  @override
  State<SwipeUpActionControl> createState() => _SwipeUpActionControlState();
}

class _SwipeUpActionControlState extends State<SwipeUpActionControl>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  static const double _maxDragDistance = 80.0;
  static const double _triggerThreshold = 50.0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    )..addListener(() {
        setState(() {
          _dragOffset = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_hasTriggered) return;
    setState(() {
      // Dragging upward means negative delta
      _dragOffset = (_dragOffset - details.primaryDelta!)
          .clamp(0.0, _maxDragDistance);
    });

    if (_dragOffset >= _triggerThreshold && !_hasTriggered) {
      _hasTriggered = true;
      widget.onTriggered();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_hasTriggered) return;
    final velocity = details.primaryVelocity;
    // Direct trigger if dragged past threshold OR flicked upward with velocity
    if (_dragOffset >= _triggerThreshold ||
        (velocity != null && velocity < -200)) {
      _hasTriggered = true;
      widget.onTriggered();
    } else {
      // Snap back smoothly
      _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
      );
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _maxDragDistance).clamp(0.0, 1.0);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.3 + 0.5 * progress),
          width: 1.5,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Top guide arrows / label
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_double_arrow_up_rounded,
                    color: widget.accentColor
                        .withValues(alpha: 0.6 + 0.4 * progress),
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Draggable Knob at Bottom
            Positioned(
              bottom: 12 + _dragOffset,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor
                          .withValues(alpha: 0.4 + 0.4 * progress),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
