import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../schedule/services/missed_task_recovery_service.dart';
import '../../../schedule/services/timora_autopilot_service.dart';
import '../../../settings/data/models/settings_models.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class AutopilotBannerWidget extends ConsumerWidget {
  const AutopilotBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly instantiate autopilot loop
    ref.watch(timoraAutopilotServiceProvider);

    final settings = ref.watch(settingsProvider);
    final recommendationsAsync = ref.watch(recoveryRecommendationsProvider);

    return recommendationsAsync.when(
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        final top = recommendations.first;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF31104B)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFFAF5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          settings.autopilotMode == AutopilotMode.fullAutopilot
                              ? 'AUTOPILOT ACTIVE'
                              : 'AUTOPILOT ASSIST',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA78BFA),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      if (top.activity != null) {
                        ref.read(missedTaskRecoveryServiceProvider).dismissMissed(top.activity!);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Missed Task Detected: ${top.title}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                top.reason,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Move to New Slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      await ref.read(missedTaskRecoveryServiceProvider).applyRecovery(top);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Moved "${top.title}" to ${top.reason.split("at ").last}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      if (top.activity != null) {
                        ref.read(missedTaskRecoveryServiceProvider).dismissMissed(top.activity!);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
