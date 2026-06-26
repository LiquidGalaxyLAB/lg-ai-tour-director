import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../models/wikimedia_result.dart';

// fetches a cc licensed image + short description per location from the
// wikipedia rest summary endpoint (`/page/summary/{title}`)

// rest api only cause the deprecated mediawiki `w/api.php` endpoint is not used
class WikimediaService {
  WikimediaService._();
  static final WikimediaService instance = WikimediaService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.wikimediaBaseUrl,
      headers: const {
        'User-Agent':
            'LGAITourDirector/1.0 (GSoC 2026; kabirkhanuja@gmail.com)',
      },
    ),
  );

  Future<WikimediaResult?> fetchLocationMedia(String locationName) async {
    final name = locationName.trim();
    if (name.isEmpty) {
      debugPrint('[WikimediaService] empty query → null');
      return null;
    }

    try {
      final response = await _dio.get(
        '/page/summary/${Uri.encodeComponent(name)}',
      );

      final data = response.data;
      final thumb = data is Map ? data['thumbnail'] : null;
      final source = thumb is Map ? thumb['source'] : null;

      if (source is! String || source.isEmpty) {
        debugPrint('[WikimediaService] "$name": no thumbnail → null');
        return null;
      }

      final extract = (data['extract'] is String)
          ? data['extract'] as String
          : '';
      final description = extract.length > 300
          ? '${extract.substring(0, 300).trimRight()}…'
          : extract;

      debugPrint('[WikimediaService] "$name" → $source');
      return WikimediaResult(imageUrl: source, description: description);
    } catch (e) {
      debugPrint('[WikimediaService] "$name" failed: $e → null');
      return null;
    }
  }

  Future<String?> getImageUrl(String query) async {
    final result = await fetchLocationMedia(query);
    return result?.imageUrl;
  }
}
