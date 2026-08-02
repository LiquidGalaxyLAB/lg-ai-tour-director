import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class RunwayProvider extends VideoProvider {
  RunwayProvider({required this.apiKey, this.modelId = 'gen4_turbo'});

  final String apiKey;
  final String modelId;
  final Dio _dio = Dio();

  static const _base = 'https://api.dev.runwayml.com/v1';
  static const _type = VideoProviderType.runway;

  Options get _opts => Options(
    headers: {
      'Authorization': 'Bearer $apiKey',
      'X-Runway-Version': '2024-11-06',
      'Content-Type': 'application/json',
    },
  );

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
  }) async {
    try {
      final r = await _dio.post(
        '$_base/text_to_video',
        options: _opts,
        data: {
          'promptText': prompt,
          'duration': durationSeconds,
          'ratio': '1280:720',
          'model': modelId,
        },
      );
      final id = (r.data as Map)['id'] as String?;
      if (id == null || id.isEmpty) {
        throw VideoGenerationException.classify(
          'Runway response had no task id: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      debugPrint('[Runway] submitted task $id');
      return id;
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    try {
      final r = await _dio.get('$_base/tasks/$jobId', options: _opts);
      final status = ((r.data as Map)['status'] as String?)?.toUpperCase();
      if (status == 'FAILED') {
        debugPrint('[Runway] task $jobId FAILED: ${r.data}');
        throw VideoGenerationException.classify(
          'Runway generation failed: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      return status == 'SUCCEEDED';
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    try {
      final r = await _dio.get('$_base/tasks/$jobId', options: _opts);
      final url = nestedString(r.data, ['output', 0]);
      if (url == null || url.isEmpty) {
        throw VideoGenerationException.classify(
          'Runway response contained no output URL: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      debugPrint('[Runway] video URL: $url');
      return url;
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final r = await _dio.get('$_base/organization', options: _opts);
      return r.statusCode == 200;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw VideoGenerationException.classify('401 unauthorized', _type);
      }
      throwClassified(e, _type);
    } catch (e) {
      throwClassified(e, _type);
    }
  }
}
