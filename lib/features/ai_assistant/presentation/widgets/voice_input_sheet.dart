import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/voice_input_service.dart';
import '../screens/ai_assistant_screen.dart';

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
  bool _isListening = false;

  final List<String> _voiceExamples = [
    'Urgent submit client proposal today at 4pm',
    'Ask AI: Plan my morning around deep work',
    'Workout session tomorrow morning at 7am',
    'Ask AI: How can I optimize my daily focus?',
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
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening && _textController.text.isEmpty) {
        _textController.text = _voiceExamples[DateTime.now().second % _voiceExamples.length];
      }
    });
  }

  Future<void> _processInput(VoiceRoutingTarget target) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final service = ref.read(voiceInputServiceProvider);
    final result = await service.processVoiceInput(text, target: target);

    if (mounted) {
      Navigator.pop(context);
      if (result.target == VoiceRoutingTarget.aiAssistant) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Voice Task Created: "${result.parsedTask?.title ?? text}"'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              'Voice Productivity Interface',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Speak naturally to add tasks or converse with Timora AI',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 24),
            // Pulsating Mic Button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFEC4899)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(
                            alpha: _isListening ? 0.4 + (_animController.value * 0.3) : 0.2,
                          ),
                          blurRadius: _isListening ? 20 + (_animController.value * 12) : 10,
                          spreadRadius: _isListening ? _animController.value * 6 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 36,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? '🎙️ Listening... Tap to stop' : 'Tap microphone to speak',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isListening ? const Color(0xFF4F46E5) : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
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
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Quick suggestions
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
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Dual Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('Add Task'),
                    onPressed: () => _processInput(VoiceRoutingTarget.task),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Ask Timora AI'),
                    onPressed: () => _processInput(VoiceRoutingTarget.aiAssistant),
                    style: FilledButton.styleFrom(
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
    );
  }
}
