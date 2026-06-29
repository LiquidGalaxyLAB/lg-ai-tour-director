import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'open_router_prompts.dart';

/// Calls any model on OpenRouter (openrouter.ai) via the OpenAI-compatible
/// chat-completions format. One key → 300+ models (DeepSeek, GPT, Claude,
/// Llama, …). Standalone — shares no code with GeminiService.
class OpenRouterService {
  OpenRouterService({required this.apiKey, String? model})
      : model = model ?? _defaultModel;

  static const String _base = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _defaultModel = 'deepseek/deepseek-chat';

  final String apiKey;
  final String model;

  final Dio _dio = Dio();

  /// Generic completion — system + user prompt in, raw assistant text out.
  /// Returns null on any error (caller decides how to surface it).
  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    debugPrint(
      '[OpenRouter] model: $model, '
      'prompt_chars: ${systemPrompt.length + userPrompt.length}',
    );
    try {
      final response = await _dio.post(
        _base,
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
      return response.data['choices']?[0]?['message']?['content'] as String?;
    } on DioException catch (e) {
      debugPrint('[OpenRouter] error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      debugPrint('[OpenRouter] error: $e');
      return null;
    }
  }

  /// Creative Director — extract 4-6 locations from a travel prompt (raw JSON).
  Future<String?> extractLocations(String travelPrompt) => generate(
        systemPrompt: OpenRouterPrompts.creativeDirectorSystem,
        userPrompt: travelPrompt,
      );

  /// Writer — narration for a single location (raw JSON).
  Future<String?> generateNarration(String locationJson) => generate(
        systemPrompt: OpenRouterPrompts.writerSystem,
        userPrompt: 'Generate narration for: $locationJson',
      );

  /// Fallback — alternative name for a location that failed geocoding.
  Future<String?> suggestFallbackLocation(String failedName) => generate(
        systemPrompt: OpenRouterPrompts.fallbackLocationSystem,
        userPrompt: 'Original failed location: $failedName',
      );

  /// Used by the settings screen's "Test Connection" button.
  Future<bool> testConnection() async {
    final result = await generate(
      systemPrompt: 'Reply with exactly: OK',
      userPrompt: 'test',
    );
    return result != null && result.trim().contains('OK');
  }
}
