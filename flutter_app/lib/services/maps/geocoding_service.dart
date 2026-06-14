import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/app_constants.dart';

/// Calls the Google Geocoding REST API directly (no SDK) and returns the
/// lat/lng for a location name. Logs every step to the terminal so we can
/// see exactly why a lookup succeeds or fails while we get geocoding right.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.geocodingBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Returns `{'lat': ..., 'lng': ...}` or `null` if the lookup fails.
  Future<Map<String, double>?> getCoordinates(String locationName) async {
    final apiKey = dotenv.env['MAPS_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint(
        'Geocoding: MAPS_KEY missing or empty — skipping "$locationName"',
      );
      return null;
    }

    debugPrint('Geocoding: → requesting coordinates for "$locationName"');

    try {
      final response = await _dio.get(
        '/json',
        queryParameters: {'address': locationName, 'key': apiKey},
      );

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        final errMsg = data['error_message'];
        debugPrint(
          'Geocoding: ✗ "$locationName" returned status=$status'
          '${errMsg != null ? ' — $errMsg' : ''}',
        );
        return null;
      }

      final results = data['results'] as List;
      if (results.isEmpty) {
        debugPrint('Geocoding: ✗ "$locationName" status=OK but zero results');
        return null;
      }

      final first = results[0] as Map<String, dynamic>;
      final location = first['geometry']['location'] as Map<String, dynamic>;
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();
      final formatted = first['formatted_address'] as String?;

      debugPrint(
        'Geocoding: ✓ "$locationName" → ($lat, $lng)'
        '${formatted != null ? '  [$formatted]' : ''}',
      );

      return {'lat': lat, 'lng': lng};
    } on DioException catch (e) {
      debugPrint(
        'Geocoding: ✗ network error for "$locationName" — '
        '${e.type} ${e.response?.statusCode ?? ''} ${e.message ?? ''}',
      );
      return null;
    } catch (e) {
      debugPrint('Geocoding: ✗ unexpected error for "$locationName" — $e');
      return null;
    }
  }
}
