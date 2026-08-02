import '../video_provider.dart';

/// Runway Gen-4. Wiring lands in Prompt 3.
class RunwayProvider extends VideoProvider {
  RunwayProvider({required this.apiKey});

  final String apiKey;

  @override
  String get providerName => 'Runway Gen-4';

  @override
  int get maxClipDurationSeconds => 16;

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
