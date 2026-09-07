import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/productivity_event_model.dart';
import '../../data/repositories/productivity_event_repository.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/data/models/focus_session_model.dart';

class ProductivityHeatmapWidget extends ConsumerWidget {
  const ProductivityHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final eventsAsync = ref.watch(productivityEventRepositoryProvider).getAllEvents();
    final focusSessionsAsync = ref.watch(allFocusSessionsProvider.future);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([eventsAsync, focusSessionsAsync]),
      builder: (context, snapshot) {
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final timeSlots = ['Morning\n6-12', 'Afternoon\n12-17', 'Evening\n17-21', 'Night\n21-24'];

        // 7 days x 4 time blocks matrix
        final matrix = List.generate(7, (_) => List.generate(4, (_) => 0));

        if (snapshot.hasData) {
          final events = snapshot.data![0] as List<ProductivityEventModel>;
          final sessions = snapshot.data![1] as List<FocusSessionModel>;

          for (final e in events) {
            final weekdayIndex = e.timestamp.weekday - 1;
            final slotIndex = _getSlotIndex(e.timestamp.hour);
            matrix[weekdayIndex][slotIndex] += 1;
          }

          for (final s in sessions) {
            if (s.status == FocusSessionStatus.completed) {
              final weekdayIndex = s.createdAt.weekday - 1;
              final slotIndex = _getSlotIndex(s.createdAt.hour);
              matrix[weekdayIndex][slotIndex] += 2;
            }
          }
        }

        // Determine most productive slot
        int maxVal = -1;
        int peakDay = 0;
        int peakSlot = 0;
        for (int d = 0; d < 7; d++) {
          for (int s = 0; s < 4; s++) {
            if (matrix[d][s] > maxVal) {
              maxVal = matrix[d][s];
              peakDay = d;
              peakSlot = s;
            }
          }
        }

        final peakSlotNames = ['between 9 AM and 12 PM', 'between 1 PM and 4 PM', 'between 6 PM and 8 PM', 'late evening'];
        final peakInsight = maxVal > 0
            ? 'You are most productive on ${days[peakDay]}s ${peakSlotNames[peakSlot]}.'
            : 'Complete focused sessions and scheduled activities to populate your heatmap.';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Productivity Heatmap',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      _legendBox(const Color(0xFF1E293B), '0', isDark),
                      const SizedBox(width: 4),
                      _legendBox(const Color(0xFF6366F1).withValues(alpha: 0.4), 'Low', isDark),
                      const SizedBox(width: 4),
                      _legendBox(const Color(0xFF6366F1).withValues(alpha: 0.75), 'Med', isDark),
                      const SizedBox(width: 4),
                      _legendBox(const Color(0xFF4F46E5), 'High', isDark),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Heatmap Table Grid
              Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(42),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      const SizedBox(),
                      for (final slot in timeSlots)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            slot,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (int d = 0; d < 7; d++)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            days[d],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        for (int s = 0; s < 4; s++)
                          Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: _cell(matrix[d][s], isDark),
                          ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B101B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights, color: Color(0xFF6366F1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peakInsight,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _getSlotIndex(int hour) {
    if (hour >= 6 && hour < 12) return 0;
    if (hour >= 12 && hour < 17) return 1;
    if (hour >= 17 && hour < 21) return 2;
    return 3;
  }

  Widget _cell(int value, bool isDark) {
    Color color;
    if (value == 0) {
      color = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
    } else if (value <= 2) {
      color = const Color(0xFF6366F1).withValues(alpha: 0.35);
    } else if (value <= 5) {
      color = const Color(0xFF6366F1).withValues(alpha: 0.7);
    } else {
      color = const Color(0xFF4F46E5);
    }

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _legendBox(Color color, String label, bool isDark) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
