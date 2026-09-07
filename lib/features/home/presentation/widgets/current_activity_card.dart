import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/data/models/focus_session_model.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/presentation/providers/task_provider.dart';

class CurrentActivityCard extends ConsumerWidget {
  const CurrentActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(focusTimerProvider);
    final activeSession = timerState.activeSession;
    final isSessionActive = activeSession != null &&
        (activeSession.status == FocusSessionStatus.running ||
            activeSession.status == FocusSessionStatus.breakTime ||
            activeSession.status == FocusSessionStatus.paused);

    final activityAsync = ref.watch(currentActivityProvider);
    final currentTime = ref.watch(currentTimeProvider);
    final format = DateFormat('h:mm a');

    // Case 1: An active Focus Session is ongoing or paused
    if (isSessionActive) {
      final s = activeSession;
      final isPaused = s.status == FocusSessionStatus.paused;
      final remainingSecs = timerState.remainingSeconds;
      final remainingMins = (remainingSecs / 60).ceil();
      final progress = s.plannedDurationSeconds > 0
          ? (timerState.elapsedSeconds / s.plannedDurationSeconds).clamp(0.0, 1.0)
          : 0.0;

      final startStr = format.format(s.startedAt);
      final plannedEnd = s.startedAt.add(Duration(seconds: s.plannedDurationSeconds));
      final endStr = format.format(plannedEnd);

      // Determine task or mode title
      final isBreak = s.status == FocusSessionStatus.breakTime;
      String sessionTitle = 'Focus Session';
      if (s.taskId != null) {
        final allTasks = ref.watch(allTasksProvider).valueOrNull;
        final task = allTasks?.where((t) => t.id == s.taskId).firstOrNull;
        if (task != null && task.title.isNotEmpty) {
          sessionTitle = task.title;
        }
      } else if (s.scheduleActivityId != null) {
        final currentAct = activityAsync.valueOrNull;
        if (currentAct != null && currentAct.id == s.scheduleActivityId) {
          sessionTitle = currentAct.title;
        }
      } else if (isBreak) {
        sessionTitle = 'Break Time';
      } else if (s.mode == FocusSessionMode.pomodoro) {
        sessionTitle = 'Pomodoro Focus';
      } else if (s.mode == FocusSessionMode.custom) {
        sessionTitle = 'Custom Focus';
      } else {
        sessionTitle = 'Deep Focus';
      }

      final tag = isPaused
          ? 'Paused'
          : (isBreak ? 'Rest & Recharge' : 'In Progress');

      final quote = isPaused
          ? 'Session paused. Resume whenever you are ready.'
          : (isBreak
              ? 'Take a breath and step away from the screen.'
              : 'Make time work for you with distraction-free focus');

      return _buildCardContent(
        context: context,
        ref: ref,
        headerLabel: 'CURRENT ACTIVITY',
        title: sessionTitle,
        timeRange: '$startStr – $endStr',
        tag: tag,
        quote: quote,
        remainingMinutes: remainingMins,
        progress: progress,
        iconData: isBreak
            ? Icons.coffee_rounded
            : Icons.laptop_mac_rounded,
        primaryButtonText: isPaused ? 'Resume' : 'Pause',
        primaryButtonIcon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        onPrimaryPressed: () {
          if (isPaused) {
            ref.read(focusTimerProvider.notifier).resumeSession();
          } else {
            ref.read(focusTimerProvider.notifier).pauseSession();
          }
        },
        secondaryButtonText: 'Stop',
        secondaryButtonIcon: Icons.stop_rounded,
        onSecondaryPressed: () async {
          final finished = await ref.read(focusTimerProvider.notifier).stopSession();
          if (context.mounted && finished != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Focused for ${(finished.actualDurationSeconds / 60).round()} min 🎉',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    }

    // Case 2: No active focus session; observe schedule activities
    return activityAsync.when(
      loading: () => _buildCardContent(
        context: context,
        ref: ref,
        headerLabel: 'CURRENT ACTIVITY',
        title: 'Focus Session',
        timeRange: 'Now',
        tag: 'In Progress',
        quote: 'Make time work for you with distraction-free focus',
        remainingMinutes: 25,
        progress: 0.0,
        iconData: Icons.laptop_mac_rounded,
        primaryButtonText: 'Start Focus',
        primaryButtonIcon: Icons.play_arrow_rounded,
        onPrimaryPressed: () {
          ref.read(focusTimerProvider.notifier).startSession(durationMinutes: 25);
        },
        secondaryButtonText: 'Open',
        secondaryButtonIcon: Icons.open_in_new_rounded,
        onSecondaryPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        },
      ),
      error: (_, __) => _buildCardContent(
        context: context,
        ref: ref,
        headerLabel: 'CURRENT ACTIVITY',
        title: 'Ready for Focus',
        timeRange: '25 min session',
        tag: 'Focus Session',
        quote: 'Start a focus block to power through deep work',
        remainingMinutes: 25,
        progress: 0.0,
        iconData: Icons.self_improvement_rounded,
        primaryButtonText: 'Start Focus',
        primaryButtonIcon: Icons.play_arrow_rounded,
        onPrimaryPressed: () {
          ref.read(focusTimerProvider.notifier).startSession(durationMinutes: 25);
        },
        secondaryButtonText: 'Options',
        secondaryButtonIcon: Icons.tune_rounded,
        onSecondaryPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        },
      ),
      data: (activity) {
        if (activity == null) {
          // No current activity scheduled -> display intelligent "What Should I Do Now" recommendation
          final recAsync = ref.watch(whatShouldIDoNowProvider);
          final rec = recAsync.valueOrNull;

          if (rec != null && rec.type != RecommendationType.freeSlotFocus) {
            final isOverdue = rec.type == RecommendationType.overdueTask;
            final isHighPrio = rec.type == RecommendationType.highPriorityTask;
            final tag = isOverdue
                ? 'Action Needed'
                : (isHighPrio ? 'High Priority' : 'Recommended Next');

            return _buildCardContent(
              context: context,
              ref: ref,
              headerLabel: 'WHAT SHOULD I DO NOW',
              title: rec.title,
              timeRange: rec.subtitle,
              tag: tag,
              quote: rec.reason,
              remainingMinutes: rec.duration.inMinutes,
              progress: 0.0,
              iconData: isOverdue ? Icons.warning_amber_rounded : Icons.lightbulb_outline_rounded,
              primaryButtonText: 'Start Focus',
              primaryButtonIcon: Icons.play_arrow_rounded,
              onPrimaryPressed: () {
                final taskId = rec.type == RecommendationType.overdueTask || rec.type == RecommendationType.highPriorityTask
                    ? rec.entityId
                    : null;
                ref.read(focusTimerProvider.notifier).startSession(
                      durationMinutes: rec.duration.inMinutes > 5 ? rec.duration.inMinutes : 25,
                      taskId: taskId,
                    );
              },
              secondaryButtonText: rec.entity is TaskModel ? 'Complete' : 'Schedule',
              secondaryButtonIcon: rec.entity is TaskModel ? Icons.check_circle_outline_rounded : Icons.calendar_today_rounded,
              onSecondaryPressed: () async {
                if (rec.entity is TaskModel) {
                  await ref.read(taskNotifierProvider).completeTask(rec.entity as TaskModel);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Completed "${rec.title}"! 🎉'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
                }
              },
            );
          }

          // General ready-to-focus fallback
          return _buildCardContent(
            context: context,
            ref: ref,
            headerLabel: 'WHAT SHOULD I DO NOW',
            title: 'Free Focus Window',
            timeRange: '25 min session',
            tag: 'Open Window',
            quote: 'No activity scheduled right now. Take 25 minutes of deep focus or review your day.',
            remainingMinutes: 25,
            progress: 0.0,
            iconData: Icons.self_improvement_rounded,
            primaryButtonText: 'Start Focus',
            primaryButtonIcon: Icons.play_arrow_rounded,
            onPrimaryPressed: () {
              ref.read(focusTimerProvider.notifier).startSession(durationMinutes: 25);
            },
            secondaryButtonText: 'Options',
            secondaryButtonIcon: Icons.tune_rounded,
            onSecondaryPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
            },
          );
        }

        final totalDuration = activity.endTime.difference(activity.startTime).inMinutes;
        final elapsed = currentTime.difference(activity.startTime).inMinutes;
        final remaining = activity.endTime.difference(currentTime).inMinutes;
        final progress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;

        return _buildCardContent(
          context: context,
          ref: ref,
          headerLabel: 'CURRENT ACTIVITY',
          title: activity.title,
          timeRange: '${format.format(activity.startTime)} – ${format.format(activity.endTime)}',
          tag: 'In Progress',
          quote: activity.description.isNotEmpty ? activity.description : 'Focus on what matters most today',
          remainingMinutes: remaining > 0 ? remaining : 0,
          progress: progress,
          iconText: activity.icon,
          primaryButtonText: 'Start Focus',
          primaryButtonIcon: Icons.play_arrow_rounded,
          onPrimaryPressed: () {
            final dur = remaining > 5 ? remaining : 25;
            ref.read(focusTimerProvider.notifier).startSession(
                  durationMinutes: dur,
                  scheduleActivityId: activity.id,
                );
          },
          secondaryButtonText: 'Open',
          secondaryButtonIcon: Icons.open_in_new_rounded,
          onSecondaryPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
          },
        );
      },
    );
  }

  Widget _buildCardContent({
    required BuildContext context,
    required WidgetRef ref,
    String? headerLabel,
    required String title,
    required String timeRange,
    required String tag,
    required String quote,
    required int remainingMinutes,
    required double progress,
    IconData? iconData,
    String? iconText,
    required String primaryButtonText,
    required IconData primaryButtonIcon,
    required VoidCallback onPrimaryPressed,
    required String secondaryButtonText,
    required IconData secondaryButtonIcon,
    required VoidCallback onSecondaryPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pctInt = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: Current Activity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1322) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Squircle Icon + Title/Time + 3 dots
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Squircle icon with blue/purple gradient
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: iconText != null && iconText.isNotEmpty
                        ? Text(iconText, style: const TextStyle(fontSize: 26))
                        : Icon(iconData ?? Icons.laptop_mac_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  // Title, Time, and Pill tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (headerLabel != null && headerLabel.isNotEmpty) ...[
                          Text(
                            headerLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          timeRange,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13203D) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              // 3-dots popup menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  size: 20,
                ),
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'focus') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'focus',
                    child: Text(
                      'Open Focus Screen',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Middle row: Subtitle Quote on left + Circular Arc Gauge on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Quote
              Expanded(
                child: Text(
                  '"$quote"',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Circular Arc Gauge
              SizedBox(
                width: 115,
                height: 115,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(115, 115),
                      painter: CircularArcGaugePainter(
                        progress: progress,
                        trackColor: isDark ? const Color(0xFF131B2D) : const Color(0xFFF1F5F9),
                        gradientColors: const [
                          Color(0xFF38BDF8),
                          Color(0xFF818CF8),
                          Color(0xFFA855F7),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$remainingMinutes',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'min',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Remaining',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF94A3B8),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Session Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                '$pctInt%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? const Color(0xFF151D33) : const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons: Primary (gradient) + Secondary (outlined)
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPrimaryPressed,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(primaryButtonIcon, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            primaryButtonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSecondaryPressed,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0C1322) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            secondaryButtonIcon,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            secondaryButtonText,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
      ],
    );
  }
}

/// Custom arc gauge painter for the circular progress gauge
class CircularArcGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> gradientColors;

  CircularArcGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    // Starts at bottom-left (~135 degrees = 2.35 rad), sweeps ~270 degrees = 4.65 rad
    const startAngle = 2.35;
    const sweepAngle = 4.65;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: gradientColors,
        transform: const GradientRotation(startAngle),
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round;

      final currentSweep = sweepAngle * progress.clamp(0.02, 1.0);
      canvas.drawArc(
        rect,
        startAngle,
        currentSweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CircularArcGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.trackColor != trackColor;
  }
}


