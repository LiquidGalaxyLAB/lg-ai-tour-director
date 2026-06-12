import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/app_constants.dart';

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.geocodingBaseUrl,
  ));

  Future<Map<String, double>?> getCoordinates(String locationName) async {
    final apiKey = dotenv.env['MAPS_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/json',
        queryParameters: {
          'address': locationName,
          'key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final location = results[0]['geometry']['location'];
          return {
            'lat': location['lat'] as double,
            'lng': location['lng'] as double,
          };
        }
      }
    } catch (e) {
      // Log or handle error
    }
    return null;
  }
}
