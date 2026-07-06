import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../llm/llm_client.dart';

class LLMService {
  LLMService._();
  static final LLMService instance = LLMService._();

  static const String prefBaseUrl = 'llmBaseUrl';
  static const String prefApiKey = 'llmApiKey';
  static const String prefModel = 'llmModel';

  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'deepseek/deepseek-chat';

  static const String _oldApiKey = 'openRouterApiKey';
  static const String _oldModel = 'openRouterModel';
  static const String _oldUseOpenRouter = 'useOpenRouter';

  static Future<void> migrateLegacyKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final hasNew =
        prefs.containsKey(prefBaseUrl) ||
        prefs.containsKey(prefApiKey) ||
        prefs.containsKey(prefModel);
    final hasOld =
        prefs.containsKey(_oldApiKey) ||
        prefs.containsKey(_oldModel) ||
        prefs.containsKey(_oldUseOpenRouter);
    if (hasNew || !hasOld) return;

    debugPrint('[LLMService] migrating legacy OpenRouter keys → generic keys');
    final oldKey = prefs.getString(_oldApiKey);
    final oldModel = prefs.getString(_oldModel);
    if (oldKey != null) await prefs.setString(prefApiKey, oldKey);
    if (oldModel != null) await prefs.setString(prefModel, oldModel);
    await prefs.setString(prefBaseUrl, defaultBaseUrl);

    await prefs.remove(_oldApiKey);
    await prefs.remove(_oldModel);
    await prefs.remove(_oldUseOpenRouter);
  }

  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString(prefBaseUrl) ?? defaultBaseUrl).trim();
    final key = (prefs.getString(prefApiKey) ?? '').trim();
    final model = (prefs.getString(prefModel) ?? defaultModel).trim();
    if (baseUrl.isEmpty || model.isEmpty) return false;
    final isLocal =
        baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    return isLocal || key.isNotEmpty;
  }

  Future<String?> generate(String systemPrompt, String userPrompt) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(prefBaseUrl) ?? defaultBaseUrl;
    final key = prefs.getString(prefApiKey) ?? '';
    final model = prefs.getString(prefModel) ?? defaultModel;

    if (baseUrl.trim().isEmpty) {
      debugPrint('[LLMService] No LLM endpoint configured');
      return null;
    }

    debugPrint('[LLMService] routing to: $baseUrl ($model)');
    return LLMClient(
      baseUrl: baseUrl,
      apiKey: key,
      model: model,
    ).generate(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  Future<String?> maybeOpenRouter(
    String systemPrompt,
    String userPrompt,
  ) async => null;
}
