/// Common contract every AI video backend implements. Concrete providers live
/// in `providers/`; construct them via VideoProviderFactory.
abstract class VideoProvider {
  /// Provider name for display.
  String get providerName;

  /// Max duration this provider supports per single clip — drives chunking.
  int get maxClipDurationSeconds;

  /// Whether generated clips include their own audio.
  bool get hasNativeAudio;

  /// Submit a generation job. Returns a jobId to poll.
  Future<String> submitJob({
    required String prompt,
    required int durationSeconds, // capped to maxClipDuration internally
  });

  /// Poll job status. True when the clip is ready.
  Future<bool> isJobComplete(String jobId);

  /// The video URL once the job is complete.
  Future<String> getVideoUrl(String jobId);

  /// Test connection with a minimal request. True if key + endpoint are valid.
  Future<bool> testConnection();

  /// Convenience: submit + poll + return the URL, reporting progress via
  /// [onStatusUpdate].
  Future<String> generateAndWait({
    required String prompt,
    required int durationSeconds,
    required void Function(String status) onStatusUpdate,
  });
}
