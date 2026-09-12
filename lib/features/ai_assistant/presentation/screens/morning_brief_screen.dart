import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/morning_brief_service.dart';
import '../../../settings/data/repositories/notification_settings_repository.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

class MorningBriefScreen extends ConsumerStatefulWidget {
  const MorningBriefScreen({super.key});

  @override
  ConsumerState<MorningBriefScreen> createState() => _MorningBriefScreenState();
}

class _MorningBriefScreenState extends ConsumerState<MorningBriefScreen> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  String? _activeDuration;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ref.read(morningBriefServiceProvider).stopSpeaking();
    super.dispose();
  }

  Future<void> _handlePlayAudio(String text) async {
    final service = ref.read(morningBriefServiceProvider);
    if (_isPlaying) {
      await service.stopSpeaking();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await service.speakBrief(text);
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsRepo = ref.watch(notificationSettingsRepositoryProvider);
    final briefAsync = ref.watch(todayMorningBriefProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Morning Briefing',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Briefing Preferences',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: briefAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Synthesizing your morning brief...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                const Text('Could not load morning briefing.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(todayMorningBriefProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (brief) {
          final isMale = settingsRepo.morningBriefVoiceGender == 'male';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date & Greeting Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brief.dateString,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your Day at a Glance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Duration Filter Chips (Short, Normal, Detailed) ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: ['short', 'normal', 'detailed'].map((d) {
                      final isSelected = (_activeDuration ?? brief.duration) == d;
                      final label = d == 'short' ? '⚡ Short' : (d == 'normal' ? '🌤️ Normal' : '📋 Detailed');
                      return Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            setState(() => _activeDuration = d);
                            await settingsRepo.setMorningBriefDuration(d);
                            ref.invalidate(todayMorningBriefProvider);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Spoken Brief Card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF131B2E), const Color(0xFF0F172A)]
                          : [Colors.white, const Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: brief.generatedWithAI ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                brief.generatedWithAI ? 'AI PERSONALIZED BRIEF' : 'VERIFIED TIMORA BRIEF',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          // Voice Gender Pill
                          InkWell(
                            onTap: () async {
                              final newGender = isMale ? 'female' : 'male';
                              await settingsRepo.setMorningBriefVoiceGender(newGender);
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isMale ? Icons.man_rounded : Icons.woman_rounded,
                                    size: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isMale ? 'Male Voice' : 'Female Voice',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Spoken Text Content
                      SelectableText(
                        brief.briefText,
                        style: TextStyle(
                          fontSize: 16.5,
                          height: 1.55,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Audio Playback Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Play / Pause FAB
                            InkWell(
                              onTap: () => _handlePlayAudio(brief.briefText),
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _isPlaying
                                            ? [const Color(0xFFEC4899), const Color(0xFFF43F5E)]
                                            : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: _isPlaying
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFF43F5E)
                                                    .withValues(alpha: 0.3 + 0.2 * _pulseController.value),
                                                blurRadius: 10 + 4 * _pulseController.value,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPlaying ? 'Speaking Morning Brief...' : 'Listen to Brief',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    _isPlaying
                                        ? 'Tap to stop playback'
                                        : 'Spoken using ${isMale ? "male" : "female"} voice',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Breakdown Cards: Priorities & First Activity ──
                Text(
                  "Today's Key Targets",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                // Priorities List
                if (brief.priorities.isNotEmpty) ...[
                  ...brief.priorities.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final title = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No pending priorities logged for today. Feel free to plan or add tasks!',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // First Activity Card
                if (brief.firstActivityTitle != null && brief.firstActivityTime != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.schedule_rounded, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First Activity Today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                brief.firstActivityTitle!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            DateFormat('h:mm a').format(brief.firstActivityTime!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
