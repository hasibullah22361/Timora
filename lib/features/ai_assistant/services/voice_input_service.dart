import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../quick_add/services/quick_add_parser.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../services/ai_service.dart';

enum VoiceInputState {
  idle,
  listening,
  processing,
  success,
  error,
}

enum VoiceRoutingTarget {
  task,
  aiAssistant,
  auto,
}

class VoiceInputResult {
  final String transcript;
  final VoiceRoutingTarget target;
  final TaskModel? parsedTask;
  final String? errorMessage;

  VoiceInputResult({
    required this.transcript,
    required this.target,
    this.parsedTask,
    this.errorMessage,
  });
}

final voiceInputStateProvider = StateProvider<VoiceInputState>((ref) => VoiceInputState.idle);
final voiceTranscriptProvider = StateProvider<String>((ref) => '');

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return VoiceInputService(ref);
});

class VoiceInputService {
  final Ref _ref;

  VoiceInputService(this._ref);

  /// Analyzes transcribed voice text and determines whether it is an immediate task command or AI prompt
  static VoiceRoutingTarget determineTarget(String text) {
    final lower = text.toLowerCase().trim();
    
    // Explicit AI assistant intents
    if (lower.startsWith('ask ai') ||
        lower.startsWith('ai ') ||
        lower.contains('plan my day') ||
        lower.contains('plan my week') ||
        lower.contains('how should i') ||
        lower.contains('what should i do') ||
        lower.contains('suggest') ||
        lower.contains('coach me')) {
      return VoiceRoutingTarget.aiAssistant;
    }

    // Default to Quick Add Task
    return VoiceRoutingTarget.task;
  }

  /// Processes spoken text, creates a task or sends to AI assistant based on target
  Future<VoiceInputResult> processVoiceInput(String transcript, {VoiceRoutingTarget target = VoiceRoutingTarget.auto}) async {
    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.processing;

    try {
      final actualTarget = (target == VoiceRoutingTarget.auto)
          ? determineTarget(transcript)
          : target;

      if (actualTarget == VoiceRoutingTarget.task) {
        final parsed = QuickAddParser.parse(transcript);
        final task = parsed.toTaskModel();
        await _ref.read(taskNotifierProvider).createTask(task);

        _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
        return VoiceInputResult(
          transcript: transcript,
          target: VoiceRoutingTarget.task,
          parsedTask: task,
        );
      } else {
        // Send to AI Assistant
        final cleanPrompt = transcript
            .replaceFirst(RegExp(r'^(ask ai|ai)\s*', caseSensitive: false), '')
            .trim();

        await _ref.read(aiMessagesProvider.notifier).sendMessage(cleanPrompt.isNotEmpty ? cleanPrompt : transcript);

        _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
        return VoiceInputResult(
          transcript: transcript,
          target: VoiceRoutingTarget.aiAssistant,
        );
      }
    } catch (e) {
      _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.error;
      return VoiceInputResult(
        transcript: transcript,
        target: target,
        errorMessage: e.toString(),
      );
    }
  }
}
