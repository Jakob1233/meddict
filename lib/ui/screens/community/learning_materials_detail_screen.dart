import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'learning_materials_model.dart';

class LearningMaterialDetailScreen extends StatefulWidget {
  const LearningMaterialDetailScreen({super.key, required this.materialId, this.initialMaterial});

  final String materialId;
  final LearningMaterial? initialMaterial;

  @override
  State<LearningMaterialDetailScreen> createState() => _LearningMaterialDetailScreenState();
}

class _LearningMaterialDetailScreenState extends State<LearningMaterialDetailScreen> {
  LearningMaterial? _material;
  bool _isLoading = false;
  bool _bookmark = false;
  bool _isOpening = false;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _material = widget.initialMaterial;
    _loadMaterial(incrementView: true);
  }

  Future<void> _loadMaterial({bool incrementView = false}) async {
    setState(() => _isLoading = _material == null);
    final docRef = FirebaseFirestore.instance.collection('materials').doc(widget.materialId);

    try {
      LearningMaterial? material;
      if (incrementView) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            throw StateError('Material nicht gefunden.');
          }
          transaction.update(docRef, {'views': FieldValue.increment(1)});
          material = LearningMaterial.fromDoc(snapshot);
        });
        if (material != null) {
          material = material!.copyWith(views: material!.views + 1);
        }
      } else {
        final snapshot = await docRef.get();
        if (!snapshot.exists) {
          throw StateError('Material nicht gefunden.');
        }
        material = LearningMaterial.fromDoc(snapshot);
      }

      if (!mounted) return;
      setState(() {
        _material = material;
        _isLoading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $err')),
      );
    }
  }

  Future<void> _openMaterial() async {
    final material = _material;
    if (material == null || material.fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Datei verfügbar.')),
      );
      return;
    }

    setState(() => _isOpening = true);
    try {
      final uri = Uri.parse(material.fileUrl);
      final isPdf = uri.path.toLowerCase().endsWith('.pdf');
      if (!kIsWeb && isPdf && _supportsInAppWebView()) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _MaterialPdfViewerScreen(title: material.title, url: uri.toString())),
        );
      } else {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Die Datei konnte nicht geöffnet werden.')),
          );
        }
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Öffnen fehlgeschlagen: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  bool _supportsInAppWebView() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  void _toggleBookmark() {
    setState(() => _bookmark = !_bookmark);
  }

  @override
  Widget build(BuildContext context) {
    final material = _material;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(material);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(material),
          ),
          title: const Text('Material'),
          centerTitle: false,
        ),
        body: SafeArea(
          child: _isLoading && material == null
              ? const Center(child: CircularProgressIndicator())
              : material == null
                  ? const Center(child: Text('Material wurde nicht gefunden.'))
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _metaLine(material),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isOpening ? null : _openMaterial,
                                icon: _isOpening
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.open_in_new_rounded),
                                label: Text(_isOpening ? 'Öffnet…' : 'Ansehen / Download'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _toggleBookmark,
                                icon: Icon(_bookmark ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded),
                                label: Text(_bookmark ? 'Gespeichert' : 'Speichern'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          material.description.isEmpty
                              ? 'Keine Beschreibung vorhanden.'
                              : material.description,
                          maxLines: _descriptionExpanded ? null : 4,
                          overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (material.description.isNotEmpty && material.description.length > 180)
                          TextButton(
                            onPressed: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                            child: Text(_descriptionExpanded ? 'Weniger anzeigen' : 'Mehr anzeigen'),
                          ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  String _metaLine(LearningMaterial material) {
    final parts = <String>[
      material.uploaderOrFallback,
      if (material.semester != null && material.semester!.isNotEmpty) material.semester!,
      material.typeLabel,
      '${material.views} Aufrufe',
    ];
    return parts.join(' · ');
  }
}

class _MaterialPdfViewerScreen extends StatelessWidget {
  const _MaterialPdfViewerScreen({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: InAppWebViewSettings(allowsInlineMediaPlayback: true),
        ),
      ),
    );
  }
}
