class SpacedRepetition {
  /// quality: 0 = schwer, 1 = gut, 2 = einfach
  static Map<String, dynamic> reviewCard(Map<String, dynamic> card, int quality) {
    final now = DateTime.now();

    // defensiv casten
    final repDyn = card['repetitions'];
    int repetitions = (repDyn is int) ? repDyn : int.tryParse('$repDyn') ?? 0;

    final easeDyn = card['ease'];
    double ease = (easeDyn is num) ? easeDyn.toDouble() : double.tryParse('$easeDyn') ?? 2.5;

    final intDyn = card['interval'];
    int interval = (intDyn is int) ? intDyn : int.tryParse('$intDyn') ?? 1;

    // Bounds für quality absichern
    final q = (quality < 0) ? 0 : (quality > 2 ? 2 : quality);

    if (q < 1) {
      // falsch / schwer
      repetitions = 0;
      interval = 1;
    } else {
      repetitions += 1;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * ease).round();
      }
      // SM-2 Ease-Update
      ease = ease + (0.1 - (2 - q) * (0.08 + (2 - q) * 0.02));
      if (ease < 1.3) ease = 1.3;
    }

    final due = now.add(Duration(days: interval)).toIso8601String();

    return {
      ...card,
      'repetitions': repetitions,
      'ease': ease,
      'interval': interval,
      'due': due,               // wir bleiben bei ISO-String (lexisch sortierbar)
      'updatedAt': now,         // Flutter wandelt DateTime → Timestamp
    };
  }
}