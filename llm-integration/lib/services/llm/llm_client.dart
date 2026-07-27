import 'package:dio/dio.dart';

import 'llm_exception.dart';

/// Calls ANY OpenAI-compatible chat-completions endpoint: OpenRouter, Groq,
/// Together.ai, OpenAI, or a local Ollama / LM Studio server — they all speak
/// the same format.
///
/// Configured purely by [baseUrl] + [apiKey] + [model]; there is no
/// provider-specific logic. The endpoint hit is always
/// `{baseUrl}/chat/completions`.
///
///   https://openrouter.ai/api/v1     (OpenRouter)
///   https://api.groq.com/openai/v1   (Groq)
///   http://localhost:11434/v1        (Ollama, local — no key needed)
///   http://localhost:1234/v1         (LM Studio, local — no key needed)
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
    if (!trimmed.startsWith('http')) return 'http://$trimmed';
    return trimmed;
  }

  /// Sends [systemPrompt] (the role / instructions) and [userPrompt] (the
  /// actual request) to the model and returns its reply as plain text.
  ///
  /// Throws [LlmException] with a friendly, user-showable message on any
  /// failure (bad key, no credit, wrong model, timeout, etc.).
  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final url = '$baseUrl/chat/completions';
    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
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
        );
      }
      return content;
    } on DioException catch (e) {
      throw LlmException.fromDio(e);
    }
  }

  /// Sends one tiny request to confirm the URL, key and model all work.
  /// Returns normally on success; throws [LlmException] on failure.
  Future<void> testConnection() =>
      generate(systemPrompt: 'Reply with exactly: OK', userPrompt: 'test');
}
