import 'package:dio/dio.dart';

class LlmException implements Exception {
  LlmException(this.message, {this.isSetupIssue = false});

  final String message;
  final bool isSetupIssue;

  @override
  String toString() => message;

  factory LlmException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return LlmException(
          'The AI request timed out. Check your connection and try again.',
        );
      case DioExceptionType.connectionError:
        return LlmException(
          'No internet connection. Check your network and try again.',
        );
      default:
        break;
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;
    final apiMsg = (data is Map && data['error'] is Map)
        ? data['error']['message']?.toString()
        : (data is Map ? data['message']?.toString() : null);

    switch (status) {
      case 401:
      case 403:
        return LlmException(
          'Invalid or missing API key. Re-copy the key from your AI provider '
          'and paste it correctly in AI Configuration. Local models can leave '
          'the key empty.',
          isSetupIssue: true,
        );
      case 402:
        return LlmException(
          'Your AI provider account is out of credits or quota. Add credit, or '
          'switch to a free or local model, then try again.',
          isSetupIssue: true,
        );
      case 400:
      case 404:
        return LlmException(
          'Model not found or invalid model ID${apiMsg != null ? ' ($apiMsg)' : ''}. '
          'Enter the exact model ID your provider expects in AI Configuration '
          '(e.g. deepseek/deepseek-chat, openai/gpt-4o-mini, or llama3).',
          isSetupIssue: true,
        );
      case 429:
        return LlmException(
          'Rate limit reached on your AI provider. Wait a moment and try again.',
        );
      default:
        return LlmException(
          'AI request failed${status != null ? ' ($status)' : ''}'
          '${apiMsg != null ? ': $apiMsg' : ''}. Try again or check AI '
          'Configuration.',
          isSetupIssue: status != null && status >= 400 && status < 500,
        );
    }
  }
}
