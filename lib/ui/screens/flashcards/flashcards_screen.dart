import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';
import 'package:flutterquiz/ui/widgets/circular_progress_container.dart';

import 'card_excel_import.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});
  static const routeName = '/flashcards';
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool showLocal = true;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;

  // Utils
  int _clampInt(int v) => v < 0 ? 0 : v;

  // Fixed categories list
  static const List<String> kDeckCategories = [
    'Divers',
    'Anatomie',
    'Physiologie',
    'Biochemie',
    'Pathologie',
    'Pharmakologie',
    'Innere Medizin',
    'Kardiologie',
    'Gastroenterologie',
    'Pneumologie',
    'Neurologie',
    'Chirurgie',
    'Gynäkologie',
    'Pädiatrie',
    'Psychiatrie',
    'Radiologie',
    'Allgemeinmedizin',
  ];

  Stream<_DeckCounters> _countersStream() async* {
    final userDecks = _db.collection('users').doc(_uid).collection('decks');
    final progress = _db.collection('users').doc(_uid).collection('progress');

    // Done/Left: Fallback auf 0 wenn progress-Dok nicht existiert
    final progSnap = await progress.get();
    int done = 0;
    int left = 0;
    for (final d in progSnap.docs) {
      final data = d.data();
      final dc = data['doneCount'];
      final lc = data['leftCount'];
      done += (dc is int) ? dc : 0;
      left += (lc is int) ? _clampInt(lc) : 0;
    }
    // Wenn keine progress-Daten: versuche count() der Karten als "left"
    if (done == 0 && left == 0) {
      final ds = await userDecks.get();
      int total = 0;
      for (final deck in ds.docs) {
        final cardsAgg = await userDecks
            .doc(deck.id)
            .collection('cards')
            .count()
            .get();
        total += cardsAgg.count ?? 0;
      }
      left = total;
    }
    yield _DeckCounters(done: done, left: left);
  }

  Query<Map<String, dynamic>> _decksQuery() {
    if (showLocal) {
      return _db
          .collection('users')
          .doc(_uid)
          .collection('decks')
          .orderBy('updatedAt', descending: true);
    } else {
      return _db
          .collection('public_decks')
          .orderBy('updatedAt', descending: true);
    }
  }

  Future<int> _cardCount(String deckId) async {
    final base = showLocal
        ? _db.collection('users').doc(_uid).collection('decks').doc(deckId)
        : _db.collection('public_decks').doc(deckId);
    // Bevorzugt: gespeichertes Feld cardCount
    final doc = await base.get();
    final data = doc.data();
    final cc = (data?['cardCount'] as int?);
    if (cc != null) return cc;
    // Fallback: Aggregation
    final agg = await base.collection('cards').count().get();
    return agg.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E0E) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1B1B1B) : const Color(0xFFEFF4FF)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'MedDeck',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: Column(
        children: [
          // KPI Kacheln
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1B1B)
                    : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(stream: _countersStream(), isLeft: true),
                  ),
                  Container(
                    width: 1,
                    height: 78,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  Expanded(
                    child: _StatTile(stream: _countersStream(), isLeft: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // "DECKS" Label + Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF232323)
                          : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'DECKS',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SegmentedChip(
                      label: 'Lokal',
                      selected: showLocal,
                      onTap: () => setState(() => showLocal = true),
                    ),
                    const SizedBox(width: 10),
                    _SegmentedChip(
                      label: 'Online',
                      selected: !showLocal,
                      onTap: () => setState(() => showLocal = false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Deck-Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _decksQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressContainer());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      showLocal
                          ? 'Keine lokalen Decks'
                          : 'Keine öffentlichen Decks',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (c, i) {
                    final d = docs[i];
                    final rawTitle = d.data()['title'];
                    final title = (rawTitle is String && rawTitle.isNotEmpty)
                        ? rawTitle
                        : 'Unbenannt';
                    final ownerName = showLocal
                        ? null
                        : (d.data()['ownerName'] as String?) ?? 'Unbekannt';
                    final views = showLocal
                        ? null
                        : (d.data()['views'] as int?) ?? 0;
                    final ownerId = showLocal
                        ? null
                        : (d.data()['ownerId'] as String?);
                    return FutureBuilder<int>(
                      future: _cardCount(d.id),
                      builder: (c2, cnt) {
                        final trailing = cnt.hasData ? cnt.data! : 0;
                        return _DeckTile(
                          title: title,
                          trailing: trailing,
                          ownerName: ownerName,
                          views: views,
                          onTap: () async {
                            if (!showLocal) {
                              try {
                                final isOwner =
                                    ownerId != null && ownerId == _uid;
                                if (!isOwner) {
                                  await _db
                                      .collection('public_decks')
                                      .doc(d.id)
                                      .update({
                                        'views': FieldValue.increment(1),
                                      });
                                }
                              } catch (_) {}
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _DeckDetailScreen(
                                  deckId: d.id,
                                  isLocal: showLocal,
                                  title: title,
                                  uid: _uid,
                                ),
                              ),
                            );
                          },
                          onPlay: () {
                            final baseDoc = showLocal
                                ? _db
                                      .collection('users')
                                      .doc(_uid)
                                      .collection('decks')
                                      .doc(d.id)
                                : _db.collection('public_decks').doc(d.id);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _ReviewSessionScreen(
                                  deckRef: baseDoc,
                                  uid: _uid,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: docs.length,
                );
              },
            ),
          ),
          // Bottom Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _PrimaryPillButton(
                    label: 'New Deck',
                    icon: Icons.add,
                    onTap: () async {
                      final controller = TextEditingController();
                      String selectedCategory = kDeckCategories.first;
                      await showDialog(
                        context: context,
                        builder: (_) => StatefulBuilder(
                          builder: (ctx, setSt) => AlertDialog(
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              8,
                            ),
                            title: const Text('Neues Deck'),
                            content: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  // Keep within dialog's width and provide comfortable layout on phones
                                  maxWidth: 560,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        hintText: 'Titel',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppDropdown<String>(
                                            label: 'Kategorie',
                                            hintText: 'Kategorie wählen…',
                                            items: kDeckCategories,
                                            itemLabel: (c) => c,
                                            value: selectedCategory,
                                            onChanged: (v) => setSt(
                                              () => selectedCategory =
                                                  v ?? kDeckCategories.first,
                                            ),
                                            borderRadius: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Optional für private Decks. Erforderlich, wenn du veröffentlichst.',
                                        softWrap: true,
                                        overflow: TextOverflow.fade,
                                        maxLines: 2,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final title = controller.text.trim().isEmpty
                                      ? 'Unbenannt'
                                      : controller.text.trim();
                                  final base = showLocal
                                      ? _db
                                            .collection('users')
                                            .doc(_uid)
                                            .collection('decks')
                                      : _db.collection('public_decks');

                                  if (!showLocal &&
                                      (selectedCategory.isEmpty ||
                                          selectedCategory == 'Divers')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Kategorie erforderlich für öffentliche Decks.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  final ownerName =
                                      currentUser?.displayName ?? 'Unbekannt';
                                  final payload = {
                                    'title': title,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                    'cardCount': 0,
                                    'category': selectedCategory,
                                    'isPublic': !showLocal,
                                    if (!showLocal) 'ownerId': _uid,
                                    if (!showLocal) 'ownerName': ownerName,
                                    if (!showLocal) 'views': 0,
                                  };
                                  await base.add(payload);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('Erstellen'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _CircleButton(icon: Icons.settings, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Called when the bottom nav tab is tapped again
  // Keeping it no-op avoids runtime errors from dynamic call
  void onTapTab() {}
}

class _DeckCounters {
  final int done;
  final int left;
  const _DeckCounters({required this.done, required this.left});
}

class _StatTile extends StatelessWidget {
  final Stream<_DeckCounters> stream;
  final bool isLeft;
  const _StatTile({required this.stream, required this.isLeft});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<_DeckCounters>(
      stream: stream,
      builder: (c, s) {
        final done = s.data?.done ?? 0;
        final left = s.data?.left ?? 0;
        final big = TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF2563FF),
        );
        final small = TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Text(isLeft ? '$done' : '${left < 0 ? 0 : left}', style: big),
              const SizedBox(height: 4),
              Text(isLeft ? 'Cards Done' : 'Left to Answer', style: small),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563FF)
              : (isDark ? const Color(0xFF242424) : const Color(0xFFF2F2F2)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final String title;
  final int trailing;
  final VoidCallback onTap;
  final VoidCallback? onPlay; // NEW
  final String? ownerName;
  final int? views;
  const _DeckTile({
    required this.title,
    required this.trailing,
    required this.onTap,
    this.onPlay,
    this.ownerName,
    this.views,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFEDEDED),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ownerName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'von ${ownerName!}${views != null ? ' • ${views!} Aufrufe' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$trailing',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              if (onPlay != null)
                Material(
                  color: const Color(0xFF2563FF),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPlay,
                    child: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2563FF),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEDEDED),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(Icons.settings, size: 22),
        ),
      ),
    );
  }
}

/// Minimaler Detail-Screen: zeigt Kartenliste + Stub fürs Review
class _DeckDetailScreen extends StatelessWidget {
  final String deckId;
  final bool isLocal;
  final String title;
  final String uid;
  const _DeckDetailScreen({
    required this.deckId,
    required this.isLocal,
    required this.title,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final base = isLocal
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('decks')
              .doc(deckId)
        : FirebaseFirestore.instance.collection('public_decks').doc(deckId);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          runAlignment: WrapAlignment.end,
          children: [
            if (isLocal)
              FloatingActionButton.extended(
                heroTag: 'import_excel',
                onPressed: () => _onImportFromExcel(context, base),
                label: const Text('Aus Excel importieren'),
                icon: const Icon(Icons.file_upload_outlined),
              ),
            FloatingActionButton.extended(
              heroTag: 'add_card',
              onPressed: () => _openAddCardSheet(context, base),
              label: const Text('Neue Karte'),
              icon: const Icon(Icons.post_add),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: base.snapshots(),
              builder: (ctx, snap) {
                final data = snap.data?.data() ?? <String, dynamic>{};
                final isPublic = (data['isPublic'] as bool?) ?? false;
                final category = (data['category'] as String?) ?? 'Divers';
                final owner = (data['ownerName'] as String?) ?? 'Unbekannt';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Material(
                          color: const Color(0xFF2563FF),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _ReviewSessionScreen(
                                    deckRef: base,
                                    uid: uid,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(14.0),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isLocal)
                          OutlinedButton.icon(
                            icon: Icon(
                              isPublic ? Icons.public : Icons.public_off,
                            ),
                            label: const Text('Öffentlich'),
                            onPressed: () async {
                              final wantPublic = !isPublic;
                              if (wantPublic) {
                                if (category.isEmpty || category == 'Divers') {
                                  final proceed = await _requireCategoryAndPick(
                                    ctx,
                                    base,
                                    requireNonDivers: true,
                                  );
                                  if (proceed != true) return;
                                }
                                await _publishDeck(ctx, base, uid);
                              } else {
                                await _unpublishDeck(ctx, base);
                              }
                            },
                          )
                        else
                          InputChip(
                            avatar: const Icon(Icons.public, size: 18),
                            label: const Text('Öffentlich'),
                            onPressed: null,
                          ),
                      ],
                    ),
                    if (!isLocal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'von $owner',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: base
                  .collection('cards')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (c, s) {
                if (!s.hasData)
                  return const Center(child: CircularProgressContainer());
                final docs = s.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text('Noch keine Karten.'));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final map = docs[i].data();
                    final q = map['question'] as String? ?? '';
                    final a = map['answer'] as String? ?? '';
                    final imagePath = map['imagePath'] as String?;
                    return ListTile(
                      leading: (imagePath == null)
                          ? null
                          : FutureBuilder<String>(
                              future: FirebaseStorage.instance
                                  .ref(imagePath)
                                  .getDownloadURL(),
                              builder: (ctx, snap) {
                                if (!snap.hasData)
                                  return const SizedBox(width: 44, height: 44);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    snap.data!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                      tileColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1B1B1B)
                          : const Color(0xFFF2F2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(q),
                      subtitle: Text(
                        a,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _ReviewCardView(
                              question: q,
                              answer: a,
                              deckRef: base,
                              imagePath: imagePath,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: docs.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onImportFromExcel(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> deckRef,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null) {
      final path = file.path;
      if (path != null) {
        try {
          bytes = await File(path).readAsBytes();
        } catch (e, st) {
          debugPrint('Excel import read error: $e\n$st');
        }
      }
    }
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        await _showSimpleDialog(
          context,
          title: 'Import abgebrochen',
          message: 'Die ausgewählte Datei konnte nicht gelesen werden.',
        );
      }
      return;
    }

    final closeParsingLoader = _showBlockingLoader(
      context,
      'Excel wird analysiert…',
    );
    Map<String, dynamic> rawParseResult;
    try {
      rawParseResult = await compute(parseExcelBytesSerializable, bytes);
    } catch (e, st) {
      debugPrint('Excel parsing failed: $e\n$st');
      closeParsingLoader();
      if (context.mounted) {
        await _showSimpleDialog(
          context,
          title: 'Fehler beim Einlesen',
          message: 'Die Excel-Datei konnte nicht verarbeitet werden.',
        );
      }
      return;
    }
    closeParsingLoader();
    if (!context.mounted) return;

    final parseResult = ExcelParseResult.fromMap(
      Map<String, dynamic>.from(rawParseResult),
    );
    if (parseResult.hasFatalError) {
      await _showSimpleDialog(
        context,
        title: 'Import nicht möglich',
        message: parseResult.fatalMessage!,
      );
      return;
    }
    if (parseResult.cards.isEmpty) {
      final message = parseResult.errors.isEmpty
          ? 'Es wurden keine gültigen Karten gefunden.'
          : 'Alle Zeilen enthalten Fehler und können nicht importiert werden.';
      await _showSimpleDialog(
        context,
        title: 'Import nicht möglich',
        message: message,
      );
      return;
    }

    final preview = await _showImportPreviewDialog(context, parseResult);
    if (preview == null) return;

    final closeImportLoader = _showBlockingLoader(
      context,
      'Karten werden importiert…',
    );
    try {
      final existingSnap = await deckRef.collection('cards').get();
      final existing = existingSnap.docs
          .map(
            (doc) => <String, dynamic>{
              'question': (doc.data()['question'] as String?) ?? '',
              'answer': (doc.data()['answer'] as String?) ?? '',
            },
          )
          .toList(growable: false);
      final existingKeysList = await compute(
        buildCardKeysSerializable,
        existing,
      );
      final seenKeys = existingKeysList.toSet();
      final pendingWrites = <_PendingCardWrite>[];
      var duplicatesSkipped = 0;

      for (final card in parseResult.cards) {
        final key = buildCardKey(card.question, card.answer);
        final alreadyExists = seenKeys.contains(key);
        if (alreadyExists) {
          if (preview.skipDuplicates) {
            duplicatesSkipped++;
            continue;
          }
        }
        seenKeys.add(key);
        final docRef = deckRef.collection('cards').doc();
        final data = <String, dynamic>{
          'question': card.question,
          'answer': card.answer,
          if (card.explanation != null) 'explanation': card.explanation,
          if (card.tags.isNotEmpty) 'tags': card.tags,
          if (card.imageUrl != null) 'imageUrl': card.imageUrl,
          if (card.source != null) 'source': card.source,
          if (card.difficulty != null) 'difficulty': card.difficulty,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        pendingWrites.add(_PendingCardWrite(ref: docRef, data: data));
      }

      final addedCount = pendingWrites.length;
      if (addedCount == 0) {
        closeImportLoader();
        if (context.mounted) {
          final info = duplicatesSkipped > 0
              ? ' Alle Einträge waren Duplikate.'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Keine neuen Karten importiert.$info')),
          );
        }
        return;
      }

      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      var operations = 0;

      Future<void> commitBatch() async {
        await batch.commit();
        batch = firestore.batch();
        operations = 0;
      }

      for (final write in pendingWrites) {
        batch.set(write.ref, write.data);
        operations++;
        if (operations >= 450) {
          await commitBatch();
        }
      }

      batch.update(deckRef, {
        'cardCount': FieldValue.increment(addedCount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      operations++;

      if (operations > 0) {
        await batch.commit();
      }

      final isLocalDeck = deckRef.parent.id == 'decks';
      if (isLocalDeck) {
        final deckSnap = await deckRef.get();
        final isPublicDeck = (deckSnap.data()?['isPublic'] as bool?) ?? false;
        if (isPublicDeck) {
          final publicDeckRef = FirebaseFirestore.instance
              .collection('public_decks')
              .doc(deckRef.id);
          WriteBatch publicBatch = firestore.batch();
          var publicOps = 0;

          Future<void> commitPublicBatch() async {
            await publicBatch.commit();
            publicBatch = firestore.batch();
            publicOps = 0;
          }

          for (final write in pendingWrites) {
            publicBatch.set(
              publicDeckRef.collection('cards').doc(write.ref.id),
              write.data,
            );
            publicOps++;
            if (publicOps >= 450) {
              await commitPublicBatch();
            }
          }

          publicBatch.set(
            publicDeckRef,
            {
              'cardCount': FieldValue.increment(addedCount),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          publicOps++;
          if (publicOps > 0) {
            await publicBatch.commit();
          }
        }
      }

      closeImportLoader();
      if (context.mounted) {
        final skippedTotal = duplicatesSkipped;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import abgeschlossen: $addedCount hinzugefügt, $skippedTotal übersprungen.',
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Excel import failed: $e\n$st');
      closeImportLoader();
      if (context.mounted) {
        await _showSimpleDialog(
          context,
          title: 'Import fehlgeschlagen',
          message:
              'Beim Import ist ein Fehler aufgetreten. Bitte versuche es erneut.',
        );
      }
    }
  }

  Future<_ImportPreviewResult?> _showImportPreviewDialog(
    BuildContext context,
    ExcelParseResult result,
  ) {
    bool skipDuplicates = true;
    return showDialog<_ImportPreviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final previewCards = result.cards.take(5).toList();
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Excel-Vorschau'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gefundene Zeilen: ${result.totalRows}'),
                      Text('Gültige Karten: ${result.cards.length}'),
                      Text('Fehlerhafte Zeilen: ${result.errors.length}'),
                      const SizedBox(height: 12),
                      if (previewCards.isNotEmpty) ...[
                        Text(
                          'Vorschau (max. 5):',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _buildPreviewTable(ctx, previewCards),
                      ] else
                        Text(
                          'Keine gültigen Einträge zur Vorschau.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (result.errors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Fehler (max. 10):',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        ...result.errors
                            .take(10)
                            .map(
                              (err) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'Zeile ${err.rowNumber}: ${err.message}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ),
                      ],
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: skipDuplicates,
                        onChanged: (value) =>
                            setState(() => skipDuplicates = value ?? true),
                        title: const Text('Duplikate überspringen (empfohlen)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: result.cards.isEmpty
                      ? null
                      : () => Navigator.of(ctx).pop(
                          _ImportPreviewResult(skipDuplicates: skipDuplicates),
                        ),
                  child: const Text('Importieren'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewTable(BuildContext context, List<ExcelImportCard> cards) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodySmall;
    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        children: [
          _previewHeaderCell('Frage', headerStyle),
          _previewHeaderCell('Antwort', headerStyle),
          _previewHeaderCell('Details', headerStyle),
        ],
      ),
    ];

    for (final card in cards) {
      rows.add(
        TableRow(
          children: [
            _previewBodyCell(card.question, bodyStyle),
            _previewBodyCell(card.answer, bodyStyle),
            _previewBodyCell(_previewMeta(card), bodyStyle),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(0.9),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  Widget _previewHeaderCell(String text, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, style: style),
    );
  }

  Widget _previewBodyCell(String text, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text.isEmpty ? '-' : text,
        style: style,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _previewMeta(ExcelImportCard card) {
    final parts = <String>[];
    if (card.difficulty != null) parts.add('Stufe ${card.difficulty}');
    if (card.tags.isNotEmpty) parts.add(card.tags.join(', '));
    if (card.source != null && card.source!.isNotEmpty) parts.add(card.source!);
    return parts.isEmpty ? '-' : parts.join(' • ');
  }

  Future<void> _showSimpleDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  VoidCallback _showBlockingLoader(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    return () {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    };
  }

  Future<void> _openAddCardSheet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> deckRef,
  ) async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    Uint8List? imageBytes; // eventuell bereits verkleinert
    String? pickedName;

    Future<void> pickImage() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.single;
      if (file.bytes == null) return;

      final compressed = await _downscaleToUnder1MB(file.bytes!);
      if (compressed == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bild konnte nicht ausreichend komprimiert werden.',
              ),
            ),
          );
        }
        return;
      }
      imageBytes = compressed;
      pickedName = file.name;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B1B1B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Neue Karte',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qCtrl,
                    decoration: const InputDecoration(labelText: 'Frage'),
                    maxLines: null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: aCtrl,
                    decoration: const InputDecoration(labelText: 'Antwort'),
                    maxLines: null,
                  ),
                  const SizedBox(height: 12),
                  if (imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imageBytes!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await pickImage();
                          setSheet(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          imageBytes == null ? 'Bild wählen' : 'Bild ändern',
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final q = qCtrl.text.trim();
                          final a = aCtrl.text.trim();
                          if (q.isEmpty || a.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Frage und Antwort dürfen nicht leer sein.',
                                ),
                              ),
                            );
                            return;
                          }

                          String? storagePath;
                          if (imageBytes != null) {
                            final uid = FirebaseAuth.instance.currentUser!.uid;
                            final deckId = deckRef.id;
                            final ext = _inferExtFromName(pickedName) ?? 'png';
                            final id = FirebaseFirestore.instance
                                .collection('_ids')
                                .doc()
                                .id;
                            storagePath =
                                'users/' +
                                uid +
                                '/decks/' +
                                deckId +
                                '/images/' +
                                id +
                                '.' +
                                ext;

                            final ref = FirebaseStorage.instance.ref().child(
                              storagePath,
                            );
                            final meta = SettableMetadata(
                              contentType: ext == 'png'
                                  ? 'image/png'
                                  : 'image/jpeg',
                            );
                            await ref.putData(imageBytes!, meta);
                          }

                          final cardData = {
                            'question': q,
                            'answer': a,
                            if (storagePath != null) 'imagePath': storagePath,
                            'createdAt': FieldValue.serverTimestamp(),
                          };

                          final newCardRef = await deckRef
                              .collection('cards')
                              .add(cardData);
                          await deckRef.update({
                            'cardCount': FieldValue.increment(1),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          // If local deck is published, mirror to public deck
                          try {
                            final isLocalDeck = deckRef.parent.id == 'decks';
                            if (isLocalDeck) {
                              final deckSnap = await deckRef.get();
                              final isPublic =
                                  (deckSnap.data()?['isPublic'] as bool?) ??
                                  false;
                              if (isPublic) {
                                final pubRef = FirebaseFirestore.instance
                                    .collection('public_decks')
                                    .doc(deckRef.id);
                                await pubRef
                                    .collection('cards')
                                    .doc(newCardRef.id)
                                    .set(cardData);
                                await pubRef.set({
                                  'cardCount': FieldValue.increment(1),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              }
                            }
                          } catch (_) {}

                          if (context.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Speichern'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String? _inferExtFromName(String? name) {
    if (name == null) return null;
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.png')) return 'png';
    return null;
  }

  Future<Uint8List?> _downscaleToUnder1MB(Uint8List bytes) async {
    const maxBytes = 1024 * 1024; // 1MB
    if (bytes.lengthInBytes <= maxBytes) return bytes;

    for (final target in [1200, 1000, 800, 640, 512, 400]) {
      try {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: target,
          allowUpscaling: false,
        );
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bd == null) continue;
        final out = bd.buffer.asUint8List();
        if (out.lengthInBytes <= maxBytes) return out;
      } catch (_) {
        // Nächste Stufe versuchen
      }
    }
    return null;
  }

  Future<bool?> _requireCategoryAndPick(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> localDeckRef, {
    bool requireNonDivers = false,
  }) async {
    String selected = 'Divers';
    try {
      final snap = await localDeckRef.get();
      final c = (snap.data()?['category'] as String?) ?? 'Divers';
      selected = c.isNotEmpty ? c : 'Divers';
    } catch (_) {}

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B1B1B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String current = selected;
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategorie erforderlich',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bitte wähle eine fachliche Kategorie, bevor du das Deck veröffentlichst.',
                ),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: 'Kategorie',
                  hintText: 'Kategorie wählen…',
                  items: _FlashcardsScreenState.kDeckCategories,
                  itemLabel: (c) => c,
                  value: current,
                  onChanged: (v) => setSt(() => current = v ?? 'Divers'),
                  borderRadius: 16,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        if (requireNonDivers &&
                            (current.isEmpty || current == 'Divers')) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Bitte gültige Kategorie wählen.'),
                            ),
                          );
                          return;
                        }
                        await localDeckRef.set({
                          'category': current,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        if (context.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Kategorie wählen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _publishDeck(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> localDeckRef,
    String uid,
  ) async {
    final deckId = localDeckRef.id;
    final localSnap = await localDeckRef.get();
    final title = (localSnap.data()?['title'] as String?) ?? 'Unbenannt';
    final category = (localSnap.data()?['category'] as String?) ?? 'Divers';
    final createdAt = localSnap.data()?['createdAt'];
    final cardCount = (localSnap.data()?['cardCount'] as int?) ?? 0;
    final ownerName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Unbekannt';

    if (category.isEmpty || category == 'Divers') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategorie erforderlich, um zu veröffentlichen.'),
        ),
      );
      return;
    }

    await localDeckRef.set({
      'isPublic': true,
      'ownerId': uid,
      'ownerName': ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final pubRef = FirebaseFirestore.instance
        .collection('public_decks')
        .doc(deckId);
    await pubRef.set({
      'title': title,
      'category': category,
      'cardCount': cardCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isPublic': true,
      'ownerId': uid,
      'ownerName': ownerName,
      'views': (localSnap.data()?['views'] as int?) ?? 0,
    }, SetOptions(merge: true));

    final cardsSnap = await localDeckRef
        .collection('cards')
        .orderBy('createdAt')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final c in cardsSnap.docs) {
      batch.set(
        pubRef.collection('cards').doc(c.id),
        c.data(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deck wurde veröffentlicht.')),
      );
    }
  }

  Future<void> _unpublishDeck(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> localDeckRef,
  ) async {
    final deckId = localDeckRef.id;
    await localDeckRef.set({
      'isPublic': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final pubRef = FirebaseFirestore.instance
        .collection('public_decks')
        .doc(deckId);
    try {
      await pubRef.delete();
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deck ist nun privat.')),
      );
    }
  }
}

class _ImportPreviewResult {
  const _ImportPreviewResult({required this.skipDuplicates});

  final bool skipDuplicates;
}

class _PendingCardWrite {
  _PendingCardWrite({required this.ref, required this.data});

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
}

/// Sehr einfache Review-Ansicht (Flip per Tap)
class _ReviewCardView extends StatefulWidget {
  final String question;
  final String answer;
  final DocumentReference<Map<String, dynamic>> deckRef;
  final String? imagePath; // optional header image

  const _ReviewCardView({
    required this.question,
    required this.answer,
    required this.deckRef,
    this.imagePath,
  });

  @override
  State<_ReviewCardView> createState() => _ReviewCardViewState();
}

class _ReviewCardViewState extends State<_ReviewCardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      backgroundColor: isDark ? const Color(0xFF0E0E0E) : Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 12),
          if (widget.imagePath != null)
            FutureBuilder<String>(
              future: FirebaseStorage.instance
                  .ref(widget.imagePath!)
                  .getDownloadURL(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox(height: 12);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      snap.data!,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _toggleFlip,
                child: _buildFlipCard(context),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF141414)
                : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundIcon(
                context,
                icon: Icons.thumb_down_alt_rounded,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _roundIcon(
                context,
                icon: Icons.visibility_rounded,
                onTap: _toggleFlip,
              ),
              _roundIcon(
                context,
                icon: Icons.thumb_up_alt_rounded,
                primary: true,
                onTap: () async {
                  final progDoc = FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('progress')
                      .doc(widget.deckRef.id);
                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final s = await tx.get(progDoc);
                    final prevDone = (s.data()?['doneCount'] as int?) ?? 0;
                    final prevLeft = (s.data()?['leftCount'] as int?) ?? 0;
                    final newLeft = prevLeft - 1;
                    tx.set(
                      progDoc,
                      {
                        'doneCount': prevDone + 1,
                        'leftCount': newLeft < 0 ? 0 : newLeft,
                      },
                      SetOptions(merge: true),
                    );
                  });
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFlip() {
    if (_showAnswer) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  Widget _buildFlipCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final angle = _ctrl.value * 3.14159;
        final isBack = angle > 1.5708;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.82,
            height: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(isBack ? 3.14159 : 0),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  isBack ? widget.answer : widget.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _roundIcon(
    BuildContext context, {
    required IconData icon,
    bool primary = false,
    required VoidCallback onTap,
  }) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primary
              ? const Color(0xFF2563FF)
              : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF2F2F2)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: primary
              ? Colors.white
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87),
        ),
      ),
    );
  }
}

class _ReviewSessionScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> deckRef;
  final String uid;
  const _ReviewSessionScreen({required this.deckRef, required this.uid});
  @override
  State<_ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<_ReviewSessionScreen>
    with SingleTickerProviderStateMixin {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cards = [];
  int _index = 0;
  bool _loading = true;

  late AnimationController _ctrl;
  bool _showAnswer = false;

  int _successCount = 0;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Load deck cards
    final deckSnap = await widget.deckRef
        .collection('cards')
        .orderBy('createdAt')
        .get();
    final allCards = deckSnap.docs;

    // Load per-user review states for this deck
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('reviews')
        .doc(widget.deckRef.id)
        .collection('cards')
        .get();
    final Map<String, Map<String, dynamic>> reviewMap = {
      for (final d in reviewsSnap.docs) d.id: d.data(),
    };

    final now = DateTime.now();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> due = [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> later = [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> fresh = [];

    for (final c in allCards) {
      final r = reviewMap[c.id];
      if (r == null) {
        fresh.add(c);
      } else {
        final dueTs = r['due'];
        DateTime? dueAt;
        if (dueTs is Timestamp) dueAt = dueTs.toDate();
        if (dueAt != null && !dueAt.isAfter(now)) {
          due.add(c);
        } else {
          later.add(c);
        }
      }
    }

    // Session strategy: prefer due; if none due, take up to 20 new cards; else fall back to all
    List<QueryDocumentSnapshot<Map<String, dynamic>>> session;
    if (due.isNotEmpty) {
      session = due;
    } else if (fresh.isNotEmpty) {
      const int NEW_LIMIT = 20;
      session = fresh.take(NEW_LIMIT).toList();
    } else {
      session = allCards; // fallback
    }

    _cards = session;
    setState(() => _loading = false);
  }

  Future<void> _rate(String cardId, {required bool success}) async {
    final prog = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('reviews')
        .doc(widget.deckRef.id)
        .collection('cards')
        .doc(cardId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(prog);
      double ease = 2.5; // starting ease
      int interval = 0;
      int reps = 0;
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        ease = (d['ease'] as num?)?.toDouble() ?? 2.5;
        interval = (d['interval'] as int?) ?? 0;
        reps = (d['reps'] as int?) ?? 0;
      }

      if (success) {
        reps += 1;
        if (reps == 1) {
          interval = 1;
        } else if (reps == 2) {
          interval = 6;
        } else {
          interval = (interval * ease).round().clamp(1, 3650);
        }
      } else {
        reps = 0;
        ease = (ease - 0.2).clamp(1.3, 3.0);
        interval = 1; // see again tomorrow
      }

      final due = Timestamp.fromDate(
        DateTime.now().add(Duration(days: interval)),
      );

      tx.set(prog, {
        'ease': ease,
        'interval': interval,
        'reps': reps,
        'due': due,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (success) {
        final deckProg = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('progress')
            .doc(widget.deckRef.id);
        final deckProgSnap = await tx.get(deckProg);
        final prevDone = (deckProgSnap.data()?['doneCount'] as int?) ?? 0;
        final prevLeft = (deckProgSnap.data()?['leftCount'] as int?) ?? 0;
        final newLeft = prevLeft - 1;
        tx.set(
          deckProg,
          {
            'doneCount': prevDone + 1,
            'leftCount': newLeft < 0 ? 0 : newLeft,
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  void _nextCard() {
    setState(() {
      _showAnswer = false;
      _ctrl.reset();
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressContainer()));
    if (_index >= _cards.length) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final total = _successCount + _failCount;
      final accuracy = total == 0
          ? 0
          : (((_successCount) / total) * 100).round();
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E0E0E) : Colors.white,
        appBar: AppBar(title: const Text('Review')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Session abgeschlossen ✨',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _summaryChip('Success', _successCount),
                const SizedBox(height: 8),
                _summaryChip('Fail', _failCount),
                const SizedBox(height: 16),
                Text('Accuracy: $accuracy%'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zurück zum Deck'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _cards[_index].data();
    final q = data['question'] as String? ?? '';
    final a = data['answer'] as String? ?? '';
    final imagePath = data['imagePath'] as String?;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E0E) : Colors.white,
      appBar: AppBar(title: const Text('Review')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          if (imagePath != null)
            FutureBuilder<String>(
              future: FirebaseStorage.instance.ref(imagePath).getDownloadURL(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox(height: 12);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      snap.data!,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_showAnswer) {
                    _ctrl.reverse();
                  } else {
                    _ctrl.forward();
                  }
                  setState(() => _showAnswer = !_showAnswer);
                },
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final angle = _ctrl.value * 3.14159;
                    final isBack = angle > 1.5708;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        height: 260,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1C1C)
                              : const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(isBack ? 3.14159 : 0),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              isBack ? a : q,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundIcon(
                context,
                icon: Icons.close_rounded,
                onTap: () async {
                  await _rate(_cards[_index].id, success: false);
                  setState(() => _failCount++);
                  _nextCard();
                },
              ),
              _roundIcon(
                context,
                icon: Icons.check_circle_rounded,
                primary: true,
                onTap: () async {
                  await _rate(_cards[_index].id, success: true);
                  setState(() => _successCount++);
                  _nextCard();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(
    BuildContext context, {
    required IconData icon,
    bool primary = false,
    required VoidCallback onTap,
  }) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primary
              ? const Color(0xFF2563FF)
              : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF2F2F2)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: primary
              ? Colors.white
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
