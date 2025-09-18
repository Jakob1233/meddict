import 'package:flutterquiz/data/repositories/exams_repository.dart';

const _sfuCode = 'SFU';

/// =======================
/// SFU – BACHELOR HUMAN
/// =======================
final List<Map<String, String>> _bachelorHuman = <Map<String, String>>[
  // S1
  {'title': 'Grundlagen des Lebens', 'semester': 'S1', 'track': 'human'},
  {'title': 'Allgemeine Anatomie', 'semester': 'S1', 'track': 'human'},
  {'title': 'Organismus und schädigende Agentien', 'semester': 'S1', 'track': 'human'},
  {'title': 'Grenzflächen', 'semester': 'S1', 'track': 'human'},

  // S2
  {'title': 'Sinnesorgane', 'semester': 'S2', 'track': 'human'},
  {'title': 'Bewegungsapparat', 'semester': 'S2', 'track': 'human'},
  {'title': 'Blut, Immunsystem und Infekt', 'semester': 'S2', 'track': 'human'},

  // S3
  {'title': 'Herz-Kreislauf', 'semester': 'S3', 'track': 'human'},
  {'title': 'Atmung', 'semester': 'S3', 'track': 'human'},
  {'title': 'Endokrine Systeme', 'semester': 'S3', 'track': 'human'},
  {'title': 'Stoffwechsel (B14-1)', 'semester': 'S3', 'track': 'human'},

  // S4
  {'title': 'Verdauung und Stoffwechsel (B14-2)', 'semester': 'S4', 'track': 'human'},
  {'title': 'Niere und ableitende Harnwege', 'semester': 'S4', 'track': 'human'},
  {'title': 'Sexualität und Fortpflanzung', 'semester': 'S4', 'track': 'human'},

  // S5
  {'title': 'Nervensystem', 'semester': 'S5', 'track': 'human'},
  {'title': 'Gesundheit und Krankheit der Psyche im Lebensverlauf', 'semester': 'S5', 'track': 'human'},
  {'title': 'Wachstum, Entwicklung und Altern', 'semester': 'S5', 'track': 'human'},

  // S6
  {'title': 'Diversität in der Medizin', 'semester': 'S6', 'track': 'human'},
  {'title': 'Chronische Krankheiten und Schmerz', 'semester': 'S6', 'track': 'human'},
  {'title': 'Pharmakologische und Toxikologische Grundlagen', 'semester': 'S6', 'track': 'human'},
  {'title': 'Transdisziplinärer anatomischer Präparierkurs', 'semester': 'S6', 'track': 'human'},
];

/// =======================
/// SFU – BACHELOR ZAHN
/// (S1–S4 inhaltlich wie Human; hier startend ab S5, weil dort
/// die zahnmedizinischen Blöcke beginnen)
/// =======================
final List<Map<String, String>> _bachelorZahn = <Map<String, String>>[
  // S5 (gemeinsame + zahn-spezifische)
  {'title': 'Zahnärztliche Fertigkeiten (BZ3a)', 'semester': 'S5', 'track': 'zahn'},
  {'title': 'Nervensystem', 'semester': 'S5', 'track': 'zahn'},
  {'title': 'Gesundheit und Krankheit der Psyche im Lebensverlauf', 'semester': 'S5', 'track': 'zahn'},
  {'title': 'Wachstum, Entwicklung und Altern', 'semester': 'S5', 'track': 'zahn'},

  // S6
  {'title': 'Zahnärztliche Fertigkeiten (BZ3b)', 'semester': 'S6', 'track': 'zahn'},
  {'title': 'Diversität in der Medizin', 'semester': 'S6', 'track': 'zahn'},
  {'title': 'Propädeutikum der zahnmedizinischen Fachgebiete (BZ23)', 'semester': 'S6', 'track': 'zahn'},
  {'title': 'Pharmakologische und Toxikologische Grundlagen', 'semester': 'S6', 'track': 'zahn'},
];

/// =======================
/// SFU – MASTER (NOCH OFFEN)
/// Bitte mit den offiziellen Titeln nachreichen.
/// =======================
final List<Map<String, String>> _masterHuman = <Map<String, String>>[
  // TODO: S7–S12 Human – offizielle Titel einfügen.
];

final List<Map<String, String>> _masterZahn = <Map<String, String>>[
  // TODO: S7–S12 Zahn – offizielle Titel einfügen.
];

List<Map<String, String>> _withUniversity(List<Map<String, String>> rows) {
  return rows
      .map((entry) => <String, String>{
            ...entry,
            'universityCode': entry['universityCode'] ?? _sfuCode,
          })
      .toList();
}

Future<int> seedExamsSFU(ExamsRepository repository) async {
  final payload = <Map<String, String>>[
    ..._withUniversity(_bachelorHuman),
    ..._withUniversity(_bachelorZahn),
    ..._withUniversity(_masterHuman),
    ..._withUniversity(_masterZahn),
  ];
  return repository.addMany(payload);
}