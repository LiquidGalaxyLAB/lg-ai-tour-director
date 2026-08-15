import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Image fallback when Wikipedia has no photo. Uses the Unsplash Search API,
/// returning a single landscape photo URL or null on miss/no key/error.
class UnsplashService {
  UnsplashService._();
  static final UnsplashService instance = UnsplashService._();

  static const String _base = 'https://api.unsplash.com/search/photos';

  final Dio _dio = Dio();

  /// Searches Unsplash for [query], trying progressively broader variants.
  Future<String?> fetchPhotoUrl(String query) async {
    // Search API authenticates with the Access Key as client_id.
    final key = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('[UnsplashService] No access key configured');
      return null;
    }

    for (final variant in _queryVariants(query)) {
      final url = await _search(variant, key);
      if (url != null) {
        debugPrint('[UnsplashService] found ($variant): $url');
        return url;
      }
      debugPrint('[UnsplashService] No results for: $variant');
    }
    return null;
  }

  /// Ordered, de-duplicated search terms, broadening on each step (strips any
  /// "(parenthetical)" alias and the trailing ", City").
  List<String> _queryVariants(String name) {
    String flatten(String s) =>
        s.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final noParen = name.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    return <String>{
      flatten(noParen), // paren-stripped, comma-flattened (most likely to hit)
      flatten(noParen.split(',').first), // paren-stripped first segment
      flatten(name), // original, in case the parenthetical mattered
      flatten(name.split(',').first),
    }.where((v) => v.isNotEmpty).toList();
  }

  Future<String?> _search(String query, String key) async {
    try {
      final response = await _dio.get(
        _base,
        queryParameters: {
          'query': query,
          'per_page': 1,
          'orientation': 'landscape', // better for the 420×240 image box
          'client_id': key,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final results = response.data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      // 'regular' (≈1080px wide) — full/raw are too large for an overlay.
      return results[0]['urls']?['regular'] as String?;
    } catch (e) {
      debugPrint('[UnsplashService] error: $e');
      return null;
    }
  }
}
