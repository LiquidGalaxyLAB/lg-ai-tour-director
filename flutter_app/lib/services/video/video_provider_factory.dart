import 'dart:math';

import '../../models/video_generation_settings.dart';
import 'providers/custom_provider.dart';
import 'providers/fal_ai_provider.dart';
import 'providers/kling_direct_provider.dart';
import 'providers/runway_provider.dart';
import 'providers/veo_provider.dart';
import 'providers/vllm_omni_provider.dart';
import 'video_provider.dart';

/// Builds the concrete [VideoProvider] for the configured settings and computes
/// the chunking a location's requested duration needs.
class VideoProviderFactory {
  const VideoProviderFactory._();

  static VideoProvider create(VideoGenerationSettings settings) {
    switch (settings.providerType) {
      case VideoProviderType.falAi:
        return FalAiProvider(
          apiKey: settings.apiKey,
          modelId: settings.modelId,
        );
      case VideoProviderType.veo3:
        return VeoProvider(apiKey: settings.apiKey);
      case VideoProviderType.runway:
        return RunwayProvider(apiKey: settings.apiKey);
      case VideoProviderType.klingDirect:
        return KlingDirectProvider(apiKey: settings.apiKey);
      case VideoProviderType.vllmOmni:
        return VllmOmniProvider(baseUrl: settings.baseUrl);
      case VideoProviderType.custom:
        return CustomProvider(
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          modelId: settings.modelId,
        );
    }
  }

  /// How many clips a [requestedSeconds] location must be split into for this
  /// provider's per-clip limit.
  static int chunksNeeded(VideoProvider provider, int requestedSeconds) {
    return (requestedSeconds / provider.maxClipDurationSeconds).ceil();
  }

  /// The duration of a single chunk (never exceeds the provider's limit).
  static int chunkDuration(VideoProvider provider, int requestedSeconds) {
    return min(requestedSeconds, provider.maxClipDurationSeconds);
  }
}
