import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/message_model.dart';

class GeminiService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _gracyAiBotId = 'gracy_ai_official';
  
  static const String _systemPrompt = '''You are GracyAI, the intellectual core of the Gracy Network. You are witty, brilliant, and an expert in all university domains from Computer Science to Housing. You speak with a touch of wit, use student-friendly language, and prioritize accuracy. If a student asks for 'form', suggest they check Events or Parties categories in Gracy.''';

  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late final GenerativeModel _model;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = await _getApiKey();
      if (apiKey.isEmpty) {
        throw Exception('Gemini API key not found. Please set it in secure storage.');
      }

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        ),
              );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Gemini: $e');
      rethrow;
    }
  }

  Future<String> _getApiKey() async {
    // Try secure storage first
    String? apiKey = await _secureStorage.read(key: _apiKeyKey);
    
    // Fallback to environment variable for development
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
    }
    
    return apiKey;
  }

  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
    _isInitialized = false;
    await initialize();
  }

  Future<String> generateResponse({
    required String userMessage,
    required List<MessageModel> conversationHistory,
    int maxHistoryLength = 10,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Build conversation history for context
      final List<Content> history = [];
      
      // Add recent messages for context (limit to maxHistoryLength)
      final recentMessages = conversationHistory.length > maxHistoryLength
          ? conversationHistory.sublist(conversationHistory.length - maxHistoryLength)
          : conversationHistory;

      for (final message in recentMessages) {
        if (message.senderId == _gracyAiBotId) {
          history.add(Content.text(message.text));
        } else {
          history.add(Content.text(message.text));
        }
      }

      // Add current user message
      history.add(Content.text(userMessage));

      // Generate response
      final response = await _model.generateContent(history);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return 'Sorry, I couldn\'t generate a response. Please try again.';
      }

      return text;
    } catch (e) {
      debugPrint('Error generating AI response: $e');
      return 'Sorry, I\'m having trouble connecting right now. Please try again in a moment.';
    }
  }

  Future<String> generateQuickResponse(String userMessage) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final response = await _model.generateContent([Content.text(userMessage)]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return 'Sorry, I couldn\'t generate a response. Please try again.';
      }

      return text;
    } catch (e) {
      debugPrint('Error generating quick AI response: $e');
      return 'Sorry, I\'m having trouble connecting right now. Please try again in a moment.';
    }
  }

  bool get isInitialized => _isInitialized;

  static String get gracyAiBotId => _gracyAiBotId;
}
