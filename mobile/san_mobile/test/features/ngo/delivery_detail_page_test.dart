import 'package:flutter_test/flutter_test.dart';
import 'package:san_mobile/features/ngo/delivery_detail_page.dart';

void main() {
  group('normalizeNgoDeliveryStatus', () {
    test('normalizes routed and in-transit variants', () {
      expect(normalizeNgoDeliveryStatus('routed'), 'ROUTED');
      expect(normalizeNgoDeliveryStatus('IN TRANSIT'), 'IN_TRANSIT');
      expect(normalizeNgoDeliveryStatus('in-transit'), 'IN_TRANSIT');
      expect(normalizeNgoDeliveryStatus('in  -  transit'), 'IN_TRANSIT');
    });

    test('normalizes cancelled aliases to canonical status', () {
      expect(normalizeNgoDeliveryStatus('cancelled'), 'CANCELLED');
      expect(normalizeNgoDeliveryStatus('canceled'), 'CANCELLED');
    });

    test('handles null, blank, and unexpected values', () {
      expect(normalizeNgoDeliveryStatus(null), '');
      expect(normalizeNgoDeliveryStatus('  '), '');
      expect(normalizeNgoDeliveryStatus('paused'), 'PAUSED');
    });
  });
}
