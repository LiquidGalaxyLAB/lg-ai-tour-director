// Pure unit tests — no widget boot, no localization/assets, so they run
// reliably in CI. (The full app boot needs EasyLocalization + loaded
// translation assets, which a plain widget test can't provide.)

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/rig_config.dart';
import 'package:flutter_app/services/maps/location_name_utils.dart';

void main() {
  group('RigConfig.fromScreenCount', () {
    test('3-screen layout', () {
      final c = RigConfig.fromScreenCount(3);
      expect(c.centerScreen, 2);
      expect(c.leftScreens, [1]);
      expect(c.rightScreens, [3]);
      expect(c.leftmostScreen, 1);
      expect(c.rightmostScreen, 3);
    });

    test('5-screen layout, nearest-to-center ordering', () {
      final c = RigConfig.fromScreenCount(5);
      expect(c.centerScreen, 3);
      expect(c.leftScreens, [2, 1]);
      expect(c.rightScreens, [4, 5]);
    });
  });

  group('locationQueryVariants', () {
    test('keeps the original name first', () {
      final v = locationQueryVariants('Old Fort (Purana Qila), Delhi');
      expect(v, isNotEmpty);
      expect(v.first, 'Old Fort (Purana Qila), Delhi');
    });

    test('never emits a bare city as a query', () {
      final v = locationQueryVariants('Shaniwar Wada, Pune');
      expect(v.contains('Pune'), isFalse);
    });
  });
}
