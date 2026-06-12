import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  final Dio _dio = Dio(
    BaseOptions(baseUrl: 'https://maps.googleapis.com/maps/api/place'),
  );

  Future<Map<String, dynamic>?> getPlaceDetails(String locationName) async {
    final apiKey = dotenv.env['MAPS_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/findplacefromtext/json',
        queryParameters: {
          'input': locationName,
          'inputtype': 'textquery',
          'fields': 'place_id,formatted_address,types',
          'key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final candidates = response.data['candidates'] as List;
        if (candidates.isNotEmpty) {
          return candidates[0] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }
}
