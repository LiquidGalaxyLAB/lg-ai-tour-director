import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class VllmOmniProvider extends VideoProvider {
  VllmOmniProvider({required this.baseUrl, this.modelId = ''});

  final String baseUrl;
  final String modelId;
  final Dio _dio = Dio();

  static const _type = VideoProviderType.vllmOmni;

  Options get _opts => Options(headers: {'Content-Type': 'application/json'});

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  String get providerName => 'Local (vLLM-Omni)';

  @override
  int get maxClipDurationSeconds => 999;

  @override
  bool get hasNativeAudio => false;

  @override
  Future<String> submitJob({
    required String prompt,
    required int durationSeconds,
  }) async {
    try {
      final r = await _dio.post(
        '$_root/v1/videos',
        options: _opts,
        data: {'model': modelId, 'prompt': prompt, 'duration': durationSeconds},
      );
      final d = r.data as Map;
      final id = (d['id'] ?? d['request_id']) as String?;
      if (id == null || id.isEmpty) {
        throw VideoGenerationException.classify(
          'vLLM-Omni response had no id/request_id: $d',
          _type,
        );
      }
      debugPrint('[VllmOmni] submitted job $id');
      return id;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    try {
      final r = await _dio.get('$_root/v1/videos/$jobId', options: _opts);
      final status = ((r.data as Map)['status'] as String?)?.toLowerCase();
      if (status == 'failed') {
        debugPrint('[VllmOmni] job $jobId failed: ${r.data}');
        throw VideoGenerationException.classify(
          'vLLM-Omni generation failed: ${r.data}',
          _type,
        );
      }
      return status == 'completed';
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    try {
      final r = await _dio.get('$_root/v1/videos/$jobId', options: _opts);
      final d = r.data as Map;
      final url = (d['url'] ?? d['video_url']) as String?;
      if (url == null || url.isEmpty) {
        throw VideoGenerationException.classify(
          'vLLM-Omni response contained no video URL: $d',
          _type,
        );
      }
      debugPrint('[VllmOmni] video URL: $url');
      return url;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> testConnection() async {
    for (final path in ['/health', '/v1/models']) {
      try {
        final r = await _dio.get('$_root$path', options: _opts);
        if (r.statusCode == 200) return true;
      } on DioException {
        continue;
      }
    }
    debugPrint('[VllmOmni] cannot reach local server at $_root');
    throw VideoGenerationException(
      type: VideoGenerationError.unknown,
      rawMessage: 'connection refused: $_root',
      userMessage:
          'Cannot connect to local server at $baseUrl. Make sure vLLM-Omni is '
          'running: vllm serve <model> --omni',
    );
  }
}
