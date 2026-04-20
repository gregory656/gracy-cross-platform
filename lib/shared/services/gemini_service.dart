class GeminiService {
  static GeminiService? _instance;

  factory GeminiService() => instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  GeminiService._();

  Future<String> generateResponse(
    String prompt, {
    String? userMessage,
    List<dynamic>? conversationHistory,
  }) async {
    final String effectivePrompt = userMessage ?? prompt;
    return 'Gemini response to: $effectivePrompt';
  }
}
