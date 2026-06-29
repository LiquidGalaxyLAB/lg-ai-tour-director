import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class OpenRouterService {
  OpenRouterService({required this.apiKey, required this.model});

  static const String _base = 'https://openrouter.ai/api/v1/chat/completions';

  final String apiKey;
  final String model;

  final Dio _dio = Dio();

  Future<String?> generate(String systemPrompt, String userPrompt) async {
    try {
      final response = await _dio.post(
        _base,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://liquidgalaxy.eu',
            'X-Title': 'LG AI Tour Director',
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
      debugPrint(
        '[OpenRouter] model: $model, response length: ${content?.length}',
      );
      return content;
    } on DioException catch (e) {
      debugPrint('[OpenRouter] error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      debugPrint('[OpenRouter] error: $e');
      return null;
    }
  }
}
