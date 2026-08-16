import '../../models/video_generation_settings.dart';

/// A per-second rate + a human label for the cost estimate. [perSecond] is null
/// when the rate is unknown (custom endpoints).
class VideoCostRate {
  const VideoCostRate(this.perSecond, this.label);
  final double? perSecond;
  final String label;
}

/// Hardcoded, clearly-labelled cost *estimates* (USD/sec). Real charges depend
/// on each provider's live pricing — this is only a rough guide for the UI.
class VideoCost {
  const VideoCost._();

  static VideoCostRate rate(VideoProviderType type, String modelId) {
    switch (type) {
      case VideoProviderType.falAi:
        // fal.ai pay-as-you-go, 720p / audio off (verified Aug 2026).
        final m = modelId.toLowerCase();
        if (m.contains('kling')) return const VideoCostRate(0.084, 'Kling v3');
        if (m.contains('wan')) return const VideoCostRate(0.08, 'WAN 2.2 720p');
        if (m.contains('minimax') || m.contains('hailuo')) {
          return const VideoCostRate(0.045, 'Hailuo 02');
        }
        // LTX bills a flat ~$0.02/clip; expressed per-second for the estimate.
        if (m.contains('ltx'))
          return const VideoCostRate(0.004, 'LTX ~\$0.02/clip');
        return const VideoCostRate(0.06, 'fal.ai');
      case VideoProviderType.veo3:
        return const VideoCostRate(0.40, 'Veo 3 (Fast \$0.15)');
      case VideoProviderType.runway:
        return const VideoCostRate(0.05, 'Runway Gen-4 Turbo');
      case VideoProviderType.klingDirect:
        return const VideoCostRate(0.09, 'Kling direct');
      case VideoProviderType.vllmOmni:
        return const VideoCostRate(0.0, 'Free (local)');
      case VideoProviderType.custom:
        return const VideoCostRate(null, 'Unknown');
    }
  }

  /// Total estimate in USD, or null if the rate is unknown.
  static double? estimateUsd({
    required VideoProviderType type,
    required String modelId,
    required int durationPerLocation,
    required int locationCount,
  }) {
    final r = rate(type, modelId).perSecond;
    if (r == null) return null;
    return durationPerLocation * locationCount * r;
  }
}
