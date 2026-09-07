import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/career_milestone_model.dart';
import '../../data/repositories/career_roadmap_repository.dart';

class CareerRoadmapScreen extends ConsumerStatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  ConsumerState<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends ConsumerState<CareerRoadmapScreen> {
  @override
  Widget build(BuildContext context) {
    final roadmapAsync = ref.watch(activeRoadmapProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Career Roadmap', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: roadmapAsync.valueOrNull != null
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text('Add Milestone', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddMilestoneSheet(context, roadmapAsync.valueOrNull!.id),
            )
          : null,
      body: roadmapAsync.when(
        data: (roadmap) {
          if (roadmap == null) {
            return const Center(child: Text('No active roadmap'));
          }

          final milestonesAsync = ref.watch(roadmapMilestonesProvider(roadmap.id));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
            children: [
              // Hero Roadmap Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2E1065), const Color(0xFF1E1B4B)]
                        : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roadmap.targetRole.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5CF6),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${roadmap.progress.round()}% Completed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      roadmap.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      roadmap.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (roadmap.progress / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFDDD6FE),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // AI Career Intelligence Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timora Career Intelligence',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You completed Python Programming. Focus on Mathematical Foundations and Classic ML this week to progress toward your target role.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Text(
                'Milestone Pathway',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              milestonesAsync.when(
                data: (milestones) {
                  return Column(
                    children: [
                      for (int i = 0; i < milestones.length; i++)
                        _buildMilestoneNode(context, milestones[i], i + 1, isDark),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMilestoneNode(BuildContext context, CareerMilestoneModel milestone, int index, bool isDark) {
    final isCompleted = milestone.progress >= 100 || milestone.status == CareerMilestoneStatus.completed;
    final isInProgress = milestone.progress > 0 && milestone.progress < 100;

    Color nodeColor = const Color(0xFF64748B);
    if (isCompleted) nodeColor = const Color(0xFF10B981);
    if (isInProgress) nodeColor = const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: nodeColor.withValues(alpha: 0.15),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Color(0xFF10B981))
                    : Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nodeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  milestone.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: nodeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : (isInProgress ? '${milestone.progress}%' : 'NOT STARTED'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: nodeColor,
                  ),
                ),
              ),
            ],
          ),
          if (milestone.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38.0),
              child: Text(
                milestone.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 38.0),
            child: Row(
              children: [
                if (!isCompleted && milestone.linkedTaskId == null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_task, size: 14, color: Color(0xFF8B5CF6)),
                    label: const Text('Add to Tasks', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6))),
                    onPressed: () async {
                      await ref.read(careerRoadmapRepositoryProvider).convertMilestoneToTimoraTask(milestone);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${milestone.title}" to your Tasks & Schedule!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                if (milestone.linkedTaskId != null)
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        'Connected to Schedule',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                PopupMenuButton<int>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B101B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Set Progress', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                  onSelected: (val) async {
                    await ref.read(careerRoadmapRepositoryProvider).saveMilestone(
                          milestone.copyWith(
                            progress: val,
                            status: val >= 100
                                ? CareerMilestoneStatus.completed
                                : (val > 0 ? CareerMilestoneStatus.inProgress : CareerMilestoneStatus.notStarted),
                          ),
                        );
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 0, child: Text('0% (Not Started)')),
                    const PopupMenuItem(value: 25, child: Text('25% (Started)')),
                    const PopupMenuItem(value: 50, child: Text('50% (Halfway)')),
                    const PopupMenuItem(value: 75, child: Text('75% (Advanced)')),
                    const PopupMenuItem(value: 100, child: Text('100% (Completed)')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMilestoneSheet(BuildContext context, String roadmapId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Career Milestone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Milestone Title',
                hintText: 'e.g. Distributed Computing with Ray',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Scope',
                hintText: 'e.g. Multi-node cluster training and actor patterns',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add to Pathway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;

                  final milestone = CareerMilestoneModel(
                    roadmapId: roadmapId,
                    title: title,
                    description: descCtrl.text.trim(),
                  );

                  await ref.read(careerRoadmapRepositoryProvider).saveMilestone(milestone);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
