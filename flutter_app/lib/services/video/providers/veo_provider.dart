import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class VeoProvider extends VideoProvider {
  VeoProvider({required this.apiKey});

  final String apiKey;
  final Dio _dio = Dio();

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static const _type = VideoProviderType.veo3;

  Options get _opts => Options(
    headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
  );

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
  }) async {
    try {
      final r = await _dio.post(
        '$_base/models/veo-003:generateVideo',
        options: _opts,
        data: {
          'prompt': {'text': prompt},
          'generationConfig': {
            'durationSeconds': durationSeconds,
            'aspectRatio': '16:9',
          },
        },
      );
      final name = (r.data as Map)['name'] as String?;
      if (name == null || name.isEmpty) {
        throw VideoGenerationException.classify(
          'Veo response had no operation name: ${r.data}',
          _type,
        );
      }
      debugPrint('[Veo] submitted operation $name');
      return name;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    try {
      final r = await _dio.get('$_base/$jobId', options: _opts);
      final d = r.data as Map;
      if (d['error'] != null) {
        debugPrint('[Veo] operation error: ${d['error']}');
        throw VideoGenerationException.classify(d['error'], _type);
      }
      return d['done'] == true;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    try {
      final r = await _dio.get('$_base/$jobId', options: _opts);
      final uri = nestedString(r.data, ['response', 'videos', 0, 'uri']);
      if (uri == null || uri.isEmpty) {
        throw VideoGenerationException.classify(
          'Veo response contained no video uri: ${r.data}',
          _type,
        );
      }
      // gs://bucket/path → https://storage.googleapis.com/bucket/path
      final url = uri.startsWith('gs://')
          ? 'https://storage.googleapis.com/${uri.substring(5)}'
          : uri;
      debugPrint('[Veo] video URL: $url');
      return url;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final r = await _dio.get('$_base/models', options: _opts);
      final models = (r.data as Map)['models'];
      final hasVeo =
          models is List &&
          models.any(
            (m) => (m is Map ? m['name']?.toString() ?? '' : '')
                .toLowerCase()
                .contains('veo'),
          );
      if (!hasVeo) {
        throw VideoGenerationException.classify(
          'model veo not found in models list',
          _type,
          modelId: 'veo-003',
        );
      }
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401) {
        throw VideoGenerationException.classify('401 unauthorized', _type);
      }
      throwClassified(e, _type);
    } catch (e) {
      throwClassified(e, _type);
    }
  }
}
