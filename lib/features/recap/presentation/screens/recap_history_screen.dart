import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/recap/domain/models/recap_models.dart';
import 'package:timora/features/recap/data/repositories/recap_repository.dart';
import 'package:timora/features/recap/presentation/screens/recap_screen.dart';

class RecapHistoryScreen extends ConsumerStatefulWidget {
  const RecapHistoryScreen({super.key});

  @override
  ConsumerState<RecapHistoryScreen> createState() => _RecapHistoryScreenState();
}

class _RecapHistoryScreenState extends ConsumerState<RecapHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recap History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecapHistoryList(type: RecapType.daily),
          _RecapHistoryList(type: RecapType.weekly),
          _RecapHistoryList(type: RecapType.monthly),
        ],
      ),
    );
  }
}

class _RecapHistoryList extends ConsumerWidget {
  final RecapType type;

  const _RecapHistoryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recapRepositoryProvider);

    return FutureBuilder<List<TimoraRecapModel>>(
      future: repo.getRecapsByType(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final recaps = snapshot.data ?? [];
        if (recaps.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'No ${type.name} recaps saved yet.',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recaps are automatically generated at scheduled review times.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recaps.length,
          itemBuilder: (context, index) {
            final recap = recaps[index];
            final dateStr = type == RecapType.daily
                ? DateFormat('EEEE, MMMM d, yyyy').format(recap.targetDate)
                : (type == RecapType.weekly
                    ? 'Week of ${DateFormat('MMM d').format(recap.periodStart)} – ${DateFormat('MMM d, yyyy').format(recap.periodEnd)}'
                    : DateFormat('MMMM yyyy').format(recap.targetDate));

            final score = recap.productivityScore.round();
            final h = recap.focusMinutes ~/ 60;
            final m = recap.focusMinutes % 60;
            final focusText = h > 0 ? '${h}h ${m}m' : '${m}m';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecapScreen(
                        recapType: recap.type,
                        targetDate: recap.targetDate,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (score >= 80
                                      ? const Color(0xFF10B981)
                                      : (score >= 60
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFFF59E0B)))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$score% Score',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: score >= 80
                                    ? const Color(0xFF10B981)
                                    : (score >= 60
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recap.notificationBody,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniBadge(Icons.check_circle_outline,
                              '${recap.completedTasks} Tasks'),
                          const SizedBox(width: 8),
                          _buildMiniBadge(Icons.timer_outlined, focusText),
                          const Spacer(),
                          const Text('View Details →',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
