import 'dart:typed_data';

import 'package:excel/excel.dart';

const int _kQuestionMaxLength = 2000;
const int _kAnswerMaxLength = 2000;
const int _kExplanationMaxLength = 2000;
const int _kSourceMaxLength = 500;
const int _kImageUrlMaxLength = 1000;
const String _kKeySeparator = '|||';

class ExcelImportCard {
  const ExcelImportCard({
    required this.question,
    required this.answer,
    this.explanation,
    this.tags = const [],
    this.imageUrl,
    this.source,
    this.difficulty,
  });

  final String question;
  final String answer;
  final String? explanation;
  final List<String> tags;
  final String? imageUrl;
  final String? source;
  final int? difficulty;

  Map<String, dynamic> toMap() => {
    'question': question,
    'answer': answer,
    'explanation': explanation,
    'tags': tags,
    'imageUrl': imageUrl,
    'source': source,
    'difficulty': difficulty,
  };

  factory ExcelImportCard.fromMap(Map<String, dynamic> map) => ExcelImportCard(
    question: map['question'] as String,
    answer: map['answer'] as String,
    explanation: map['explanation'] as String?,
    tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    imageUrl: map['imageUrl'] as String?,
    source: map['source'] as String?,
    difficulty: map['difficulty'] as int?,
  );
}

class ExcelRowError {
  const ExcelRowError({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;

  Map<String, dynamic> toMap() => {
    'rowNumber': rowNumber,
    'message': message,
  };

  factory ExcelRowError.fromMap(Map<String, dynamic> map) => ExcelRowError(
    rowNumber: map['rowNumber'] as int,
    message: map['message'] as String,
  );
}

class ExcelParseResult {
  const ExcelParseResult({
    required this.cards,
    required this.errors,
    required this.totalRows,
    this.fatalMessage,
  });

  final List<ExcelImportCard> cards;
  final List<ExcelRowError> errors;
  final int totalRows;
  final String? fatalMessage;

  bool get hasFatalError => fatalMessage != null;

  Map<String, dynamic> toMap() => {
    'cards': cards.map((c) => c.toMap()).toList(growable: false),
    'errors': errors.map((e) => e.toMap()).toList(growable: false),
    'totalRows': totalRows,
    'fatalMessage': fatalMessage,
  };

  factory ExcelParseResult.fromMap(Map<String, dynamic> map) =>
      ExcelParseResult(
        cards: ((map['cards'] as List<dynamic>?) ?? [])
            .map(
              (e) => ExcelImportCard.fromMap(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
              ),
            )
            .toList(),
        errors: ((map['errors'] as List<dynamic>?) ?? [])
            .map(
              (e) => ExcelRowError.fromMap(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
              ),
            )
            .toList(),
        totalRows: (map['totalRows'] as int?) ?? 0,
        fatalMessage: map['fatalMessage'] as String?,
      );
}

ExcelParseResult parseExcelBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return const ExcelParseResult(
      cards: [],
      errors: [],
      totalRows: 0,
      fatalMessage: 'Die Datei ist leer.',
    );
  }

  final book = Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) {
    return const ExcelParseResult(
      cards: [],
      errors: [],
      totalRows: 0,
      fatalMessage: 'Keine Tabellenblätter gefunden.',
    );
  }

  final sheet = book.tables.values.first;
  final rows = sheet.rows;
  if (rows.isEmpty) {
    return const ExcelParseResult(
      cards: [],
      errors: [],
      totalRows: 0,
      fatalMessage: 'Keine Datenzeilen gefunden.',
    );
  }

  final headerRow = rows.first;
  final Map<String, int> headers = {};
  for (var i = 0; i < headerRow.length; i++) {
    final header = _cellToString(headerRow[i])?.toLowerCase();
    if (header != null && header.isNotEmpty) {
      headers[header.trim()] = i;
    }
  }

  if (!headers.containsKey('question') || !headers.containsKey('answer')) {
    return const ExcelParseResult(
      cards: [],
      errors: [],
      totalRows: 0,
      fatalMessage:
          'Erforderliche Spaltenüberschriften "question" und "answer" wurden nicht gefunden.',
    );
  }

  final List<ExcelImportCard> cards = [];
  final List<ExcelRowError> errors = [];
  int processedRows = 0;

  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (_isRowEmpty(row)) {
      continue;
    }

    processedRows++;
    final rowNumber = rowIndex + 1;

    String? question = _takeString(row, headers['question']);
    String? answer = _takeString(row, headers['answer']);

    if (question == null ||
        question.isEmpty ||
        answer == null ||
        answer.isEmpty) {
      errors.add(
        ExcelRowError(
          rowNumber: rowNumber,
          message: 'Frage oder Antwort fehlt.',
        ),
      );
      continue;
    }

    question = _truncate(question, _kQuestionMaxLength);
    answer = _truncate(answer, _kAnswerMaxLength);

    final explanation = _truncateNullable(
      _takeString(row, headers['explanation']),
      _kExplanationMaxLength,
    );
    final source = _truncateNullable(
      _takeString(row, headers['source']),
      _kSourceMaxLength,
    );
    final imageUrl = _truncateNullable(
      _takeString(row, headers['imageurl']),
      _kImageUrlMaxLength,
    );
    final tagsRaw = _takeString(row, headers['tags']);
    final tags = tagsRaw == null
        ? <String>[]
        : tagsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false);
    final difficultyRaw = _takeString(row, headers['difficulty']);
    final difficulty = _parseDifficulty(difficultyRaw);

    cards.add(
      ExcelImportCard(
        question: question,
        answer: answer,
        explanation: explanation,
        tags: tags,
        imageUrl: imageUrl,
        source: source,
        difficulty: difficulty,
      ),
    );
  }

  return ExcelParseResult(
    cards: cards,
    errors: errors,
    totalRows: processedRows,
  );
}

Map<String, dynamic> parseExcelBytesSerializable(Uint8List bytes) {
  final result = parseExcelBytes(bytes);
  return result.toMap();
}

String buildCardKey(String question, String answer) {
  return '${question.trim().toLowerCase()}$_kKeySeparator${answer.trim().toLowerCase()}';
}

List<String> buildCardKeysSerializable(List<Map<String, dynamic>> entries) {
  final set = <String>{};
  for (final entry in entries) {
    final question = (entry['question'] as String?) ?? '';
    final answer = (entry['answer'] as String?) ?? '';
    if (question.isEmpty || answer.isEmpty) continue;
    set.add(buildCardKey(question, answer));
  }
  return set.toList(growable: false);
}

String? _takeString(List<Data?> row, int? index) {
  if (index == null) return null;
  if (index < 0 || index >= row.length) return null;
  final cell = row[index];
  return _cellToString(cell)?.trim();
}

String? _cellToString(Data? cell) {
  if (cell == null) return null;
  final value = cell.value;
  if (value == null) return null;
  if (value is String) return value;
  if (value is bool) return value ? 'true' : 'false';
  return value.toString();
}

bool _isRowEmpty(List<Data?> row) {
  for (final cell in row) {
    final text = _cellToString(cell);
    if (text != null && text.trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

String _truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength);
}

String? _truncateNullable(String? text, int maxLength) {
  if (text == null) return null;
  if (text.isEmpty) return null;
  return _truncate(text, maxLength);
}

int? _parseDifficulty(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  final parsed = int.tryParse(lower);
  if (parsed != null && parsed >= 1 && parsed <= 3) {
    return parsed;
  }
  switch (lower) {
    case 'easy':
      return 1;
    case 'good':
      return 2;
    case 'hard':
      return 3;
  }
  return null;
}
