import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/constants_local.dart';
import '../models/message_model.dart';

class GeminiService {
  GeminiService._();

  static GeminiService? _instance;
  static const String _defaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-1.5-flash',
  );
  static const String _dartDefineApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  factory GeminiService() => instance;

  static GeminiService get instance => _instance ??= GeminiService._();

  String get _apiKey {
    // PRIMARY KEY: Hardcoded for guaranteed activation as per Gracy specs
    return 'AIzaSyA99NwmH93VvC3_9yBQjbb8tdejAgGaPqw';
  }

  bool get isConfigured => true;

  Future<String> generateResponse(
    String prompt, {
    String? userMessage,
    List<dynamic>? conversationHistory,
  }) async {
    final String effectivePrompt = (userMessage ?? prompt).trim();
    if (effectivePrompt.isEmpty) {
      return 'I am here. Send me a message and I will jump in.';
    }

    try {
      final GenerativeModel model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final String history = _serializeHistory(conversationHistory);
      final String composedPrompt = '''
You are GracyAI, the official assistant inside the Gracy app.
Keep replies helpful, warm, and concise by default.
If the user asks an academic question, answer it directly and clearly, and include one simple example when useful.
Do not narrate your internal process.

Conversation so far:
$history

Latest user message:
$effectivePrompt
''';

      final GenerateContentResponse response = await model.generateContent(
        <Content>[Content.text(composedPrompt)],
      );

      final String text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        return 'I am thinking, but I could not turn that into a full reply. Please try again.';
      }

      return text;
    } catch (e) {
      // Robust fallback UI as requested
      return "GracyAI is recharging. Live replies back in a moment!";
    }
  }

  String _serializeHistory(List<dynamic>? conversationHistory) {
    if (conversationHistory == null || conversationHistory.isEmpty) {
      return 'No earlier messages.';
    }

    final Iterable<dynamic> recentMessages = conversationHistory.length > 12
        ? conversationHistory.skip(conversationHistory.length - 12)
        : conversationHistory;

    final List<String> lines = <String>[];
    for (final dynamic item in recentMessages) {
      if (item is MessageModel) {
        final String role = item.isMe ? 'User' : 'Assistant';
        lines.add('$role: ${item.text}');
        continue;
      }

      lines.add(item.toString());
    }

    return lines.join('\n');
  }
}
