import 'package:intl/intl.dart';

class RupiahFormatter {
  const RupiahFormatter._();

  static final NumberFormat _decimalFormat = NumberFormat.decimalPattern('id_ID');

  static String format(int amount, {bool showSign = false}) {
    final absFormatted = 'Rp ${_decimalFormat.format(amount.abs())}';
    if (amount < 0) {
      return '-$absFormatted';
    }
    if (showSign && amount > 0) {
      return '+$absFormatted';
    }
    return absFormatted;
  }
}
