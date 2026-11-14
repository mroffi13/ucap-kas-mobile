class SlangParser {
  const SlangParser._();

  static const Map<String, int> _baseSlang = {
    'seceng': 1000,
    'goceng': 5000,
    'ceban': 10000,
    'noban': 20000,
    'goban': 50000,
    'cepek': 100000,
    'gopek': 500000,
  };

  static const Map<String, int> _multipliers = {
    'satu': 1,
    'dua': 2,
    'tiga': 3,
    'empat': 4,
    'lima': 5,
    'enam': 6,
    'tujuh': 7,
    'delapan': 8,
    'sembilan': 9,
    'sepuluh': 10,
  };

  static int? parseSpokenAmount(String phrase) {
    final normalized = phrase.trim().toLowerCase();
    for (final entry in _baseSlang.entries) {
      if (normalized.contains(entry.key)) {
        for (final mult in _multipliers.entries) {
          if (normalized.contains(mult.key)) {
            return entry.value * mult.value;
          }
        }
        return entry.value;
      }
    }

    final ribuMatch = RegExp(r'(\d+)\s*(ribu|rb)').firstMatch(normalized);
    if (ribuMatch != null) {
      return int.parse(ribuMatch.group(1)!) * 1000;
    }

    final jutaMatch = RegExp(r'(\d+)\s*(juta|jt)').firstMatch(normalized);
    if (jutaMatch != null) {
      return int.parse(jutaMatch.group(1)!) * 1000000;
    }

    return null;
  }
}
