import 'package:flutter_test/flutter_test.dart';
import 'package:ucapkas_app/core/utils/slang_parser.dart';

void main() {
  group('SlangParser', () {
    test('parses Indonesian slang terms accurately', () {
      expect(SlangParser.parseSpokenAmount('ceban tiga'), 30000);
      expect(SlangParser.parseSpokenAmount('goceng'), 5000);
      expect(SlangParser.parseSpokenAmount('seceng'), 1000);
      expect(SlangParser.parseSpokenAmount('noban'), 20000);
      expect(SlangParser.parseSpokenAmount('goban'), 50000);
      expect(SlangParser.parseSpokenAmount('cepek'), 100000);
      expect(SlangParser.parseSpokenAmount('450 ribu'), 450000);
    });
  });
}
