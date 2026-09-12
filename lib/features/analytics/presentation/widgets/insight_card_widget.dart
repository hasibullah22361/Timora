import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/analytics_models.dart';
import '../../services/insight_action_service.dart';
import '../../../daily_plan/presentation/screens/daily_plan_screen.dart';
import '../../../routine/presentation/screens/routines_screen.dart';
import '../../../focus/presentation/screens/focus_screen.dart';

class InsightCardWidget extends ConsumerStatefulWidget {
  final AnalyticsInsight insight;
  final bool isCompact;

  const InsightCardWidget({
    super.key,
    required this.insight,
    this.isCompact = false,
  });

  @override
  ConsumerState<InsightCardWidget> createState() => _InsightCardWidgetState();
}

class _InsightCardWidgetState extends ConsumerState<InsightCardWidget> {
  bool _isExecuting = false;

  Color _getCategoryColor(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.productivityPattern:
        return const Color(0xFF6366F1); // Indigo
      case InsightCategory.scheduleEffectiveness:
        return const Color(0xFF3B82F6); // Blue
      case InsightCategory.routineConsistency:
        return const Color(0xFFEC4899); // Pink
      case InsightCategory.missedTask:
        return const Color(0xFFF59E0B); // Amber
      case InsightCategory.trend:
        return const Color(0xFF10B981); // Emerald
      case InsightCategory.general:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  String _getCategoryLabel(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.productivityPattern:
        return 'PRODUCTIVITY INSIGHT';
      case InsightCategory.scheduleEffectiveness:
        return 'SCHEDULE EFFECTIVENESS';
      case InsightCategory.routineConsistency:
        return 'ROUTINE CONSISTENCY';
      case InsightCategory.missedTask:
        return 'TASK ATTENTION ALERT';
      case InsightCategory.trend:
        return 'PERFORMANCE TREND';
      case InsightCategory.general:
        return 'TIMORA INTELLIGENCE';
    }
  }

  Future<void> _handleAction() async {
    if (_isExecuting) return;
    setState(() => _isExecuting = true);

    try {
      final actionService = ref.read(insightActionServiceProvider);
      final result = await actionService.executeAction(widget.insight);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );

      if (result.navigationTarget == 'daily_plan') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
      } else if (result.navigationTarget == 'routines') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutinesScreen()));
      } else if (result.navigationTarget == 'focus') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _getCategoryColor(widget.insight.category);
    final isCompact = widget.isCompact;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 0 : 14),
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.insight.hasSufficientData
              ? color.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Category Badge + Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.insight.icon,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _getCategoryLabel(widget.insight.category),
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!widget.insight.hasSufficientData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Learning Rhythm',
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Title
          Text(
            widget.insight.title,
            style: TextStyle(
              fontSize: isCompact ? 14.5 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Core Finding / Description
          Text(
            widget.insight.description,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              height: 1.35,
            ),
          ),

          // Detailed Explanation ("What does this mean?")
          if (!isCompact && widget.insight.explanation.isNotEmpty && widget.insight.explanation != widget.insight.description) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155).withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊',
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.insight.explanation,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actionable Recommendation ("What to do differently")
          if (widget.insight.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.insight.recommendation,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Button
          if (widget.insight.actionType != InsightActionType.none && widget.insight.actionLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: _isExecuting ? null : _handleAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isExecuting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getActionIcon(widget.insight.actionType),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.insight.actionLabel!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getActionIcon(InsightActionType type) {
    switch (type) {
      case InsightActionType.rescheduleTask:
        return Icons.event_repeat_rounded;
      case InsightActionType.scheduleFocusBlock:
        return Icons.lock_clock_rounded;
      case InsightActionType.planTomorrow:
        return Icons.calendar_month_rounded;
      case InsightActionType.startFocusSession:
        return Icons.play_arrow_rounded;
      case InsightActionType.reviewRoutines:
        return Icons.repeat_rounded;
      case InsightActionType.none:
        return Icons.check;
    }
  }
}
