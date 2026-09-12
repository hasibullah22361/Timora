import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../focus/presentation/screens/focus_history_screen.dart';
import '../../../ambient_sound/presentation/screens/ambient_sounds_screen.dart';

class FocusDashboardWidget extends ConsumerWidget {
  const FocusDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Focus Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                context: context,
                title: 'Focus State',
                subtitle: 'Active / Deep',
                icon: Icons.play_circle_outline_rounded,
                iconColor: const Color(0xFF22C55E),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FocusScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolCard(
                context: context,
                title: 'Pomodoro',
                subtitle: '25 / 5 min',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFA855F7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FocusScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolCard(
                context: context,
                title: 'Focus History',
                subtitle: 'Logs & Stats',
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFF97316),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FocusHistoryScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolCard(
                context: context,
                title: 'Focus Music',
                subtitle: 'Ambient',
                icon: Icons.headphones_outlined,
                iconColor: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AmbientSoundsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1322) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF172033) : const Color(0xFFE2E8F0),
              width: 1,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
