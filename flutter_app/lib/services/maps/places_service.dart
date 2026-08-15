import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import 'location_name_utils.dart';

// Place details for a location name: native geocoder first (Android/iOS/macOS),
// then Nominatim over HTTP (works on web too). No paid Google Places API.
// Don't touch: the generation pipeline calls this byte-for-byte.
class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

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

  Future<Map<String, dynamic>?> getPlaceDetails(String locationName) async {
    final variants = locationQueryVariants(locationName);
    for (final query in variants) {
      final hit = await _lookup(query);
      if (hit != null) {
        if (query != locationName) {
          debugPrint(
            'Places: ✓ rescued "$locationName" via cleaned query "$query"',
          );
        }
        return hit;
      }
    }
    debugPrint(
      'Places: ✗ all ${variants.length} variant(s) failed for "$locationName"',
    );
    return null;
  }

  // The `geocoding` plugin is native-only; skip it elsewhere and use Nominatim.
  static bool get _nativeGeocodingSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// One query through the native geocoder first, then Nominatim as fallback.
  Future<Map<String, dynamic>?> _lookup(String query) async {
    if (_nativeGeocodingSupported) {
      final native = await _nativeLookup(query);
      if (native != null) return native;
    }
    return _nominatimLookup(query);
  }

  Future<Map<String, dynamic>?> _nativeLookup(String locationName) async {
    debugPrint('Places: → resolving "$locationName" via native geocoder');
    try {
      final locations = await locationFromAddress(locationName);
      if (locations.isEmpty) return null;

      final first = locations.first;
      final placemarks = await placemarkFromCoordinates(
        first.latitude,
        first.longitude,
      );
      if (placemarks.isEmpty) return null;

      final formatted = _formatPlacemark(placemarks.first);
      debugPrint('Places: ✓ (native) "$locationName" → [$formatted]');
      return _result(formatted);
    } on NoResultFoundException {
      return null;
    } catch (e) {
      debugPrint('Places: native lookup failed for "$locationName" — $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _nominatimLookup(String locationName) async {
    debugPrint('Places: → resolving "$locationName" via OpenStreetMap');
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {'q': locationName, 'format': 'json', 'limit': 1},
      );

      final data = response.data;
      if (data is! List || data.isEmpty) {
        debugPrint('Places: ✗ "$locationName" — no OpenStreetMap match');
        return null;
      }

      final first = data.first as Map<String, dynamic>;
      final formatted = (first['display_name'] as String?)?.trim();
      debugPrint('Places: ✓ (osm) "$locationName" → [$formatted]');
      return _result(formatted == null || formatted.isEmpty ? null : formatted);
    } on DioException catch (e) {
      debugPrint(
        'Places: ✗ OpenStreetMap network error for "$locationName" — '
        '${e.type} ${e.response?.statusCode ?? ''} ${e.message ?? ''}',
      );
      return null;
    } catch (e) {
      debugPrint('Places: ✗ unexpected error for "$locationName" — $e');
      return null;
    }
  }

  Map<String, dynamic> _result(String? formattedAddress) => {
    'place_id': null,
    'formatted_address': formattedAddress,
    'types': const <String>[],
  };

  String? _formatPlacemark(Placemark p) {
    final parts = <String?>[
      p.name,
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.postalCode,
      p.country,
    ];
    final seen = <String>{};
    final cleaned = <String>[];
    for (final part in parts) {
      final value = part?.trim();
      if (value == null || value.isEmpty) continue;
      if (seen.add(value)) cleaned.add(value);
    }
    return cleaned.isEmpty ? null : cleaned.join(', ');
  }
}
