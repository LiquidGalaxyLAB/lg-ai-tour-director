import '../video_provider.dart';

/// fal.ai queue API. Wiring lands in Prompt 3.
class FalAiProvider extends VideoProvider {
  FalAiProvider({required this.apiKey, required this.modelId});

  final String apiKey;
  final String modelId;

  @override
  String get providerName => 'fal.ai';

  @override
  int get maxClipDurationSeconds => 10;

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
