import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../streaks/presentation/providers/streak_provider.dart';
import '../../../streaks/data/models/streak_models.dart';
import '../../../streaks/presentation/screens/streaks_screen.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';

class StreaksWidget extends ConsumerWidget {
  const StreaksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusStreakAsync = ref.watch(streakProvider(StreakType.focus));
    final taskStreakAsync = ref.watch(streakProvider(StreakType.task));
    final routineStreakAsync = ref.watch(streakProvider(StreakType.routine));

    final profile = ref.watch(userProfileProvider);
    final displayName = profile.fullName.trim().isNotEmpty
        ? profile.fullName.trim().split(' ').first
        : 'User';

    int streakCount = 0;
    focusStreakAsync.whenData((s) {
      if (s.currentCount > streakCount) streakCount = s.currentCount;
    });
    taskStreakAsync.whenData((s) {
      if (s.currentCount > streakCount) streakCount = s.currentCount;
    });
    routineStreakAsync.whenData((s) {
      if (s.currentCount > streakCount) streakCount = s.currentCount;
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleText = streakCount > 0
        ? 'Keep it up, $displayName!'
        : 'Start a streak, $displayName!';

    final subtitleText = streakCount > 0
        ? "You're building a great habit"
        : 'Complete a task or focus session';

    final emoji = streakCount > 0 ? '🔥' : '⚡';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StreaksScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF221142), Color(0xFF140D2C)]
                  : const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF3B1D73) : const Color(0xFFE9D5FF),
              width: 1.2,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF221142).withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Golden Trophy Icon in circular purple container
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF381A6E) : const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFBBF24),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // User Greeting & Habit Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF581C87),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitleText,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E22CE),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Streak Number + Day Streak + Sparkline
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$streakCount',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Day Streak',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B21A8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Sparkline graph
                  SizedBox(
                    width: 44,
                    height: 28,
                    child: CustomPaint(
                      painter: _SparklinePainter(isDark: isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final bool isDark;

  _SparklinePainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF8B5CF6);
    final endColor = isDark ? Colors.white : const Color(0xFF7E22CE);

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final endDotPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;

    // Upward trending points: (0, 0.85), (0.28, 0.65), (0.52, 0.68), (0.78, 0.30), (1.0, 0.12)
    final points = [
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.28, size.height * 0.65),
      Offset(size.width * 0.52, size.height * 0.68),
      Offset(size.width * 0.78, size.height * 0.30),
      Offset(size.width, size.height * 0.12),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawCircle(points[i], 2.0, dotPaint);
    }
    canvas.drawCircle(points.last, 3.2, endDotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.isDark != isDark;
}


