import '../video_provider.dart';

/// Google Veo 3 via the Gemini API. Wiring lands in Prompt 3.
class VeoProvider extends VideoProvider {
  VeoProvider({required this.apiKey});

  final String apiKey;

  @override
  String get providerName => 'Google Veo 3';

  @override
  int get maxClipDurationSeconds => 8;

  @override
  bool get hasNativeAudio => true;

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
