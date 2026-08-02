import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum VideoProviderType {
  falAi, // fal.ai queue API
  veo3, // Google Veo 3 via Gemini API
  runway, // Runway Gen-4
  klingDirect, // Kling's own API
  vllmOmni, // local vLLM-Omni /v1/videos
  custom, // user-defined endpoint
}

extension VideoProviderTypeLabel on VideoProviderType {
  String get label {
    switch (this) {
      case VideoProviderType.falAi:
        return 'fal.ai';
      case VideoProviderType.veo3:
        return 'Google Veo 3';
      case VideoProviderType.runway:
        return 'Runway Gen-4';
      case VideoProviderType.klingDirect:
        return 'Kling';
      case VideoProviderType.vllmOmni:
        return 'Local (vLLM-Omni)';
      case VideoProviderType.custom:
        return 'Custom';
    }
  }
}

class VideoGenerationSettings {
  const VideoGenerationSettings({
    this.providerType = VideoProviderType.falAi,
    this.baseUrl = '',
    this.apiKey = '',
    this.modelId = '',
    this.durationPerLocationSeconds = 8,
    this.isEnabled = false,
  });

  final VideoProviderType providerType;
  final String baseUrl;
  final String apiKey;
  final String modelId;
  final int durationPerLocationSeconds; // 5 to 500

  /// Whether the AI Film feature is turned on (drives the post-tour prompt).
  /// Off until the user saves a valid configuration and enables it.
  final bool isEnabled;

  bool get isConfigured => apiKey.isNotEmpty && baseUrl.isNotEmpty;

  static const String _prefsKey = 'video_generation_settings';

  Map<String, dynamic> toMap() => {
    'providerType': providerType.name,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'modelId': modelId,
    'durationPerLocationSeconds': durationPerLocationSeconds,
    'isEnabled': isEnabled,
  };

  factory VideoGenerationSettings.fromMap(Map<String, dynamic> map) {
    return VideoGenerationSettings(
      providerType: VideoProviderType.values.firstWhere(
        (t) => t.name == map['providerType'],
        orElse: () => VideoProviderType.falAi,
      ),
      baseUrl: map['baseUrl'] as String? ?? '',
      apiKey: map['apiKey'] as String? ?? '',
      modelId: map['modelId'] as String? ?? '',
      durationPerLocationSeconds:
          (map['durationPerLocationSeconds'] as num?)?.toInt() ?? 8,
      isEnabled: map['isEnabled'] as bool? ?? false,
    );
  }

  VideoGenerationSettings copyWith({
    VideoProviderType? providerType,
    String? baseUrl,
    String? apiKey,
    String? modelId,
    int? durationPerLocationSeconds,
    bool? isEnabled,
  }) {
    return VideoGenerationSettings(
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
      durationPerLocationSeconds:
          durationPerLocationSeconds ?? this.durationPerLocationSeconds,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  static Future<VideoGenerationSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      return VideoGenerationSettings.fromMap(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(toMap()));
  }
}
