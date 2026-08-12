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

  // fal.ai's `duration` is a STRING and only accepts "5", "10" or "15".
  String _falDuration(int seconds) =>
      seconds <= 5 ? '5' : (seconds <= 10 ? '10' : '15');

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
          'duration': _falDuration(durationSeconds),
          'aspect_ratio': '16:9',
          'resolution': '720p',
        },
      );
      final data = r.data as Map;
      final id = data['request_id'] as String?;
      if (id == null || id.isEmpty) {
        throw VideoGenerationException.classify(
          'fal.ai response had no request_id: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      // fal's status/result live UNDER the model path — and for sub-path models
      // (e.g. Kling) the base is the app id, not the full endpoint. So use the
      // response_url fal returns rather than constructing it ourselves (building
      // it as .../requests/{id} without the model prefix causes a 405). Returned
      // as the "jobId" the poll methods below GET directly.
      final responseUrl = (data['response_url'] as String?)?.trim();
      debugPrint('[FalAi] submitted job $id');
      return (responseUrl != null && responseUrl.isNotEmpty)
          ? responseUrl
          : '$_base/$modelId/requests/$id';
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    // [jobId] is the full response_url returned by submitJob; status is at
    // "<response_url>/status".
    try {
      final r = await _dio.get('$jobId/status', options: _opts);
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
    // [jobId] is the full response_url returned by submitJob.
    try {
      final r = await _dio.get(jobId, options: _opts);
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
    // fal.ai has no key-only validation endpoint; submit a minimal job and
    // treat a returned request_id as a valid key + reachable model.
    final path = modelId.isNotEmpty ? modelId : 'wan/v2.6/text-to-video';
    try {
      final r = await _dio.post(
        '$_base/$path',
        options: _opts,
        data: {
          'prompt': 'test',
          'duration': '5',
          'aspect_ratio': '16:9',
          'resolution': '720p',
        },
      );
      final id = (r.data as Map)['request_id'] as String?;
      return id != null && id.isNotEmpty;
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
