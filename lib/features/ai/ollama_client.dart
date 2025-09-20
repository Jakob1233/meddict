import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaClient {
  OllamaClient({
    this.baseUrl = 'http://127.0.0.1:11434',
    this.model = 'qwen2:7b-instruct',
    this.timeoutSeconds = 360,
  });

  final String baseUrl;
  final String model;
  final int timeoutSeconds;

  Future<void> warmup() async {
    final uri = Uri.parse('$baseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': 'You are a helpful assistant.'},
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
      'options': {'temperature': 0, 'num_ctx': 2048},
      'stream': false,
    });
    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Ollama warmup failed: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<String> generateFlashcardsJson({
    required String sourceText,
    int maxCards = 30,
    String? subjectHint,
    String? language,
  }) async {
    final uri = Uri.parse('$baseUrl/api/chat');

    final systemMsg = '''
Du bist ein Flashcard-Generator für Medizinstudierende.
ANTWORTE AUSSCHLIESSLICH mit JSON (UTF-8).
Schema (Array von Objekten): 
- "question": string (max 180 Zeichen)
- "answer": string (max 220 Zeichen)
- "explanation": string (optional, max 280 Zeichen)
- "tags": string[]
- "source": string
Maximal $maxCards Karten, keine Dopplungen. Sprache: ${language ?? 'de'}.
''';

    final userMsg = '''
SUBJECT_HINT: ${subjectHint ?? '-'}
TEXT_BEGIN
$sourceText
TEXT_END
Bitte liefere NUR das JSON-Array.
''';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemMsg},
        {'role': 'user', 'content': userMsg},
      ],
      'options': {'temperature': 0.2, 'num_ctx': 8192},
      'stream': false,
    });

    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(Duration(seconds: timeoutSeconds));

    if (resp.statusCode != 200) {
      throw Exception('Ollama-Fehler ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final content = (data['message']?['content'] ?? '') as String;
    final trimmed = _stripFences(content).trim();
    // Gültigkeit checken
    jsonDecode(trimmed);
    return trimmed;
  }

  static String _stripFences(String s) {
    final fence = RegExp(r'^\s*```(?:json)?\s*([\s\S]*?)\s*```\s*$', multiLine: true);
    final m = fence.firstMatch(s);
    if (m != null) return m.group(1) ?? s;
    return s;
  }
}