import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../features/ai/openai_client.dart'; // GPT-5 nano (gpt-4o-mini)

// Optional: wenn du Ollama parallel testen willst
// import '../../../features/ai/ollama_client.dart';

class AiDeckWizard extends StatefulWidget {
  const AiDeckWizard({
    super.key,
    required this.deckRef,
    required this.deckTitle,
  });

  final DocumentReference<Map<String, dynamic>> deckRef;
  final String deckTitle;

  @override
  State<AiDeckWizard> createState() => _AiDeckWizardState();
}

class _AiDeckWizardState extends State<AiDeckWizard> {
  // ----- State -----
  String? _filePath;
  String? _rawText;
  String? _status;
  bool _busy = false;

  // Progress
  int _totalChunks = 0;
  int _currentChunk = 0;
  double get _progress =>
      _totalChunks == 0 ? 0 : (_currentChunk.clamp(0, _totalChunks) / _totalChunks);

  // Ergebnisse
  List<Map<String, dynamic>> _cards = [];

  // Steuerung
  bool _cancelRequested = false;

  // GPT-5 nano (= gpt-4o-mini bei OpenAI)
  final _openai = OpenAiClient(model: "gpt-4o-mini");

  // ------------------ Helpers ------------------

  Future<String> _loadAssetTextOrPdf(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final ext = assetPath.toLowerCase();
    if (ext.endsWith('.txt')) {
      return String.fromCharCodes(bytes.buffer.asUint8List());
    } else if (ext.endsWith('.pdf')) {
      final document = PdfDocument(inputBytes: bytes.buffer.asUint8List());
      final buffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        final extractor = PdfTextExtractor(document);
        buffer.writeln(
          extractor.extractText(startPageIndex: i, endPageIndex: i),
        );
      }
      document.dispose();
      return buffer.toString();
    }
    throw UnsupportedError('Nicht unterstütztes Asset: $assetPath');
  }

  Future<void> _pickFile() async {
    setState(() => _status = null);
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );
    final path = res?.files.single.path;
    if (path != null) setState(() => _filePath = path);
  }

  Future<void> _extractText() async {
    final path = _filePath;
    if (path == null) {
      setState(() => _status = 'Bitte zuerst Datei wählen oder Demo laden.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Extrahiere Text…';
    });

    try {
      final ext = p.extension(path).toLowerCase();
      if (ext == '.txt') {
        _rawText = await File(path).readAsString();
      } else if (ext == '.pdf') {
        final fileBytes = await File(path).readAsBytes();
        final document = PdfDocument(inputBytes: fileBytes);
        final buffer = StringBuffer();
        for (int i = 0; i < document.pages.count; i++) {
          final extractor = PdfTextExtractor(document);
          buffer.writeln(
            extractor.extractText(startPageIndex: i, endPageIndex: i),
          );
        }
        document.dispose();
        _rawText = buffer.toString();
      } else {
        _rawText = null;
        _status = 'Nicht unterstütztes Format: $ext';
      }

      if (_rawText != null) {
        _status = 'Text bereit (${_rawText!.length} Zeichen)';
      }
    } catch (e) {
      _rawText = null;
      _status = 'Fehler bei der Textextraktion: $e';
    } finally {
      setState(() => _busy = false);
    }
  }

  // Chunking nach Zeichen
  List<String> _chunkByLength(String input, {int maxLen = 12000, int overlap = 600}) {
    final chunks = <String>[];
    int i = 0;
    while (i < input.length) {
      final end = (i + maxLen < input.length) ? i + maxLen : input.length;
      var slice = input.substring(i, end);

      final lastDot = slice.lastIndexOf('.');
      final lastNl = slice.lastIndexOf('\n');
      final cut = [lastDot, lastNl].where((x) => x >= 0).fold<int>(-1, (a, b) => a > b ? a : b);
      if (cut >= 4000) {
        slice = slice.substring(0, cut + 1);
      }

      chunks.add(slice.trim());
      if (end >= input.length) break;
      i += slice.length - overlap;
      if (i < 0) i = 0;
    }
    return chunks;
  }

  List<Map<String, dynamic>> _dedupeCards(List<Map<String, dynamic>> cards) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final c in cards) {
      final q = (c['question'] ?? '').toString().trim().toLowerCase();
      if (q.isEmpty || seen.contains(q)) continue;
      seen.add(q);
      out.add(c);
    }
    return out;
  }

  Future<void> _generate() async {
    final text = _rawText?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _status = 'Kein Text vorhanden. Bitte zuerst extrahieren.');
      return;
    }

    setState(() {
      _busy = true;
      _cancelRequested = false;
      _cards.clear();
      _currentChunk = 0;
      _totalChunks = 0;
      _status = 'Starte KI-Generierung (GPT-5 nano)…';
    });

    // Chunking vorbereiten
    final chunks = _chunkByLength(text, maxLen: 12000, overlap: 600);
    _totalChunks = chunks.length;
    const maxTotal = 30;
    const perChunk = 10;

    final acc = <Map<String, dynamic>>[];

    for (var idx = 0; idx < chunks.length; idx++) {
      if (_cancelRequested) break;

      setState(() {
        _currentChunk = idx;
        _status = 'Erzeuge Karten… (${idx + 1}/$_totalChunks)';
      });

      try {
        final jsonString = await _openai.generateFlashcardsJson(
          sourceText: chunks[idx],
          maxCards: perChunk,
          subjectHint: widget.deckTitle,
          language: 'de',
        );
        final data = (jsonDecode(jsonString) as List).cast<Map<String, dynamic>>();
        acc.addAll(data);

        final deduped = _dedupeCards(acc);
        acc
          ..clear()
          ..addAll(deduped);

        setState(() {
          _cards = List<Map<String, dynamic>>.from(acc.take(maxTotal));
          _status = 'Vorschau: ${_cards.length} Karten (Chunk ${idx + 1}/$_totalChunks)';
        });

        if (_cards.length >= maxTotal) break;
      } catch (e) {
        setState(() {
          _status = 'Warnung: Chunk ${idx + 1} fehlgeschlagen: $e';
        });
      }
    }

    if (_cancelRequested) {
      setState(() {
        _busy = false;
        _status = 'Abgebrochen. ${_cards.length} Karten in Vorschau.';
      });
      return;
    }

    setState(() {
      _busy = false;
      if (_cards.isEmpty) {
        _status = 'Keine Karten erzeugt.';
      } else {
        _status = 'Fertig: ${_cards.length} Karten.';
      }
    });
  }

  Future<void> _save() async {
    if (_cards.isEmpty) {
      setState(() => _status = 'Keine Karten erzeugt.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Speichere Karten…';
    });
    try {
      final batch = FirebaseFirestore.instance.batch();
      final cardsCol = widget.deckRef.collection('cards');
      final now = DateTime.now();
      for (final c in _cards) {
        batch.set(cardsCol.doc(), {
  'question': (c['question'] ?? '').toString().trim(),
  'answer': (c['answer'] ?? '').toString().trim(),
  'explanation': (c['explanation'] ?? '').toString().trim(),
  'tags': (c['tags'] is List) ? List<String>.from(c['tags'] as List) : <String>[],
  'source': (c['source'] ?? widget.deckTitle).toString(),
  'createdAt': now,
  'updatedAt': now,

  // >>> Spaced Repetition Defaults <<<
  'repetitions': 0,
  'interval': 1,      // Start mit 1 Tag
  'ease': 2.5,        // Standardwert
  'due': now.toIso8601String(), // sofort fällig
});
      }
      await batch.commit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _status = 'Fehler beim Speichern: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KI-Import: Lernkarten aus Dokument'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Schritt 1 – Datei wählen
            Text('1) Datei wählen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Datei auswählen (PDF/TXT)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _filePath ?? 'Keine Datei gewählt',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Demo-Buttons
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.science),
                  label: const Text('Demo laden: M18'),
                  onPressed: _busy ? null : () async {
                    setState(() { _busy = true; _status = 'Lade Demo: M18…'; });
                    try {
                      _rawText = await _loadAssetTextOrPdf('assets/test_docs/M18.pdf');
                      _filePath = 'DEMO: M18.pdf';
                      _status = 'Text bereit (${_rawText!.length} Zeichen)';
                    } catch (e) {
                      _status = 'Fehler: $e';
                    } finally {
                      setState(() => _busy = false);
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Demo laden: B20'),
                  onPressed: _busy ? null : () async {
                    setState(() { _busy = true; _status = 'Lade Demo: B20…'; });
                    try {
                      _rawText = await _loadAssetTextOrPdf('assets/test_docs/B20.pdf');
                      _filePath = 'DEMO: B20.pdf';
                      _status = 'Text bereit (${_rawText!.length} Zeichen)';
                    } catch (e) {
                      _status = 'Fehler: $e';
                    } finally {
                      setState(() => _busy = false);
                    }
                  },
                ),
              ],
            ),

            const Divider(height: 32),

            // Schritt 2 – Text extrahieren
            Text('2) Text extrahieren', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_busy || (_filePath == null && _rawText == null)) ? null : _extractText,
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('Text extrahieren'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _rawText != null ? 'Text bereit (${_rawText!.length} Zeichen)' : '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // Schritt 3 – Karten generieren
            Text('3) Karten generieren', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_busy || _rawText == null) ? null : _generate,
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('Mit GPT-5 nano erzeugen'),
                ),
                const SizedBox(width: 8),
                if (_busy)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _cancelRequested = true);
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Abbrechen'),
                  ),
                const SizedBox(width: 12),
                if (_cards.isNotEmpty) Text('${_cards.length} Karten in Vorschau'),
              ],
            ),

            if (_busy && _totalChunks > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text(
                'Fortschritt: $_currentChunk/$_totalChunks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            if ((_status ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                _status!,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],

            const SizedBox(height: 12),
            Expanded(
              child: _cards.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      itemBuilder: (_, i) {
                        final c = _cards[i];
                        final q = (c['question'] ?? '').toString();
                        final a = (c['answer'] ?? '').toString();
                        return ListTile(
                          title: Text(q),
                          subtitle: Text(a),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _cards.length,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_busy || _cards.isEmpty) ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Karten speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}