import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/app_constants.dart';

/// Calls the Google Places API (Find Place From Text) directly and returns
/// the place_id, formatted_address and types for a location name.
class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.placesBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Returns the first candidate as `{place_id, formatted_address, types}`
  /// or `null` if nothing is found.
  Future<Map<String, dynamic>?> getPlaceDetails(String locationName) async {
    final apiKey = dotenv.env['MAPS_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint(
        'Places: MAPS_KEY missing or empty — skipping "$locationName"',
      );
      return null;
    }

    debugPrint('Places: → requesting place details for "$locationName"');

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

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        final errMsg = data['error_message'];
        debugPrint(
          'Places: ✗ "$locationName" returned status=$status'
          '${errMsg != null ? ' — $errMsg' : ''}',
        );
        return null;
      }

      final candidates = data['candidates'] as List;
      if (candidates.isEmpty) {
        debugPrint('Places: ✗ "$locationName" status=OK but zero candidates');
        return null;
      }

      final first = candidates[0] as Map<String, dynamic>;
      debugPrint(
        'Places: ✓ "$locationName" → place_id=${first['place_id']} '
        '[${first['formatted_address']}]',
      );
      return first;
    } on DioException catch (e) {
      debugPrint(
        'Places: ✗ network error for "$locationName" — '
        '${e.type} ${e.response?.statusCode ?? ''} ${e.message ?? ''}',
      );
      return null;
    } catch (e) {
      debugPrint('Places: ✗ unexpected error for "$locationName" — $e');
      return null;
    }
  }
}
