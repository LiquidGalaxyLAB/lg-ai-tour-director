import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../models/wikimedia_result.dart';

// fetches a cc licensed image + short description per location from the
// wikimedia rest summary endpoint (`/page/summary/{title}`)

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
      // Treat 404 as a normal miss (null thumbnail), not an exception.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// Looks up [locationName] on Wikipedia: exact name first, then a sanitised
  /// variant that drops qualifiers causing exact-match misses.
  Future<WikimediaResult?> fetchLocationMedia(String locationName) async {
    final name = locationName.trim();
    if (name.isEmpty) {
      debugPrint('[WikimediaService] empty query → null');
      return null;
    }

    debugPrint('[WikimediaService] trying: "$name"');
    var result = await _fetchOnce(name);

    if (result == null) {
      final sanitised = _sanitiseName(name);
      if (sanitised.isNotEmpty &&
          sanitised.toLowerCase() != name.toLowerCase()) {
        debugPrint('[WikimediaService] miss, retrying sanitised: "$sanitised"');
        result = await _fetchOnce(sanitised);
      }
    }

    if (result != null) {
      debugPrint('[WikimediaService] hit: ${result.imageUrl}');
    } else {
      debugPrint('[WikimediaService] miss for "$name" (both attempts)');
    }
    return result;
  }

  /// One REST lookup. Returns null on 404 / no thumbnail / network error.
  Future<WikimediaResult?> _fetchOnce(String name) async {
    try {
      final response = await _dio.get(
        '/page/summary/${Uri.encodeComponent(name)}',
      );

      final data = response.data;
      final thumb = data is Map ? data['thumbnail'] : null;
      final source = thumb is Map ? thumb['source'] : null;
      if (source is! String || source.isEmpty) return null;

      final extract = (data['extract'] is String)
          ? data['extract'] as String
          : '';
      final description = extract.length > 300
          ? '${extract.substring(0, 300).trimRight()}…'
          : extract;

      return WikimediaResult(imageUrl: source, description: description);
    } catch (e) {
      debugPrint('[WikimediaService] "$name" failed: $e');
      return null;
    }
  }

  /// Strips qualifiers that cause Wikipedia exact-match misses, then re-cases.
  String _sanitiseName(String name) {
    // Drop a trailing ", City"/", State" qualifier and any "(parenthetical)".
    var cleaned = name
        .split(',')
        .first
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .toLowerCase();

    const remove = [
      'experience',
      'observation wheel',
      'observation deck',
      'conservatory',
      'and botanical garden',
      'tower',
      'the ',
      'area ',
      'district',
    ];
    for (final word in remove) {
      cleaned = cleaned.replaceAll(word, '');
    }

    // Re-case, collapsing the extra whitespace any removal may have left.
    return cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<String?> getImageUrl(String query) async {
    final result = await fetchLocationMedia(query);
    return result?.imageUrl;
  }
}
