import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_exception.dart';
import 'llm_prompts.dart';

/// Calls ANY OpenAI-compatible chat-completions endpoint : OpenRouter, a local
/// Ollama / LM Studio server etc speaking in same format
///
/// Configured purely by [baseUrl] + [apiKey] + [model]; there's no provider specific logic
///
/// The endpoint hit is always `{baseUrl}/chat/completions`
///
/// https://openrouter.ai/api/v1   (OpenRouter)
/// http://localhost:11434/v1      (Ollama)
/// http://localhost:1234/v1       (LM Studio)
/// https://api.groq.com/openai/v1 (Groq)
/// https://api.together.xyz/v1    (Together.ai)

class LLMClient {
  LLMClient({
    required String baseUrl,
    required this.apiKey,
    required this.model,
  }) : baseUrl = _normaliseBaseUrl(baseUrl);

  final String baseUrl;
  final String apiKey;
  final String model;

  final Dio _dio = Dio();

  static String _normaliseBaseUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) {
      debugPrint('[LLMClient] baseUrl missing scheme, prepending http://');
      return 'http://$trimmed';
    }
    return trimmed;
  }

  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final url = '$baseUrl/chat/completions';
    debugPrint(
      '[LLMClient] url: $url, model: $model, '
      'prompt_chars: ${systemPrompt.length + userPrompt.length}',
    );
    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://liquidgalaxy.eu',
            'X-Title': 'LG AI Tour Director GSoC 2026',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.7,
        },
      );
      final content =
          response.data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw LlmException(
          'The model returned an empty response. Try a different model.',
          isSetupIssue: true,
        );
      }
      debugPrint('[LLMClient] raw response:\n$content');
      return content;
    } on DioException catch (e) {
      debugPrint('[LLMClient] error: ${e.response?.data ?? e.message}');
      throw LlmException.fromDio(e);
    }
  }

  //Creative Director : extract 4-6 locations from a travel prompt (raw JSON)
  Future<String> extractLocations(String travelPrompt) => generate(
    systemPrompt: LLMPrompts.creativeDirectorSystem,
    userPrompt: travelPrompt,
  );

  //Writer : narration for a single location (raw JSON)
  Future<String> generateNarration(String locationJson) async {
    final languageName = await _narrationLanguageName();
    final systemPrompt =
        '${LLMPrompts.writerSystem}\n'
        'Generate the narration in $languageName. '
        'Use proper $languageName grammar and vocabulary. '
        'Keep it natural and speakable.';
    return generate(
      systemPrompt: systemPrompt,
      userPrompt: 'Generate narration for: $locationJson',
    );
  }

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'hi': 'Hindi',
    'ar': 'Arabic',
    'de': 'German',
    'pt': 'Portuguese',
    'zh': 'Chinese',
  };

  Future<String> _narrationLanguageName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pref_subtitle_language');
      if (saved == null || saved.trim().isEmpty) return 'English';
      // Stored as a code → map to a name.
      final byCode = _languageNames[saved.toLowerCase()];
      if (byCode != null) return byCode;
      // Otherwise it is already a display name (e.g. "English").
      return saved;
    } catch (_) {
      return 'English';
    }
  }

  //Fallback : alternative name for a location that failed geocoding
  Future<String> suggestFallbackLocation(String failedName) => generate(
    systemPrompt: LLMPrompts.fallbackLocationSystem,
    userPrompt: 'Original failed location: $failedName',
  );

  Future<void> testConnection() =>
      generate(systemPrompt: 'Reply with exactly: OK', userPrompt: 'test');
}
