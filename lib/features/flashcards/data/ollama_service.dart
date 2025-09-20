import 'dart:convert';
import 'package:http/http.dart' as http;

/// Einfacher Client für lokalen Ollama-Server (Default: http://localhost:11434).
class OllamaService {
  OllamaService({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'gpt-oss:20b',
    this.temperature = 0.2,
  });

  final String baseUrl;
  final String model;
  final double temperature;

  /// Fragt /api/generate an (streamend) und gibt den zusammengebauten Text zurück.
  Future<String> generateJsonCards({
    required String sourceText,
    int maxCards = 80,
  }) async {
    final prompt = _buildCardPrompt(sourceText: sourceText, maxCards: maxCards);

    final uri = Uri.parse('$baseUrl/api/generate');
    final reqBody = jsonEncode({
      'model': model,
      'prompt': prompt,
      'temperature': temperature,
      'stream': true,
    });

    final request = await http.Client().send(
      http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = reqBody,
    );

    final buf = StringBuffer();
    await for (final chunk in request.stream.transform(utf8.decoder)) {
      for (final line in const LineSplitter().convert(chunk)) {
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line);
          final part = obj['response'];
          if (part is String) buf.write(part);
        } catch (_) {
          // ignoriere Nicht-JSON-Zeilen
        }
      }
    }
    return buf.toString();
  }

  String _buildCardPrompt({required String sourceText, required int maxCards}) {
    return '''
Du bist eine medizinische Lernkarten-Engine. Erzeuge prägnante, prüfungsnahe Karten aus dem folgenden Text.
Antworte ausschließlich mit gültigem JSON (UTF-8), ohne Erklärung oder Markdown, im Format:

[
  {
    "question": "…",
    "answer": "…",
    "explanation": "… (optional, kurz)",
    "source": "… (optional, z.B. Kapitel/Seite)"
  }
]

Regeln:
- Maximal $maxCards Karten.
- Frage klar, spezifisch, Single-Point.
- Antwort präzise, korrekt, 1–3 Sätze oder Stichpunkte.
- explanation nur wenn sinnvoll (Merksatz/Abgrenzung).
- Keine Codefences, kein Fließtext außerhalb von JSON.
- Duplikate vermeiden.

Quelle:
$sourceText
''';
  }
}