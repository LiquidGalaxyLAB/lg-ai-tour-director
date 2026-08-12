import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class CustomProvider extends VideoProvider {
  CustomProvider({
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
  });

  final String baseUrl;
  final String apiKey;
  final String modelId;
  final Dio _dio = Dio();

  static const _type = VideoProviderType.custom;
  static const _sync = 'sync:';

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Options get _opts => Options(
    headers: {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    },
  );

  @override
  String get providerName => 'Custom';

  @override
  int get maxClipDurationSeconds => 10;

  @override
  bool get hasNativeAudio => false;

  Future<Response<dynamic>> _post(List<String> paths, Object data) async {
    Object lastErr = Exception('no endpoint reachable');
    for (final p in paths) {
      try {
        return await _dio.post('$_root$p', options: _opts, data: data);
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr;
  }

  Future<Response<dynamic>> _get(List<String> paths) async {
    Object lastErr = Exception('no endpoint reachable');
    for (final p in paths) {
      try {
        return await _dio.get('$_root$p', options: _opts);
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr;
  }

  @override
  Future<String> submitJob({
    required String prompt,
    required int durationSeconds,
  }) async {
    try {
      final r = await _post(
        ['/videos', '/v1/videos'],
        {
          'prompt': prompt,
          'duration': durationSeconds,
          'model': modelId,
          'aspect_ratio': '16:9',
        },
      );
      final d = r.data;
      final id =
          nestedString(d, ['request_id']) ??
          nestedString(d, ['id']) ??
          nestedString(d, ['job_id']) ??
          nestedString(d, ['task_id']);
      if (id != null && id.isNotEmpty) {
        debugPrint('[Custom] submitted job $id');
        return id;
      }
      // Endpoint returned synchronously with the URL — treat as complete.
      final syncUrl =
          nestedString(d, ['url']) ?? nestedString(d, ['video_url']);
      if (syncUrl != null && syncUrl.isNotEmpty) {
        debugPrint('[Custom] synchronous response, url: $syncUrl');
        return '$_sync$syncUrl';
      }
      throw VideoGenerationException.classify(
        'Custom endpoint response had no job id or URL: $d',
        _type,
        modelId: modelId,
      );
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    if (jobId.startsWith(_sync)) return true;
    try {
      final r = await _get(['/requests/$jobId/status', '/v1/videos/$jobId']);
      final status =
          (nestedString(r.data, ['status']) ??
                  nestedString(r.data, ['state']) ??
                  '')
              .toLowerCase();
      const done = {'completed', 'succeed', 'succeeded', 'done'};
      if (status == 'failed') {
        throw VideoGenerationException.classify(
          'Custom endpoint reported failure: ${r.data}',
          _type,
          modelId: modelId,
        );
      }
      return done.contains(status);
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    if (jobId.startsWith(_sync)) return jobId.substring(_sync.length);
    try {
      final r = await _get(['/requests/$jobId', '/v1/videos/$jobId']);
      final d = r.data;
      final url =
          nestedString(d, ['video', 'url']) ??
          nestedString(d, ['video_url']) ??
          nestedString(d, ['url']) ??
          nestedString(d, ['output', 0]) ??
          nestedString(d, ['result', 'url']);
      if (url == null || url.isEmpty) {
        throw VideoGenerationException.classify(
          'no video url in response: $d',
          _type,
          modelId: modelId,
        );
      }
      debugPrint('[Custom] video URL: $url');
      return url;
    } catch (e) {
      throwClassified(e, _type, modelId: modelId);
    }
  }

  @override
  Future<bool> testConnection() async {
    for (final path in ['/health', '/v1/models']) {
      try {
        final r = await _dio.get('$_root$path', options: _opts);
        if (r.statusCode == 200) return true;
      } on DioException {
        // try next path
      }
    }
    debugPrint('[Custom] no reachable endpoint at $_root');
    throw VideoGenerationException(
      type: VideoGenerationError.unknown,
      rawMessage: 'no reachable endpoint at $_root',
      userMessage:
          'Could not reach your custom endpoint at $baseUrl. Check the base URL '
          'and that the server exposes /health or /v1/models.',
    );
  }
}
