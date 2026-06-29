import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../llm/open_router_service.dart';

/// LLM router. **OpenRouter is currently the only active path** — Gemini stays
/// fully intact and wired (see [GeminiService]) but is not invoked from the UI.
///
/// This class lives under services/gemini/ only because [GeminiService] imports
/// it for its internal [maybeOpenRouter] hook (and GeminiService must not be
/// touched). The active OpenRouter implementation lives in services/llm/.
class LLMService {
  LLMService._();
  static final LLMService instance = LLMService._();

  // SharedPreferences keys (shared with the AI Configuration screen).
  static const String prefUseOpenRouter = 'useOpenRouter';
  static const String prefApiKey = 'openRouterApiKey';
  static const String prefModel = 'openRouterModel';

  static const String defaultModel = 'deepseek/deepseek-chat';

  /// Active router: routes generation to the configured OpenRouter model.
  /// Returns null when no key is set — the caller then shows an
  /// "AI not configured" message.
  Future<String?> generate(String systemPrompt, String userPrompt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(prefApiKey) ?? '';
    final model = prefs.getString(prefModel) ?? defaultModel;

    if (key.isEmpty) {
      debugPrint('[LLMService] No OpenRouter key configured');
      return null;
    }

    debugPrint('[LLMService] routing to: openrouter ($model)');
    return OpenRouterService(apiKey: key, model: model)
        .generate(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Dormant Gemini hook. [GeminiService] calls this internally; returning null
  /// makes it fall through to its own (fully intact) Gemini logic. Gemini is
  /// simply not invoked from the UI right now.
  ///
  /// To re-enable Gemini routing later, restore the original opt-in logic here
  /// (read [prefUseOpenRouter] and return OpenRouter text only when enabled).
  Future<String?> maybeOpenRouter(String systemPrompt, String userPrompt) async =>
      null;
}
