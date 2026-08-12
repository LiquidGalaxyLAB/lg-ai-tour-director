import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/video_generation_result.dart';
import '../../../models/video_generation_settings.dart';
import '../video_provider.dart';

class KlingDirectProvider extends VideoProvider {
  KlingDirectProvider({required this.apiKey});

  final String apiKey;
  final Dio _dio = Dio();

  static const _base = 'https://api.klingai.com';
  static const _type = VideoProviderType.klingDirect;

  @override
  String get providerName => 'Kling';

  @override
  int get maxClipDurationSeconds => 10;

  @override
  bool get hasNativeAudio => true;

  String get _accessKeyId {
    final i = apiKey.indexOf(':');
    return i < 0 ? apiKey : apiKey.substring(0, i);
  }

  String get _secretKey {
    final i = apiKey.indexOf(':');
    return i < 0 ? '' : apiKey.substring(i + 1);
  }

  String _jwt() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String seg(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
    final header = seg({'alg': 'HS256', 'typ': 'JWT'});
    final payload = seg({
      'iss': _accessKeyId,
      'exp': now + 1800,
      'nbf': now - 5,
    });
    final signingInput = '$header.$payload';
    final sig = Hmac(
      sha256,
      utf8.encode(_secretKey),
    ).convert(utf8.encode(signingInput));
    final sigB64 = base64Url.encode(sig.bytes).replaceAll('=', '');
    return '$signingInput.$sigB64';
  }

  Options get _opts => Options(
    headers: {
      'Authorization': 'Bearer ${_jwt()}',
      'Content-Type': 'application/json',
    },
  );

  @override
  Future<String> submitJob({
    required String prompt,
    required int durationSeconds,
  }) async {
    try {
      final r = await _dio.post(
        '$_base/v1/videos/text2video',
        options: _opts,
        data: {
          'prompt': prompt,
          'duration': durationSeconds <= 7 ? '5' : '10',
          'mode': 'std',
          'cfg_scale': 0.5,
        },
      );
      final id = nestedString(r.data, ['data', 'task_id']);
      if (id == null || id.isEmpty) {
        throw VideoGenerationException.classify(
          'Kling response had no task_id: ${r.data}',
          _type,
        );
      }
      debugPrint('[Kling] submitted task $id');
      return id;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> isJobComplete(String jobId) async {
    try {
      final r = await _dio.get(
        '$_base/v1/videos/text2video/$jobId',
        options: _opts,
      );
      final status = nestedString(r.data, ['data', 'task_status']);
      if (status == 'failed') {
        debugPrint('[Kling] task $jobId failed: ${r.data}');
        throw VideoGenerationException.classify(
          'Kling generation failed: ${r.data}',
          _type,
        );
      }
      return status == 'succeed';
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<String> getVideoUrl(String jobId) async {
    try {
      final r = await _dio.get(
        '$_base/v1/videos/text2video/$jobId',
        options: _opts,
      );
      final url = nestedString(r.data, [
        'data',
        'task_result',
        'videos',
        0,
        'url',
      ]);
      if (url == null || url.isEmpty) {
        throw VideoGenerationException.classify(
          'Kling response contained no video URL: ${r.data}',
          _type,
        );
      }
      debugPrint('[Kling] video URL: $url');
      return url;
    } catch (e) {
      throwClassified(e, _type);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final r = await _dio.get('$_base/v1/account/costs', options: _opts);
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
