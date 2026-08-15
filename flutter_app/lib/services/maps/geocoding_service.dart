import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import 'location_name_utils.dart';

// Resolves a location name to lat/lng

// dont touch generation pipeline keeps calling it byte-for-byte
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  // Nominatim requires an identifying User-Agent and ~1 request/sec.
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String _userAgent =
      'AITourDirector/1.0 (Liquid Galaxy GSoC; tour-director)';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _nominatimBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'User-Agent': _userAgent},
    ),
  );

  /// Returns `{'lat': ..., 'lng': ...}` or null. Tries the original name, then
  /// cleaned-up variants ([locationQueryVariants]), stopping at the first hit.
  Future<Map<String, double>?> getCoordinates(String locationName) async {
    final variants = locationQueryVariants(locationName);
    for (final query in variants) {
      final hit = await _lookup(query);
      if (hit != null) {
        if (query != locationName) {
          debugPrint(
            'Geocoding: ✓ rescued "$locationName" via cleaned query "$query"',
          );
        }
        return hit;
      }
    }
    debugPrint(
      'Geocoding: ✗ all ${variants.length} variant(s) failed for "$locationName"',
    );
    return null;
  }

  // The `geocoding` plugin is native-only (Android/iOS); skip it elsewhere.
  static bool get _nativeGeocodingSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // One query through the native geocoder first, then Nominatim as fallback.
  Future<Map<String, double>?> _lookup(String query) async {
    if (_nativeGeocodingSupported) {
      final native = await _nativeLookup(query);
      if (native != null) return native;
    }
    return _nominatimLookup(query);
  }

  Future<Map<String, double>?> _nativeLookup(String locationName) async {
    debugPrint('Geocoding: → resolving "$locationName" via native geocoder');
    try {
      final results = await locationFromAddress(locationName);
      if (results.isEmpty) return null;

      final first = results.first;
      debugPrint(
        'Geocoding: ✓ (native) "$locationName" → '
        '(${first.latitude}, ${first.longitude})',
      );
      return {'lat': first.latitude, 'lng': first.longitude};
    } on NoResultFoundException {
      return null;
    } catch (e) {
      // Native error / unsupported platform: fall through to the HTTP backend.
      debugPrint('Geocoding: native lookup failed for "$locationName" — $e');
      return null;
    }
  }

  Future<Map<String, double>?> _nominatimLookup(String locationName) async {
    debugPrint('Geocoding: → resolving "$locationName" via OpenStreetMap');
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {'q': locationName, 'format': 'json', 'limit': 1},
      );

      final data = response.data;
      if (data is! List || data.isEmpty) {
        debugPrint('Geocoding: ✗ "$locationName" — no OpenStreetMap match');
        return null;
      }

      final first = data.first as Map<String, dynamic>;
      final lat = double.tryParse('${first['lat']}');
      final lng = double.tryParse('${first['lon']}');
      if (lat == null || lng == null) {
        debugPrint('Geocoding: ✗ "$locationName" — bad OpenStreetMap payload');
        return null;
      }

      debugPrint('Geocoding: ✓ (osm) "$locationName" → ($lat, $lng)');
      return {'lat': lat, 'lng': lng};
    } on DioException catch (e) {
      debugPrint(
        'Geocoding: ✗ OpenStreetMap network error for "$locationName" — '
        '${e.type} ${e.response?.statusCode ?? ''} ${e.message ?? ''}',
      );
      return null;
    } catch (e) {
      debugPrint('Geocoding: ✗ unexpected error for "$locationName" — $e');
      return null;
    }
  }
}
