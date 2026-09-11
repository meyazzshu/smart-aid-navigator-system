import 'package:flutter_test/flutter_test.dart';
import 'package:san_mobile/core/navigation.dart';

void main() {
  group('NavigationHelper.normalizeCoordinates', () {
    test('keeps already-valid coordinates unchanged', () {
      final result = NavigationHelper.normalizeCoordinates(3.1309, 101.6715);
      expect(result.lat, 3.1309);
      expect(result.lng, 101.6715);
    });

    test('swaps latitude and longitude when reversed', () {
      final result = NavigationHelper.normalizeCoordinates(101.6715, 3.1309);
      expect(result.lat, 3.1309);
      expect(result.lng, 101.6715);
    });

    test('keeps invalid pair unchanged when swap is not valid', () {
      final result = NavigationHelper.normalizeCoordinates(220.0, 190.0);
      expect(result.lat, 220.0);
      expect(result.lng, 190.0);
    });
  });
}
