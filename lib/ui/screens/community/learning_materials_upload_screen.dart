import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterquiz/features/community/providers.dart';
import 'package:flutterquiz/features/profile_management/profile_management_local_data_source.dart';

import 'learning_materials_types.dart';

class LearningMaterialUploadScreen extends ConsumerStatefulWidget {
  const LearningMaterialUploadScreen({super.key, required this.defaultType});

  final LearningMaterialTypeData defaultType;

  @override
  LearningMaterialUploadScreenState createState() => LearningMaterialUploadScreenState();
}

class LearningMaterialUploadScreenState extends ConsumerState<LearningMaterialUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  LearningMaterialTypeData? _selectedType;
  String? _selectedSemester;
  PlatformFile? _selectedFile;

  double? _uploadProgress;
  bool _isPublishing = false;
  String? _fileError;
  String? _submissionError;

  late final CommunityUserContext _userContext = ref.read(communityUserContextProvider);
  late final FirebaseAuth _auth = ref.read(authProvider);
  final ProfileManagementLocalDataSource _local = ProfileManagementLocalDataSource();

  static const List<String> _semesters = <String>[
    'S1',
    'S2',
    'S3',
    'S4',
    'S5',
    'S6',
    'S7',
    'S8',
    'S9',
    'S10',
    'S11',
    'S12',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType;
    if (_userContext.semester.isNotEmpty && _semesters.contains(_userContext.semester)) {
      _selectedSemester = _userContext.semester;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _fileError = null;
    });

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      withReadStream: !kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.first;
      _uploadProgress = null;
    });
  }

  Future<void> _submit() async {
    if (_isPublishing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _fileError = null;
      _submissionError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFile == null) {
      setState(() => _fileError = 'Bitte wähle zuerst eine Datei aus.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _submissionError = 'Bitte melde dich an, um Materialien hochzuladen.');
      return;
    }

    final universityCode = _userContext.universityCode;
    if (universityCode.isEmpty) {
      setState(() => _submissionError = 'Kein Uni-Kontext vorhanden. Prüfe deine Profilangaben.');
      return;
    }

    final type = _selectedType ?? widget.defaultType;
    final title = _titleCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final semester = _selectedSemester;
    final uploaderName = _local.getName().trim().isEmpty ? user.displayName ?? '' : _local.getName().trim();

    setState(() => _isPublishing = true);

    try {
      final fileUrl = await _uploadToStorage(user.uid, _selectedFile!);
      final doc = <String, dynamic>{
        'title': title,
        'description': description,
        'type': type.value,
        'semester': semester,
        'universityCode': universityCode,
        'fileUrl': fileUrl,
        'uploaderId': user.uid,
        'uploaderName': uploaderName,
        'createdAt': FieldValue.serverTimestamp(),
        'views': 0,
      };

      // SECURITY NOTE: Firestore-Regeln müssen sicherstellen, dass nur authentifizierte
      // Nutzer:innen aus der eigenen Uni Materialien erstellen und ihre eigenen
      // Dokumente aktualisieren können (siehe Projektregeln).
      await FirebaseFirestore.instance.collection('materials').add(doc);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (err) {
      setState(() => _submissionError = err.message ?? 'Der Upload ist fehlgeschlagen.');
    } catch (err) {
      setState(() => _submissionError = 'Der Upload ist fehlgeschlagen.(${err.toString()})');
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<String> _uploadToStorage(String uid, PlatformFile file) async {
    final storage = FirebaseStorage.instance;
    final sanitizedName = file.name.replaceAll(RegExp('[\\s]+'), '_');
    final path = 'materials/$uid/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    final ref = storage.ref().child(path);
    final metadata = SettableMetadata(contentType: _contentTypeFor(file.extension));

    final bytes = await _resolveBytes(file);
    final task = ref.putData(bytes, metadata);

    task.snapshotEvents.listen((snapshot) {
      if (!mounted) return;
      final totalBytes = snapshot.totalBytes;
      if (totalBytes <= 0) return;
      setState(() => _uploadProgress = snapshot.bytesTransferred / totalBytes);
    });

    final snapshot = await task.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  Future<Uint8List> _resolveBytes(PlatformFile file) async {
    final existingBytes = file.bytes;
    if (existingBytes != null) {
      return existingBytes;
    }

    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    throw StateError('Die Datei konnte nicht gelesen werden.');
  }

  String? _contentTypeFor(String? extension) {
    final ext = extension?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Material hochladen'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isPublishing ? null : _pickFile,
                      style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                      child: const Text('Hochladen'),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Einstellungen',
                      onPressed: _isPublishing ? null : () {},
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _UploadBox(
                  onTap: _isPublishing ? null : _pickFile,
                  file: _selectedFile,
                  progress: _uploadProgress,
                ),
                if (_fileError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _fileError!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    hintText: 'z. B. M18 Immunologie Skript',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ein Titel ist erforderlich.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _selectedSemester,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Kein Semester')),
                    for (final semester in _semesters)
                      DropdownMenuItem<String?>(
                        value: semester,
                        child: Text(semester),
                      ),
                  ],
                  onChanged: _isPublishing
                      ? null
                      : (value) {
                          setState(() => _selectedSemester = value);
                        },
                  decoration: const InputDecoration(labelText: 'Semester'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LearningMaterialTypeData>(
                  value: _selectedType,
                  items: [
                    for (final type in LearningMaterialTypeData.values)
                      DropdownMenuItem<LearningMaterialTypeData>(
                        value: type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: _isPublishing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                ),
                const SizedBox(height: 32),
                if (_submissionError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _submissionError!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isPublishing ? null : _submit,
                        child: _isPublishing
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Veröffentlichen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isPublishing ? null : () => Navigator.of(context).maybePop(),
                        child: const Text('Abbrechen'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.onTap,
    required this.file,
    required this.progress,
  });

  final VoidCallback? onTap;
  final PlatformFile? file;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.primary.withOpacity(0.4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(value: progress),
              ),
            Icon(Icons.cloud_upload_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              file == null ? 'Datei wählen oder hier ablegen' : file!.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (file != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatSize(file!),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSize(PlatformFile file) {
    final size = file.size;
    if (size <= 0) return '';
    const kb = 1024;
    const mb = kb * 1024;
    if (size < kb) return '$size B';
    if (size < mb) return '${(size / kb).toStringAsFixed(1)} KB';
    return '${(size / mb).toStringAsFixed(1)} MB';
  }
}
