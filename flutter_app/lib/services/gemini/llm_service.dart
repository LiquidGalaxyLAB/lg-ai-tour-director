import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'open_router_service.dart';

class LLMService {
  LLMService._();
  static final LLMService instance = LLMService._();

  // SharedPreferences keys
  static const String prefUseOpenRouter = 'useOpenRouter';
  static const String prefApiKey = 'openRouterApiKey';
  static const String prefModel = 'openRouterModel';

  static const String defaultModel = 'deepseek/deepseek-chat';

  Future<String?> maybeOpenRouter(
    String systemPrompt,
    String userPrompt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final useOpenRouter = prefs.getBool(prefUseOpenRouter) ?? false;

    if (!useOpenRouter) {
      debugPrint('[LLMService] routing to: gemini');
      return null;
    }

    final key = prefs.getString(prefApiKey) ?? '';
    final model = prefs.getString(prefModel) ?? defaultModel;
    if (key.isEmpty) {
      debugPrint(
        '[LLMService] OpenRouter selected but key empty → routing to: gemini',
      );
      return null;
    }

    debugPrint('[LLMService] routing to: openrouter ($model)');
    final text = await OpenRouterService(
      apiKey: key,
      model: model,
    ).generate(systemPrompt, userPrompt);
    if (text == null || text.trim().isEmpty) {
      debugPrint(
        '[LLMService] OpenRouter returned nothing → falling back to gemini',
      );
      return null;
    }
    return text;
  }
}
