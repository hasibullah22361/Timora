import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/daily_debrief_service.dart';
import '../../../diary/data/repositories/diary_repository.dart';
import '../../../diary/presentation/screens/diary_detail_screen.dart';

class DailyDebriefSheet extends ConsumerStatefulWidget {
  const DailyDebriefSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DailyDebriefSheet(),
    );
  }

  @override
  ConsumerState<DailyDebriefSheet> createState() => _DailyDebriefSheetState();
}

class _DailyDebriefSheetState extends ConsumerState<DailyDebriefSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _wellController = TextEditingController();
  final TextEditingController _improveController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListeningWell = false;
  bool _isListeningImprove = false;
  bool _isGenerating = false;
  DailyDebriefResult? _result;
  String? _errorMessage;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _wellController.dispose();
    _improveController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech(int questionNum) async {
    final isTargetActive = questionNum == 1 ? _isListeningWell : _isListeningImprove;

    if (isTargetActive) {
      await _speech.stop();
      setState(() {
        _isListeningWell = false;
        _isListeningImprove = false;
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListeningWell = false;
                _isListeningImprove = false;
              });
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListeningWell = false;
              _isListeningImprove = false;
            });
          }
        },
      );

      if (available && mounted) {
        setState(() {
          if (questionNum == 1) {
            _isListeningWell = true;
            _isListeningImprove = false;
          } else {
            _isListeningWell = false;
            _isListeningImprove = true;
          }
        });

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                if (questionNum == 1) {
                  _wellController.text = result.recognizedWords;
                } else {
                  _improveController.text = result.recognizedWords;
                }
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListeningWell = false;
          _isListeningImprove = false;
        });
      }
    }
  }

  Future<void> _handleGenerateReflection() async {
    final wellText = _wellController.text.trim();
    final improveText = _improveController.text.trim();

    if (wellText.isEmpty && improveText.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide at least a brief answer to reflect upon.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(dailyDebriefServiceProvider);
      final res = await service.processAndSaveDebrief(
        whatWentWell: wellText,
        whatToImprove: improveText,
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Failed to generate reflection. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.nightlight_round, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Debrief',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_result != null) ...[
              // ── COMPLETED REFLECTION CARD ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF131B2E), const Color(0xFF1E293B)]
                        : [const Color(0xFFEEF2FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'AI DAILY REFLECTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bookmark_added_rounded, color: Color(0xFF10B981), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Saved to Diary',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      _result!.reflection,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_result!.tasksCompletedToday} tasks completed today',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final entry = await ref.read(diaryRepositoryProvider).getEntryById(_result!.diaryEntryId);
                            if (entry != null && context.mounted) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: entry)),
                              );
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('View in Diary'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                // ── QUESTION 1: WHAT WENT WELL TODAY? ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'What went well today?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) => Icon(
                          _isListeningWell ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListeningWell
                              ? const Color(0xFFEC4899)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          size: 20,
                        ),
                      ),
                      tooltip: 'Speak your answer',
                      onPressed: () => _toggleSpeech(1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _wellController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Finished the database schema, hit 2 hours of focus...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                // ── QUESTION 2: WHAT WOULD YOU IMPROVE TOMORROW? ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'What would you improve tomorrow?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) => Icon(
                          _isListeningImprove ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListeningImprove
                              ? const Color(0xFFEC4899)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          size: 20,
                        ),
                      ),
                      tooltip: 'Speak your answer',
                      onPressed: () => _toggleSpeech(2),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _improveController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Spent too much time on phone, start focus earlier...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _handleGenerateReflection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isGenerating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Synthesizing Reflection...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Reflect & Save to Diary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
