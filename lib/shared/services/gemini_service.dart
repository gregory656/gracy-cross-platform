import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const String offlineMaintenanceMessage =
      'AI is offline for maintenance. Please try again shortly.';

  String get _apiKey {
    if (_dartDefineApiKey.trim().isNotEmpty) {
      return _dartDefineApiKey.trim();
    }
    return SupabaseLocalConfig.geminiApiKey.trim();
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String> generateResponse(
    String prompt, {
    String? userMessage,
    List<dynamic>? conversationHistory,
  }) async {
    final String effectivePrompt = (userMessage ?? prompt).trim();
    if (effectivePrompt.isEmpty) {
      return 'I am here. Send me a message and I will jump in.';
    }

    if (!isConfigured) {
      return offlineMaintenanceMessage;
    }

    try {
      final GenerativeModel model = GenerativeModel(
        model: _defaultModel,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 2048,
        ),
      );

      final String history = _serializeHistory(conversationHistory);
      final String composedPrompt =
          '''
You are GracyAI, the elite campus super-app intelligence. 
PERSONALITY: Warm, highly technical when needed, and deeply helpful to students.
CAPABILITIES: Academic tutoring, campus life planning, marketplace advice, and social hub navigation.

RESPONSE STYLE:
1. Use Markdown for richness: **bold** for emphasis, `code` for technical terms or lists, and bullet points.
2. If the user asks a technical/academic question, explain it clearly with an example.
3. Keep it premium—no robotic narration.

CONTEXT:
Conversation so far:
$history

LATEST USER REQUEST:
$effectivePrompt
''';

      final GenerateContentResponse response = await model.generateContent(
        <Content>[Content.text(composedPrompt)],
      );

      final String text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        return 'I am processing your request. Could you rephrase that?';
      }

      return text;
    } catch (e) {
      debugPrint('Gemini Error: $e');
      return offlineMaintenanceMessage;
    }
  }

  Future<List<String>> generateCampusImageCaptions(File imageFile) async {
    if (!isConfigured) {
      return const <String>[
        'Campus energy, main character edition.',
        'Proof that student life has range.',
        'Somewhere between deadline mode and good vibes.',
      ];
    }

    try {
      final GenerativeModel model = GenerativeModel(
        model: _defaultModel,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.85,
          topP: 0.95,
          maxOutputTokens: 220,
        ),
      );
      final Uint8List bytes = await imageFile.readAsBytes();
      final GenerateContentResponse response = await model.generateContent(
        <Content>[
          Content.multi(<Part>[
            TextPart(
              'Analyze this image and write exactly 3 short, witty campus-vibe captions. Return one caption per line with no numbering.',
            ),
            DataPart('image/webp', bytes),
          ]),
        ],
      );

      final List<String> captions = (response.text ?? '')
          .split('\n')
          .map((String line) => line.replaceFirst(RegExp(r'^\s*[-*\d.]+\s*'), '').trim())
          .where((String line) => line.isNotEmpty)
          .take(3)
          .toList(growable: false);
      final List<String> resolvedCaptions = captions.length == 3
          ? captions
          : const <String>[
              'Campus energy, main character edition.',
              'Proof that student life has range.',
              'Somewhere between deadline mode and good vibes.',
            ];
      await _persistAiResponse(resolvedCaptions.join('\n'));
      return resolvedCaptions;
    } catch (e) {
      debugPrint('Gemini image caption error: $e');
      return const <String>[
        'Campus energy, main character edition.',
        'Proof that student life has range.',
        'Somewhere between deadline mode and good vibes.',
      ];
    }
  }

  Future<void> _persistAiResponse(String content) async {
    try {
      final SupabaseClient client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        return;
      }
      await client.from('messages').insert(<String, dynamic>{
        'room_id': 'gracy_ai_caption_lab',
        'sender_id': 'gracy_ai_official',
        'content': content,
      });
    } catch (e) {
      debugPrint('Failed to persist AI caption response: $e');
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
