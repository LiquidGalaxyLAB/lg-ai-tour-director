import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class FalAiProvider extends VideoProvider {
  FalAiProvider({required this.apiKey, required this.modelId});

  final String apiKey;
  final String modelId;
  final Dio _dio = Dio();

  static const _base = 'https://queue.fal.run';
  static const _type = VideoProviderType.falAi;

  Options get _opts => Options(
    headers: {
      'Authorization': 'Key $apiKey',
      'Content-Type': 'application/json',
    },
  );

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
  }) async {
    try {
      final r = await _dio.post(
        '$_base/$modelId',
        options: _opts,
        data: {
          'prompt': prompt,
          'duration': durationSeconds,
          'aspect_ratio': '16:9',
        },
      );
      final id = (r.data as Map)['request_id'] as String?;
      if (id == null || id.isEmpty) {
        throw VideoGenerationException.classify(
          'fal.ai response had no request_id: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      debugPrint('[FalAi] submitted job $id');
      return id;
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    try {
      final r = await _dio.get('$_base/requests/$jobId/status', options: _opts);
      final status = ((r.data as Map)['status'] as String?)?.toUpperCase();
      if (status == 'FAILED') {
        debugPrint('[FalAi] job $jobId FAILED: ${r.data}');
        throw VideoGenerationException.classify(
          'fal.ai generation failed: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      return status == 'COMPLETED';
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    try {
      final r = await _dio.get('$_base/requests/$jobId', options: _opts);
      final d = r.data;
      final candidates = <(String, String?)>[
        ('video.url', nestedString(d, ['video', 'url'])),
        ('video_url', nestedString(d, ['video_url'])),
        ('output.video.url', nestedString(d, ['output', 'video', 'url'])),
        ('output.video_url', nestedString(d, ['output', 'video_url'])),
      ];
      for (final (path, url) in candidates) {
        if (url != null && url.isNotEmpty) {
          debugPrint('[FalAi] video URL found at path: $path');
          return url;
        }
      }
      throw VideoGenerationException.classify(
        'fal.ai response contained no video URL: $d',
        _type,
        modelId: modelId,
      );
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final r = await _dio.get('https://fal.run/models', options: _opts);
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
