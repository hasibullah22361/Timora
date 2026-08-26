import '../models/ai_models.dart';

abstract class AIProvider {
  /// Generate a text response and potentially a structured plan/actions payload
  Future<AIMessage> generateResponse({
    required String prompt,
    required String contextContext,
    required List<AIMessage> history,
  });
}
