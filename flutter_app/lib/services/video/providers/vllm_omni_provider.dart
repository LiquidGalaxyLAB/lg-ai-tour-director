import '../video_provider.dart';

/// Local vLLM-Omni `/v1/videos` endpoint. Wiring lands in Prompt 3.
class VllmOmniProvider extends VideoProvider {
  VllmOmniProvider({required this.baseUrl});

  final String baseUrl;

  @override
  String get providerName => 'Local (vLLM-Omni)';

  @override
  int get maxClipDurationSeconds => 999; // no hard limit

  @override
  bool get hasNativeAudio => false;

  @override
  Future<String> submitJob({
    required String prompt,
    required int durationSeconds,
  }) => throw UnimplementedError('Implemented in Prompt 3');

  @override
  Future<bool> isJobComplete(String jobId) =>
      throw UnimplementedError('Implemented in Prompt 3');

  @override
  Future<String> getVideoUrl(String jobId) =>
      throw UnimplementedError('Implemented in Prompt 3');

  @override
  Future<bool> testConnection() =>
      throw UnimplementedError('Implemented in Prompt 3');

  @override
  Future<String> generateAndWait({
    required String prompt,
    required int durationSeconds,
    required void Function(String status) onStatusUpdate,
  }) => throw UnimplementedError('Implemented in Prompt 3');
}
