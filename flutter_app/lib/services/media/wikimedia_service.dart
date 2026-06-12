import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';

class WikimediaService {
  WikimediaService._();
  static final WikimediaService instance = WikimediaService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.wikimediaBaseUrl,
  ));

  Future<String?> getImageUrl(String query) async {
    try {
      final response = await _dio.get(
        '/page/summary/\${Uri.encodeComponent(query)}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['thumbnail'] != null && data['thumbnail']['source'] != null) {
          return data['thumbnail']['source'] as String;
        } else if (data['originalimage'] != null && data['originalimage']['source'] != null) {
          return data['originalimage']['source'] as String;
        }
      }
    } catch (e) {
      // If 404 or other errors, try fallback search
      return await _searchImageUrl(query);
    }
    return null;
  }

  Future<String?> _searchImageUrl(String query) async {
    try {
      final dioSearch = Dio();
      final response = await dioSearch.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'prop': 'pageimages',
          'piprop': 'original',
          'titles': query,
        },
      );

      if (response.statusCode == 200) {
        final pages = response.data['query']['pages'] as Map<String, dynamic>;
        if (pages.isNotEmpty) {
          final firstPage = pages.values.first;
          if (firstPage['original'] != null && firstPage['original']['source'] != null) {
            return firstPage['original']['source'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
