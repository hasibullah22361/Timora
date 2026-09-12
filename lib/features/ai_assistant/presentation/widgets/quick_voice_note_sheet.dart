import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:uuid/uuid.dart';
import '../../services/voice_input_service.dart';
import '../../domain/models/voice_note_models.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/diary/data/models/diary_entry_model.dart';
import 'package:timora/features/diary/presentation/providers/diary_provider.dart';
import 'voice_input_sheet.dart';

enum VoiceNoteStep {
  ready,
  recording,
  processingStt,
  processingAi,
  review,
  saving,
  error,
}

class QuickVoiceNoteSheet extends ConsumerStatefulWidget {
  final String? initialText;

  const QuickVoiceNoteSheet({super.key, this.initialText});

  /// Shows the Quick Voice Note bottom sheet modal.
  static Future<void> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickVoiceNoteSheet(initialText: initialText),
    );
  }

  @override
  ConsumerState<QuickVoiceNoteSheet> createState() => _QuickVoiceNoteSheetState();
}

class _QuickVoiceNoteSheetState extends ConsumerState<QuickVoiceNoteSheet> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _transcriptController = TextEditingController();

  VoiceNoteStep _currentStep = VoiceNoteStep.ready;
  String _statusText = 'Ready to record voice note';
  String? _errorMessage;

  // Recording timer (30-second limit)
  static const int maxRecordingSeconds = 30;
  int _secondsRecorded = 0;
  Timer? _timer;

  // AI Extraction Result
  VoiceNoteExtractionResult? _extractionResult;
  bool _saveDiaryChecked = true;
  bool _isSaving = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _transcriptController.text = widget.initialText!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processTextWithAi(_transcriptController.text);
      });
    } else {
      // Auto-start recording cleanly after initial frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _transcriptController.dispose();
    _safeReleaseMicrophone();
    super.dispose();
  }

  Future<void> _safeReleaseMicrophone() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (_currentStep == VoiceNoteStep.recording) return;

    setState(() {
      _currentStep = VoiceNoteStep.ready;
      _statusText = 'Requesting microphone access...';
      _errorMessage = null;
      _secondsRecorded = 0;
    });

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[QuickVoiceNote] STT status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _currentStep == VoiceNoteStep.recording) {
              _stopRecordingAndProcess();
            }
          }
        },
        onError: (err) {
          debugPrint('[QuickVoiceNote] STT error: ${err.errorMsg}');
          if (mounted && _currentStep == VoiceNoteStep.recording) {
            if (_transcriptController.text.trim().isNotEmpty) {
              _stopRecordingAndProcess();
            } else {
              setState(() {
                _currentStep = VoiceNoteStep.error;
                _errorMessage = err.errorMsg.isNotEmpty
                    ? err.errorMsg
                    : 'Microphone speech ended or unavailable.';
              });
            }
          }
        },
      );

      if (!available) {
        setState(() {
          _currentStep = VoiceNoteStep.error;
          _errorMessage = 'Microphone permission was not granted or recognition is unavailable.';
        });
        return;
      }

      setState(() {
        _currentStep = VoiceNoteStep.recording;
        _statusText = '🎙️ Recording voice note... Speak naturally';
      });

      _startTimer();

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcriptController.text = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('[QuickVoiceNote] Exception during speech initialize: $e');
      setState(() {
        _currentStep = VoiceNoteStep.error;
        _errorMessage = 'Could not access microphone: $e';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRecorded = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRecorded++;
      });

      // 30-Second Limit reached: automatically stop & process
      if (_secondsRecorded >= maxRecordingSeconds) {
        timer.cancel();
        _stopRecordingAndProcess();
      }
    });
  }

  Future<void> _stopRecordingAndProcess() async {
    _timer?.cancel();
    await _safeReleaseMicrophone();

    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _currentStep = VoiceNoteStep.error;
        _errorMessage = 'No voice input was detected. Tap microphone or type manually.';
      });
      return;
    }

    _processTextWithAi(text);
  }

  Future<void> _processTextWithAi(String text) async {
    setState(() {
      _currentStep = VoiceNoteStep.processingStt;
      _statusText = 'Converting your voice to text...';
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _currentStep = VoiceNoteStep.processingAi;
      _statusText = 'Understanding your note...';
    });

    try {
      final service = ref.read(voiceInputServiceProvider);
      final result = await service.processVoiceNote(text);

      if (!mounted) return;

      setState(() {
        _extractionResult = result;
        _saveDiaryChecked = result.hasDiary;
        _currentStep = VoiceNoteStep.review;
      });
    } catch (e) {
      debugPrint('[QuickVoiceNote] AI Understanding error: $e');
      if (!mounted) return;
      setState(() {
        _currentStep = VoiceNoteStep.error;
        _errorMessage = 'Could not analyze voice note: $e. You can still save your transcription.';
      });
    }
  }

  Future<void> _editTaskTitle(ExtractedVoiceTask task) async {
    final controller = TextEditingController(text: task.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Task Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        task.title = newTitle;
      });
    }
  }

  Future<void> _editDiaryContent() async {
    if (_extractionResult == null || _extractionResult!.diaryContent == null) return;
    final controller = TextEditingController(text: _extractionResult!.diaryContent);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Diary Reflection'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Diary reflection...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newContent != null && newContent.isNotEmpty) {
      setState(() {
        _extractionResult = VoiceNoteExtractionResult(
          rawTranscript: _extractionResult!.rawTranscript,
          diaryContent: newContent,
          diaryTitle: _extractionResult!.diaryTitle,
          diaryMoodKey: _extractionResult!.diaryMoodKey,
          tasks: _extractionResult!.tasks,
          signature: _extractionResult!.signature,
          processedAt: _extractionResult!.processedAt,
        );
      });
    }
  }

  Future<void> _saveRawTranscriptionAsDiary() async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSaving = true;
      _currentStep = VoiceNoteStep.saving;
    });

    try {
      final now = DateTime.now();
      final todayNormalized = DateTime(now.year, now.month, now.day);
      final diaryEntry = DiaryEntryModel(
        id: const Uuid().v4(),
        date: todayNormalized,
        title: 'Voice Note — Direct Entry',
        content: text,
        moodKey: 'good',
        mood: 3,
        tags: const ['voice-note', 'direct-save'],
        createdAt: now,
      );

      await ref.read(diaryNotifierProvider.notifier).saveEntry(diaryEntry);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('✨ Voice note saved directly to your Diary.')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _currentStep = VoiceNoteStep.error;
        _errorMessage = 'Could not save diary: $e';
      });
    }
  }

  void _cancelRecording() {
    _timer?.cancel();
    _safeReleaseMicrophone();
    Navigator.of(context).pop();
  }

  Future<void> _confirmAndExecute({required bool shouldSchedule}) async {
    if (_extractionResult == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _currentStep = VoiceNoteStep.saving;
    });

    try {
      final service = ref.read(voiceInputServiceProvider);
      final summary = await service.executeVoiceNoteActions(
        result: _extractionResult!,
        saveDiary: _saveDiaryChecked,
        shouldSchedule: shouldSchedule,
        selectedTasks: _extractionResult!.tasks.where((t) => t.isSelected).toList(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(summary.message)),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _currentStep = VoiceNoteStep.review;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save voice note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimerText(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs / 00:${maxRecordingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Voice Note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Voice → Speech-to-Text → AI Understanding',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: _cancelRecording,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Bidirectional Link to Natural Voice Planning
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    _timer?.cancel();
                    _safeReleaseMicrophone();
                    Navigator.of(context).pop();
                    VoiceInputSheet.show(context);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF6366F1)),
                        SizedBox(width: 5),
                        Text(
                          'Switch to Natural Voice Planning',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content body according to current step
            if (_currentStep == VoiceNoteStep.recording || _currentStep == VoiceNoteStep.ready)
              _buildRecordingView(theme, isDark)
            else if (_currentStep == VoiceNoteStep.processingStt || _currentStep == VoiceNoteStep.processingAi)
              _buildProcessingView(theme, isDark)
            else if (_currentStep == VoiceNoteStep.review)
              _buildReviewView(theme, isDark)
            else if (_currentStep == VoiceNoteStep.saving)
              _buildSavingView(theme, isDark)
            else if (_currentStep == VoiceNoteStep.error)
              _buildErrorView(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Pulsing Microphone Visualizer
        Center(
          child: ScaleTransition(
            scale: _pulseScale,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Live Timer: 00:18 / 00:30
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimerText(_secondsRecorded),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),

        // Live recognized speech display
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 70, maxHeight: 110),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              _transcriptController.text.isEmpty
                  ? 'Say e.g.: "Today I finished the database work. Tomorrow I need to finish the API and call Ahmad about the project."'
                  : _transcriptController.text,
              style: TextStyle(
                fontSize: 14,
                fontStyle: _transcriptController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: _transcriptController.text.isEmpty
                    ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Control Buttons: Stop / Cancel
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _stopRecordingAndProcess,
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text('Stop & Process'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36.0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '"${_transcriptController.text}"',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView(ThemeData theme, bool isDark) {
    final res = _extractionResult;
    if (res == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original Voice Note Transcription Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Transcribed Voice Note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                res.rawTranscript,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ================= DIARY SECTION =================
        if (res.hasDiary) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B2433) : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF0369A1).withValues(alpha: 0.5) : const Color(0xFFBAE6FD),
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
                        const Icon(Icons.book_rounded, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Diary & Reflection',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0284C7)),
                          tooltip: 'Edit reflection',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _editDiaryContent,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Save to Diary',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Switch.adaptive(
                          value: _saveDiaryChecked,
                          activeTrackColor: const Color(0xFF0284C7),
                          activeThumbColor: Colors.white,
                          onChanged: (val) => setState(() => _saveDiaryChecked = val),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  res.diaryContent!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ================= TASKS SECTION =================
        if (res.hasTasks) ...[
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'Tasks Found (${res.tasks.length})',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...res.tasks.map((task) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: task.isSelected
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: task.isSelected,
                    activeColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        task.isSelected = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              tooltip: 'Edit task title',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editTaskTitle(task),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (task.dueDate != null)
                              _buildBadge(
                                icon: Icons.calendar_today_rounded,
                                label: _formatTaskDate(task.dueDate!),
                                color: const Color(0xFF3B82F6),
                                isDark: isDark,
                              ),
                            if (task.dueTime != null || task.startTime != null)
                              _buildBadge(
                                icon: Icons.access_time_rounded,
                                label: task.startTime != null
                                    ? '${task.startTime!.format(context)}${task.endTime != null ? ' - ${task.endTime!.format(context)}' : ''}'
                                    : task.dueTime!.format(context),
                                color: const Color(0xFF8B5CF6),
                                isDark: isDark,
                              ),
                            if (task.priority == TaskPriority.urgent || task.priority == TaskPriority.high)
                              _buildBadge(
                                icon: Icons.flag_rounded,
                                label: task.priority == TaskPriority.urgent ? 'Urgent' : 'High Priority',
                                color: const Color(0xFFEF4444),
                                isDark: isDark,
                              ),
                            if (task.matchedProjectName != null)
                              _buildBadge(
                                icon: Icons.folder_outlined,
                                label: task.matchedProjectName!,
                                color: const Color(0xFF0D9488),
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Scheduling Confirmation Prompt
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'I found ${res.tasks.length} task${res.tasks.length == 1 ? '' : 's'}. Do you want me to schedule them in Timora Planner?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _confirmAndExecute(shouldSchedule: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('No, Just Add Tasks'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : () => _confirmAndExecute(shouldSchedule: true),
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: const Text('Yes, Schedule'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // If only diary was found (0 tasks)
        if (res.hasDiary && !res.hasTasks) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => _confirmAndExecute(shouldSchedule: false),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save to Diary'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavingView(ThemeData theme, bool isDark) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36.0),
      child: Column(
        children: [
          CircularProgressIndicator(
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          SizedBox(height: 20),
          Text(
            'Updating your Timora workspace...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'An error occurred during voice note processing.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.red),
        ),
        const SizedBox(height: 16),

        // Fallback text input so the user never loses their voice note
        TextField(
          controller: _transcriptController,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Type your note here instead...',
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _startRecording,
                child: const Text('Retry Voice'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final text = _transcriptController.text.trim();
                  if (text.isNotEmpty) {
                    _processTextWithAi(text);
                  }
                },
                child: const Text('Process Text'),
              ),
            ),
          ],
        ),
        if (_transcriptController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveRawTranscriptionAsDiary,
            icon: const Icon(Icons.book_outlined, size: 18),
            label: const Text('Save Note Directly to Diary'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTaskDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tom = now.add(const Duration(days: 1));
    if (dt.year == tom.year && dt.month == tom.month && dt.day == tom.day) {
      return 'Tomorrow';
    }
    return '${dt.month}/${dt.day}';
  }
}
