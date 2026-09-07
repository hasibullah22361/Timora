import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/voice_input_service.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../screens/ai_assistant_screen.dart';

enum SpeechUIState {
  idle,
  requestingPermission,
  listening,
  processing,
  ambiguousClarification,
  confirmationRequired,
  success,
  error,
}

class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VoiceInputSheet(),
    );
  }

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late AnimationController _animController;
  final stt.SpeechToText _speech = stt.SpeechToText();

  SpeechUIState _uiState = SpeechUIState.idle;
  String _statusMessage = 'Tap microphone to speak';
  String? _clarificationPrompt;
  VoiceInputResult? _pendingConfirmationResult;

  final List<String> _voiceExamples = [
    'Schedule study tomorrow from 9 AM to 11 AM',
    'Schedule gym tomorrow at 5 PM for one hour',
    'Move my research to 9 PM',
    "Cancel today's gym",
    'What should I do now?',
    'What is my schedule tomorrow?',
    'Schedule study tomorrow',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_uiState == SpeechUIState.listening) {
      await _stopListening();
      return;
    }

    setState(() {
      _uiState = SpeechUIState.requestingPermission;
      _statusMessage = 'Requesting microphone permission...';
      _clarificationPrompt = null;
    });

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoicePlanning] Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _uiState == SpeechUIState.listening) {
              setState(() {
                _uiState = SpeechUIState.idle;
                _statusMessage = 'Tap microphone to speak';
              });
            }
          }
        },
        onError: (err) {
          debugPrint('[VoicePlanning] Speech error: ${err.errorMsg}');
          if (mounted) {
            setState(() {
              _uiState = SpeechUIState.idle;
              _statusMessage = 'Microphone speech ended or unavailable';
            });
          }
        },
      );

      if (available) {
        setState(() {
          _uiState = SpeechUIState.listening;
          _statusMessage = '🎙️ Listening... Speak naturally';
        });

        await _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
        );
      } else {
        setState(() {
          _uiState = SpeechUIState.idle;
          _statusMessage = 'Microphone permission denied or speech recognition not supported.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission was not granted or recognition is unavailable.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[VoicePlanning] Exception during speech initialize: $e');
      setState(() {
        _uiState = SpeechUIState.idle;
        _statusMessage = 'Speech recognition unavailable on this device.';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _uiState = SpeechUIState.idle;
      _statusMessage = 'Tap microphone to speak';
    });
  }

  Future<void> _processInput({VoiceRoutingTarget target = VoiceRoutingTarget.auto}) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_speech.isListening) {
      await _speech.stop();
    }

    setState(() {
      _uiState = SpeechUIState.processing;
      _statusMessage = 'Executing Timora natural voice command...';
      _clarificationPrompt = null;
    });

    final service = ref.read(voiceInputServiceProvider);
    final result = await service.processVoiceInput(text, target: target);

    if (!mounted) return;

    // Handle ambiguous commands (e.g. missing time)
    if (result.isAmbiguous) {
      setState(() {
        _uiState = SpeechUIState.ambiguousClarification;
        _clarificationPrompt = result.clarificationPrompt ?? result.spokenFeedback;
        _statusMessage = result.clarificationPrompt ?? 'Clarification needed';
      });
      return;
    }

    // Handle destructive ambiguous commands requiring confirmation
    if (result.requiresConfirmation) {
      setState(() {
        _uiState = SpeechUIState.confirmationRequired;
        _pendingConfirmationResult = result;
        _clarificationPrompt = result.clarificationPrompt ?? 'Confirm action?';
        _statusMessage = _clarificationPrompt!;
      });
      return;
    }

    if (result.errorMessage != null) {
      setState(() {
        _uiState = SpeechUIState.idle;
        _statusMessage = result.errorMessage!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!), backgroundColor: Colors.red),
      );
      return;
    }

    // Success!
    Navigator.pop(context);

    if (result.target == VoiceRoutingTarget.aiAssistant) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
      );
    } else {
      String message;
      if (result.target == VoiceRoutingTarget.activity) {
        message = '✨ Activity Scheduled: "${result.parsedActivity?.title ?? text}"';
      } else if (result.target == VoiceRoutingTarget.reschedule) {
        message = '✨ Rescheduled "${result.parsedActivity?.title ?? text}"';
      } else if (result.target == VoiceRoutingTarget.cancel) {
        message = '✨ Cancelled "${result.parsedActivity?.title ?? text}"';
      } else if (result.target == VoiceRoutingTarget.task) {
        message = '✨ Task Created: "${result.parsedTask?.title ?? text}"';
      } else {
        message = result.spokenFeedback ?? '✨ Command executed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _confirmPendingDestructiveAction() async {
    final pending = _pendingConfirmationResult;
    if (pending != null && pending.parsedActivity != null) {
      await ref.read(scheduleNotifierProvider).markSkipped(pending.parsedActivity!);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Activity cancellation confirmed.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = _uiState == SpeechUIState.listening;
    final isProcessing = _uiState == SpeechUIState.processing;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Natural Voice Planning',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Speak naturally: "Schedule study tomorrow from 9 AM to 11 AM"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 20),

            // Pulsating Mic Button
            GestureDetector(
              onTap: isProcessing ? null : _toggleListening,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isListening
                            ? [const Color(0xFFEF4444), const Color(0xFFF97316)]
                            : [const Color(0xFF4F46E5), const Color(0xFF7C3AED), const Color(0xFFEC4899)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isListening ? const Color(0xFFEF4444) : const Color(0xFF7C3AED)).withValues(
                            alpha: isListening ? 0.5 + (_animController.value * 0.4) : 0.2,
                          ),
                          blurRadius: isListening ? 24 + (_animController.value * 14) : 10,
                          spreadRadius: isListening ? _animController.value * 8 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening ? Icons.mic : (isProcessing ? Icons.hourglass_top_rounded : Icons.mic_none),
                      color: Colors.white,
                      size: 36,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isListening
                    ? const Color(0xFFEF4444)
                    : (isProcessing
                        ? const Color(0xFF7C3AED)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.65)),
              ),
            ),
            const SizedBox(height: 16),

            // Clarification or Confirmation Banner
            if (_clarificationPrompt != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _uiState == SpeechUIState.confirmationRequired
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _uiState == SpeechUIState.confirmationRequired
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _uiState == SpeechUIState.confirmationRequired ? Icons.warning_amber_rounded : Icons.help_outline,
                          size: 18,
                          color: _uiState == SpeechUIState.confirmationRequired ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _uiState == SpeechUIState.confirmationRequired ? 'Confirmation Required' : 'More Information Needed',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _uiState == SpeechUIState.confirmationRequired ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _clarificationPrompt!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    if (_uiState == SpeechUIState.confirmationRequired) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _uiState = SpeechUIState.idle;
                                _clarificationPrompt = null;
                                _statusMessage = 'Tap microphone to speak';
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            onPressed: _confirmPendingDestructiveAction,
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // Voice Input Text Field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Spoken transcript appears here...',
                hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _textController.clear()),
                      )
                    : null,
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Quick suggestion chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _voiceExamples.map((ex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(ex, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _textController.text = ex;
                          _clarificationPrompt = null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Primary Execute Button + Secondary Buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Execute Voice Command', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isProcessing ? null : () => _processInput(target: VoiceRoutingTarget.auto),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Ask AI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isProcessing ? null : () => _processInput(target: VoiceRoutingTarget.aiAssistant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
