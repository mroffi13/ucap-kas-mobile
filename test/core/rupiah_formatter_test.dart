import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/core/utils/rupiah_formatter.dart';

void main() {
  group('RupiahFormatter', () {
    test('formats standard Rupiah with dot separators', () {
      expect(RupiahFormatter.format(14850000), 'Rp 14.850.000');
      expect(RupiahFormatter.format(0), 'Rp 0');
    });

    test('formats signed inflow and outflow amounts', () {
      expect(RupiahFormatter.format(450000, showSign: true), '+Rp 450.000');
      expect(RupiahFormatter.format(-180000, showSign: true), '-Rp 180.000');
    });
  });
}
