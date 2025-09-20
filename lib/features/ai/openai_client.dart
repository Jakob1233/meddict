import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';

/// Wrapper für OpenAI (GPT-5 nano = gpt-4o-mini).
/// Holt aus Textblöcken JSON-Flashcards.
class OpenAiClient {
  OpenAiClient({
    String? apiKey,
    this.model = "gpt-4o-mini", // GPT-5 nano
  }) {
    OpenAI.apiKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY');
  }

  final String model;

  Future<String> generateFlashcardsJson({
    required String sourceText,
    int maxCards = 30,
    String? subjectHint,
    String? language,
  }) async {
    final systemPrompt = '''
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

    final userPrompt = '''
SUBJECT_HINT: ${subjectHint ?? '-'}
TEXT_BEGIN
$sourceText
TEXT_END
Bitte liefere NUR das JSON-Array.
''';

    final chatCompletion = await OpenAI.instance.chat.create(
  model: model,
  messages: [
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.system,
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt)
      ],
    ),
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt)
      ],
    ),
  ],
  temperature: 0.2,
);

    final content =
        chatCompletion.choices.first.message.content?.first.text ?? '';
    final trimmed = _stripFences(content).trim();

    // Validierung: sicherstellen, dass valides JSON zurückkommt
    jsonDecode(trimmed);
    return trimmed;
  }

  // Entfernt ```json ... ``` fences, falls Modell sie um den Output packt
  static String _stripFences(String s) {
    final fence = RegExp(
      r'^\s*```(?:json)?\s*([\s\S]*?)\s*```\s*$',
      multiLine: true,
    );
    final m = fence.firstMatch(s);
    if (m != null) return m.group(1) ?? s;
    return s;
  }
}