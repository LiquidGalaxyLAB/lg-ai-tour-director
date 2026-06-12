import 'dart:math' as math;
import '../../models/location.dart';

class AuditorService {
  AuditorService._();
  static final AuditorService instance = AuditorService._();

  /// Validates a list of locations. Rejects 0,0 and duplicates within 500m.
  List<TourLocation> validateLocations(List<TourLocation> locations) {
    final validLocations = <TourLocation>[];

    for (var loc in locations) {
      // 1. Check if lat/lng are provided
      if (loc.latitude == null || loc.longitude == null) continue;

      // 2. Reject exactly 0,0 (Null Island) which usually indicates a failure
      if (loc.latitude == 0.0 && loc.longitude == 0.0) continue;

      // 3. Reject duplicates within 500m
      bool isDuplicate = false;
      for (var existing in validLocations) {
        final distance = _calculateHaversineDistance(
          loc.latitude!,
          loc.longitude!,
          existing.latitude!,
          existing.longitude!,
        );
        if (distance < 500) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        validLocations.add(loc);
      }
    }

    return validLocations;
  }

  /// Calculates the Haversine distance between two coordinates in meters.
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // Earth radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }
}
