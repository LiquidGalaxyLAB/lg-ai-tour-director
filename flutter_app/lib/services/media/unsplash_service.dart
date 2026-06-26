import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Image fallback for locations Wikipedia has no photo for (modern venues,
/// districts, generic place names). Uses the Unsplash Search API and returns a
/// single landscape 'regular'-size photo URL, or null on miss / no key / error.
class UnsplashService {
  UnsplashService._();
  static final UnsplashService instance = UnsplashService._();

  static const String _base = 'https://api.unsplash.com/search/photos';

  final Dio _dio = Dio();

  Future<String?> fetchPhotoUrl(String query) async {
    try {
      // Search API authenticates with the Access Key as client_id (the Secret
      // Key is only for OAuth user-auth, which this app doesn't use).
      final key = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
      if (key.isEmpty) {
        debugPrint('[UnsplashService] No access key configured');
        return null;
      }

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
      if (results == null || results.isEmpty) {
        debugPrint('[UnsplashService] No results for: $query');
        return null;
      }

      // 'regular' (≈1080px wide) — full/raw are too large for an overlay.
      final url = results[0]['urls']?['regular'] as String?;
      debugPrint('[UnsplashService] found: $url');
      return url;
    } catch (e) {
      debugPrint('[UnsplashService] error: $e');
      return null;
    }
  }
}
