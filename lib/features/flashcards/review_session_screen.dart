import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../features/flashcards/spaced_repetition.dart';

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key, required this.deckRef});
  final DocumentReference<Map<String, dynamic>> deckRef;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  Future<void> _loadDueCards() async {
    final nowIso = DateTime.now().toIso8601String();
    final snap = await widget.deckRef
        .collection('cards')
        .where('due', isLessThanOrEqualTo: nowIso)
        .orderBy('due')
        .limit(100)
        .get();

    setState(() {
      _queue = snap.docs;
      _loading = false;
      _currentIndex = 0;
      _showAnswer = false;
    });
  }

  Future<void> _rateCard(int quality) async {
    final doc = _queue[_currentIndex];
    final data = doc.data();
    final updated = SpacedRepetition.reviewCard(data, quality);
    await doc.reference.update(updated);

    setState(() {
      _currentIndex++;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Review")),
        body: const Center(child: Text("Keine fälligen Karten 🎉")),
      );
    }

    if (_currentIndex >= _queue.length) {
      return Scaffold(
        appBar: AppBar(title: const Text("Review")),
        body: const Center(child: Text("Session beendet ✅")),
      );
    }

    final card = _queue[_currentIndex].data();
    final q = (card['question'] as String?)?.toString() ?? '';
    final a = (card['answer'] as String?)?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Review ${_currentIndex + 1}/${_queue.length}")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    AnimatedCrossFade(
                      crossFadeState:
                          _showAnswer ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                      firstChild: const SizedBox(height: 0),
                      secondChild: Text(
                        a,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // ✅ Schöne Bottom-Bar:
      // - Vor der Antwort: nur "Antwort zeigen" (blauer, gefüllter Button)
      // - Nach der Antwort: SR-Buttons "Schwer / Gut / Einfach"
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _showAnswer
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // SCHWER (quality 0)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => _rateCard(0),
                      icon: const Icon(Icons.close),
                      label: const Text("Schwer"),
                    ),
                    // GUT (quality 1)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => _rateCard(1),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Gut"),
                    ),
                    // EINFACH (quality 2)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => _rateCard(2),
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text("Einfach"),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Abbrechen/Schließen
                    IconButton.filled(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                    // 🔵 Gefüllter Check (kein weißer Ring mehr)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => setState(() => _showAnswer = true),
                      icon: const Icon(Icons.check),
                      label: const Text("Antwort zeigen"),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}