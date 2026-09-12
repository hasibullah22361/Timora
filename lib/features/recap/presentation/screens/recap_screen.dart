import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/recap/domain/models/recap_models.dart';
import 'package:timora/features/recap/data/repositories/recap_repository.dart';
import 'package:timora/features/recap/application/recap_generator_service.dart';
import 'package:timora/features/recap/presentation/screens/recap_history_screen.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/diary/presentation/screens/diary_screen.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

class RecapScreen extends ConsumerStatefulWidget {
  final RecapType recapType;
  final DateTime? targetDate;

  const RecapScreen({
    super.key,
    this.recapType = RecapType.daily,
    this.targetDate,
  });

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late RecapType _currentType;
  TimoraRecapModel? _recap;
  bool _isLoading = true;
  bool _isSpeaking = false;
  TaskOutcomeStatus? _taskFilter;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentType = widget.recapType;
    final now = DateTime.now();
    _selectedDate = widget.targetDate != null
        ? DateTime(widget.targetDate!.year, widget.targetDate!.month,
            widget.targetDate!.day)
        : DateTime(now.year, now.month, now.day);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);

    _loadOrGenerateRecap();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadOrGenerateRecap({bool forceRegenerate = false}) async {
    setState(() => _isLoading = true);
    final repo = ref.read(recapRepositoryProvider);
    final generator = ref.read(recapGeneratorServiceProvider);

    TimoraRecapModel? found;
    if (!forceRegenerate) {
      found = await repo.getRecapForDate(_currentType, _selectedDate);
    }

    if (found == null || forceRegenerate) {
      switch (_currentType) {
        case RecapType.daily:
          found = await generator.generateDailyRecap(
            targetDate: _selectedDate,
            saveToDiary: true,
          );
          break;
        case RecapType.weekly:
          found = await generator.generateWeeklyRecap(
            targetDate: _selectedDate,
            saveToDiary: true,
          );
          break;
        case RecapType.monthly:
          found = await generator.generateMonthlyRecap(
            targetDate: _selectedDate,
            saveToDiary: true,
          );
          break;
      }
    }

    if (mounted) {
      setState(() {
        _recap = found;
        _isLoading = false;
      });
      _animController.forward(from: 0.0);
    }
  }

  Future<void> _toggleSpeech() async {
    if (_recap == null) return;
    final voiceService = ref.read(voiceAnnouncementServiceProvider);

    if (_isSpeaking) {
      await voiceService.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      if (mounted) setState(() => _isSpeaking = true);
      await voiceService.speakNotification(
        title: 'Timora Recap',
        body: _recap!.spokenScript,
      );
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _applyTomorrowSuggestions(
      List<TomorrowRecommendation> recommendations) async {
    final taskNotifier = ref.read(taskNotifierProvider);
    final scheduleNotifier = ref.read(scheduleNotifierProvider);

    final tomorrow = _selectedDate.add(const Duration(days: 1));
    int appliedCount = 0;

    for (final rec in recommendations) {
      if (rec.isApplied) continue;

      if (rec.activityCategory == 'Routine' ||
          rec.activityCategory == 'Planning') {
        // Add to schedule
        final start =
            DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 30);
        final act = ScheduleActivity(
          id: 'rec_act_${DateTime.now().millisecondsSinceEpoch}_$appliedCount',
          title: rec.title,
          description: rec.reason,
          date: tomorrow,
          startTime: start,
          endTime: start.add(Duration(minutes: rec.estimatedMinutes)),
          category: 'Planning',
          icon: '🎯',
          createdAt: DateTime.now(),
        );
        await scheduleNotifier.addActivity(act);
      } else {
        // Add as task
        final task = TaskModel(
          id: 'rec_task_${DateTime.now().millisecondsSinceEpoch}_$appliedCount',
          title: rec.title,
          description: rec.reason,
          dueDate: tomorrow,
          priority: rec.priority == 'HIGH'
              ? TaskPriority.high
              : (rec.priority == 'URGENT'
                  ? TaskPriority.urgent
                  : TaskPriority.medium),
          category: rec.activityCategory,
          estimatedDurationMinutes: rec.estimatedMinutes,
          createdAt: DateTime.now(),
        );
        await taskNotifier.createTask(task);
      }
      appliedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✨ Applied $appliedCount recommendations for tomorrow!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      // Mark as applied locally in recap
      final updatedRecs = _recap!.tomorrowRecommendations
          .map((r) => r.copyWith(isApplied: true))
          .toList();
      final updatedRecap =
          _recap!.copyWith(tomorrowRecommendations: updatedRecs);
      await ref.read(recapRepositoryProvider).saveRecap(updatedRecap);
      setState(() => _recap = updatedRecap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🧠 AI Recap',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentType.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recap History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecapHistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Regenerate Recap',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadOrGenerateRecap(forceRegenerate: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing your real Timora productivity data...',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : _recap == null
              ? const Center(child: Text('Unable to load recap data.'))
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: () =>
                        _loadOrGenerateRecap(forceRegenerate: true),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 1. Spoken TTS Player Banner
                        _buildTtsBanner(context),
                        const SizedBox(height: 16),

                        // 2. Animated Hero Header
                        _buildHeroHeader(context),
                        const SizedBox(height: 16),

                        // 3. AI 3-Line Summary Card
                        _buildAiSummaryCard(context),
                        const SizedBox(height: 16),

                        // 4. Productivity Score & Quick Stats
                        _buildScoreAndMetrics(context),
                        const SizedBox(height: 16),

                        // 5. Task Outcomes Breakdown & Filter
                        _buildTaskOutcomesSection(context),
                        const SizedBox(height: 16),

                        // 6. Replaced Tasks Card (if any)
                        if (_recap!.replacedTasks > 0 ||
                            _recap!.taskOutcomes.any((t) =>
                                t.status == TaskOutcomeStatus.replaced)) ...[
                          _buildReplacedTasksCard(context),
                          const SizedBox(height: 16),
                        ],

                        // 7. Visual Day Timeline
                        if (_recap!.timelineItems.isNotEmpty) ...[
                          _buildTimelineSection(context),
                          const SizedBox(height: 16),
                        ],

                        // 8. Focus Analytics Card
                        _buildFocusAnalyticsCard(context),
                        const SizedBox(height: 16),

                        // 9. Wins & Areas to Improve
                        _buildWinsAndImprovements(context),
                        const SizedBox(height: 16),

                        // 10. AI Insights Card
                        if (_recap!.aiInsights.isNotEmpty) ...[
                          _buildAiInsightsCard(context),
                          const SizedBox(height: 16),
                        ],

                        // 11. Tomorrow Recommendations
                        if (_recap!.tomorrowRecommendations.isNotEmpty) ...[
                          _buildTomorrowRecommendations(context),
                          const SizedBox(height: 16),
                        ],

                        // 12. Diary Status & Actions
                        _buildDiaryActions(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTtsBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSpeaking
                      ? 'Speaking Recap...'
                      : 'Spoken Voice Announcement',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _isSpeaking
                      ? 'Tap to stop speech'
                      : 'Listen to native spoken summary',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _toggleSpeech,
            icon: Icon(
              _isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(_isSpeaking ? 'Stop' : 'Listen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Real productivity analytics & verified milestones',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  '3-LINE AI EXECUTIVE SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _recap!.aiSummary,
              style: const TextStyle(
                  fontSize: 14, height: 1.55, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreAndMetrics(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final score = _recap!.productivityScore.round();
    final h = _recap!.focusMinutes ~/ 60;
    final m = _recap!.focusMinutes % 60;
    final focusText = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Row(
      children: [
        // Productivity Score Gauge
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value:
                            (_recap!.productivityScore / 100).clamp(0.0, 1.0),
                        strokeWidth: 7,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        color: score >= 80
                            ? const Color(0xFF10B981)
                            : (score >= 60
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFF59E0B)),
                      ),
                    ),
                    Text(
                      '$score%',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Productivity',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Metrics Stack
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildMiniMetric(
                context,
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                label: 'Tasks Completed',
                value:
                    '${_recap!.completedTasks} / ${_recap!.totalTasks > 0 ? _recap!.totalTasks : _recap!.completedTasks}',
              ),
              const SizedBox(height: 8),
              _buildMiniMetric(
                context,
                icon: Icons.timer_outlined,
                color: const Color(0xFF6366F1),
                label: 'Focused Work',
                value: focusText,
              ),
              const SizedBox(height: 8),
              _buildMiniMetric(
                context,
                icon: Icons.autorenew_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Routine Consistency',
                value: '${_recap!.routineConsistency.round()}%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTaskOutcomesSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _taskFilter == null
        ? _recap!.taskOutcomes
        : _recap!.taskOutcomes.where((t) => t.status == _taskFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "TODAY'S TASKS",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8),
            ),
            Text(
              '${_recap!.completedTasks}/${_recap!.totalTasks} Completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Interactive Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', null),
              _buildFilterChip('✅ Completed (${_recap!.completedTasks})',
                  TaskOutcomeStatus.completed),
              _buildFilterChip('❌ Missed (${_recap!.missedTasks})',
                  TaskOutcomeStatus.missed),
              _buildFilterChip('⏭️ Skipped (${_recap!.skippedTasks})',
                  TaskOutcomeStatus.skipped),
              _buildFilterChip('🔄 Replaced (${_recap!.replacedTasks})',
                  TaskOutcomeStatus.replaced),
              _buildFilterChip('⏳ Incomplete (${_recap!.incompleteTasks})',
                  TaskOutcomeStatus.incomplete),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('No tasks matching this status.')),
          )
        else
          ...filtered.map((item) => _buildTaskItemTile(context, item)),
      ],
    );
  }

  Widget _buildFilterChip(String label, TaskOutcomeStatus? status) {
    final isSelected = _taskFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (_) => setState(() => _taskFilter = status),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTaskItemTile(BuildContext context, TaskOutcomeItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon;
    Color color;
    String statusLabel;

    switch (item.status) {
      case TaskOutcomeStatus.completed:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        statusLabel = 'Completed';
        break;
      case TaskOutcomeStatus.missed:
        icon = Icons.cancel_rounded;
        color = const Color(0xFFEF4444);
        statusLabel = 'Missed';
        break;
      case TaskOutcomeStatus.skipped:
        icon = Icons.skip_next_rounded;
        color = const Color(0xFFF59E0B);
        statusLabel = 'Skipped';
        break;
      case TaskOutcomeStatus.replaced:
        icon = Icons.sync_rounded;
        color = const Color(0xFF3B82F6);
        statusLabel = 'Replaced';
        break;
      case TaskOutcomeStatus.rescheduled:
        icon = Icons.calendar_today_rounded;
        color = const Color(0xFF8B5CF6);
        statusLabel = 'Rescheduled';
        break;
      case TaskOutcomeStatus.incomplete:
        icon = Icons.hourglass_top_rounded;
        color = Colors.grey;
        statusLabel = 'Incomplete';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (item.status == TaskOutcomeStatus.replaced &&
                    item.replacedByTitle != null)
                  Text(
                    'Replaced by: ${item.replacedByTitle}',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacedTasksCard(BuildContext context) {
    final replacedItems = _recap!.taskOutcomes
        .where((t) => t.status == TaskOutcomeStatus.replaced)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔄', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'TASK & ACTIVITY REPLACEMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...replacedItems.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.title,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.replacedByTitle ?? 'New Session',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DAY TIMELINE',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: _recap!.timelineItems.map((item) {
              final timeStr = DateFormat('hh:mm a').format(item.time);
              final isDone = item.status == ActivityStatus.completed;
              final isSkipped = item.status == ActivityStatus.skipped;
              final isReplaced = item.status == ActivityStatus.replaced;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Text(item.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration:
                              isSkipped ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isDone)
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: Color(0xFF10B981))
                    else if (isSkipped)
                      const Icon(Icons.skip_next_rounded,
                          size: 18, color: Color(0xFFF59E0B))
                    else if (isReplaced)
                      const Icon(Icons.sync_rounded,
                          size: 18, color: Color(0xFF3B82F6))
                    else
                      const Icon(Icons.radio_button_unchecked_rounded,
                          size: 18, color: Colors.grey),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusAnalyticsCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final h = _recap!.focusMinutes ~/ 60;
    final m = _recap!.focusMinutes % 60;
    final dh = _recap!.deepWorkMinutes ~/ 60;
    final dm = _recap!.deepWorkMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⏱️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'FOCUS ANALYTICS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFocusStatBox(
                  'Total Focus',
                  h > 0 ? '${h}h ${m}m' : '${m}m',
                  const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFocusStatBox(
                  'Deep Work',
                  dh > 0 ? '${dh}h ${dm}m' : '${dm}m',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFocusStatBox(
                  'Adherence',
                  '${_recap!.scheduleAdherence.round()}%',
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFocusStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWinsAndImprovements(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wins
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    Text(
                      "TODAY'S WINS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recap!.wins.map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '• $w',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Areas to Improve
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    Text(
                      'TO IMPROVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recap!.areasToImprove.map((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '• $a',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightsCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'TIMORA AI INSIGHTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recap!.aiInsights.map((insight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $insight',
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              )),
        ],
      ),
    );
  }

  Widget _buildTomorrowRecommendations(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF1E293B)]
              : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🔮', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'TOMORROW RECOMMENDATIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _applyTomorrowSuggestions(_recap!.tomorrowRecommendations),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                label: const Text('Apply Suggestions',
                    style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recap!.tomorrowRecommendations.map((rec) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded,
                          color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rec.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(rec.reason,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    if (rec.isApplied)
                      const Chip(
                        label: Text('Applied',
                            style:
                                TextStyle(fontSize: 10, color: Colors.green)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Color(0xFFD1FAE5),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDiaryActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiaryScreen()),
              );
            },
            icon: const Icon(Icons.book_rounded),
            label: const Text('View Diary Entries'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
