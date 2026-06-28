import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/constants/app_constants.dart';
import '../../models/location.dart';
import 'llm_service.dart';
import 'prompts.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.geminiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  String? get _apiKey => dotenv.env['GEMINI_KEY'];

  /// First model from [AppConstants.geminiModels] that responded successfully.
  /// Cached so we don't re-probe the whole chain on every call.
  String? _workingModel;

  Future<List<TourLocation>> extractLocations(String userPrompt) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GEMINI_KEY not found in .env');
    }

    // Attempt 1: Standard Prompt
    try {
      debugPrint(
        'GeminiService: Attempt 1 - Extracting locations for: "$userPrompt"',
      );
      final result = await _callApi(GeminiPrompts.buildPrompt(userPrompt));
      final locations = _parseLocations(result);

      if (locations.length < 3) {
        debugPrint(
          'GeminiService: Found fewer than 3 locations. Re-prompting with broader scope...',
        );
        return await _retryBroadScope(userPrompt);
      }
      return locations;
    } catch (e) {
      debugPrint('GeminiService: Error or Malformed JSON on Attempt 1: $e');
      // Attempt 2: Fallback / Malformed JSON fix
      return await _retryFallback(userPrompt);
    }
  }

  Future<List<TourLocation>> _retryFallback(String userPrompt) async {
    try {
      debugPrint('GeminiService: Attempt 2 - Fallback for malformed JSON');
      final result = await _callApi(
        GeminiPrompts.buildFallbackPrompt(userPrompt),
      );
      final locations = _parseLocations(result);
      if (locations.length < 3) {
        return await _retryBroadScope(userPrompt);
      }
      return locations;
    } catch (e) {
      debugPrint('GeminiService: Attempt 2 Failed: $e');
      throw Exception('Failed to extract locations correctly from Gemini.');
    }
  }

  Future<List<TourLocation>> _retryBroadScope(String userPrompt) async {
    try {
      debugPrint('GeminiService: Attempt 3 - Broadening scope');
      final result = await _callApi(
        GeminiPrompts.buildBroadScopePrompt(userPrompt),
      );
      final locations = _parseLocations(result);
      if (locations.isEmpty) {
        throw Exception(
          'Gemini could not find any locations even with a broad scope.',
        );
      }
      return locations;
    } catch (e) {
      debugPrint('GeminiService: Attempt 3 Failed: $e');
      throw Exception('Failed to extract enough locations from Gemini.');
    }
  }

  Future<String?> getAlternativeName(String locationName) async {
    try {
      debugPrint(
        'GeminiService: Asking for alternative name for "$locationName"',
      );
      final result = await _callApi(
        GeminiPrompts.buildAlternativeNamePrompt(locationName),
      );
      return _parseAlternativeName(result);
    } catch (e) {
      debugPrint('GeminiService: Failed to get alternative name: $e');
      return null;
    }
  }

  String _parseAlternativeName(String rawResponse) {
    try {
      final decoded = jsonDecode(rawResponse);
      if (decoded is String) return decoded;
      if (decoded is List && decoded.isNotEmpty) {
        if (decoded.first is Map)
          return decoded.first['name'] ?? decoded.first.values.first.toString();
        return decoded.first.toString();
      }
      if (decoded is Map)
        return decoded['name'] ?? decoded.values.first.toString();
      return decoded.toString();
    } catch (_) {
      return rawResponse.trim().replaceAll('"', '');
    }
  }

  Future<String> _callApi(String promptText) async {
    // Optional override if a tester opted into a custom OpenRouter model, use
    // its response. Returns null when disabled / no key / on failure, so we
    // fall through to the unchanged Gemini chain below.
    final override = await LLMService.instance.maybeOpenRouter(
      GeminiPrompts.systemInstruction,
      promptText,
    );
    if (override != null) return override;

    // Try the cached working model first, then the rest of the chain.
    final models = <String>[
      ?_workingModel,
      ...AppConstants.geminiModels.where((m) => m != _workingModel),
    ];

    Object? lastError;
    for (final model in models) {
      try {
        final text = await _callModel(model, promptText);
        if (_workingModel != model) {
          debugPrint('GeminiService: Using model "$model"');
          _workingModel = model;
        }
        return text;
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        debugPrint(
          'GeminiService: model "$model" failed ($status). '
          '${e.response?.data ?? e.message}',
        );
        lastError = e;
        // Only fall through to the next model when this one is unavailable
        // (not found / quota / capacity). Auth or bad-request errors will
        // fail identically on every model, so stop and surface them.
        if (status == 404 || status == 429 || status >= 500) {
          // If we had cached this model, clear it so we re-probe next time.
          if (_workingModel == model) {
            _workingModel = null;
          }
          continue;
        }
        rethrow;
      }
    }
    throw Exception('All Gemini models failed. Last error: $lastError');
  }

  /// Single generateContent call against one model. Returns the raw text part.
  Future<String> _callModel(String model, String promptText) async {
    final response = await _dio.post(
      'models/$model:generateContent?key=$_apiKey',
      data: {
        "systemInstruction": {
          "parts": [
            {"text": GeminiPrompts.systemInstruction},
          ],
        },
        "contents": [
          {
            "parts": [
              {"text": promptText},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.4,
          "response_mime_type": "application/json",
        },
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final text = candidates.first['content']['parts'][0]['text'] as String;
        debugPrint('GeminiService: Raw Response:\n$text');
        return text;
      }
    }
    throw Exception('Invalid API Response: ${response.statusCode}');
  }

  List<TourLocation> _parseLocations(String rawJson) {
    // Sometimes Gemini wraps JSON in markdown blocks even if instructed not to.
    String cleanJson = rawJson.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
    }

    cleanJson = cleanJson.trim();

    final List<dynamic> decoded = jsonDecode(cleanJson);
    return decoded.map((e) => TourLocation.fromJson(e)).toList();
  }
}
