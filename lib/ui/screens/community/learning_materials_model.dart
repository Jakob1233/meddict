import 'package:cloud_firestore/cloud_firestore.dart';

import 'learning_materials_types.dart';

class LearningMaterial {
  const LearningMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.universityCode,
    required this.uploaderId,
    required this.uploaderName,
    required this.fileUrl,
    required this.views,
    this.semester,
    this.thumbnailUrl,
    this.downloads,
  });

  factory LearningMaterial.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is DateTime
            ? rawCreatedAt
            : DateTime.now();

    final rawType = (data['type'] as String? ?? '').trim();
    final legacyCategory = (data['category'] as String? ?? '').trim();
    final resolvedType = _normalizeType(rawType.isNotEmpty ? rawType : legacyCategory);

    return LearningMaterial(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      type: resolvedType,
      semester: (data['semester'] as String?)?.trim(),
      universityCode: (data['universityCode'] as String? ?? '').trim(),
      uploaderId: (data['uploaderId'] as String? ?? '').trim(),
      uploaderName: (data['uploaderName'] as String? ?? '').trim(),
      fileUrl: (data['fileUrl'] as String? ?? '').trim(),
      createdAt: createdAt,
      views: _parseInt(data['views']) ?? _parseInt(data['downloads']) ?? 0,
      downloads: _parseInt(data['downloads']),
      thumbnailUrl: (data['thumbnailUrl'] as String?)?.trim(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String type;
  final String? semester;
  final String universityCode;
  final String uploaderId;
  final String uploaderName;
  final String fileUrl;
  final DateTime createdAt;
  final int views;
  final int? downloads;
  final String? thumbnailUrl;

  LearningMaterialTypeData get typeData => LearningMaterialTypeData.byValue(type);
  String get typeLabel => typeData.label;

  String get uploaderOrFallback => uploaderName.isNotEmpty ? uploaderName : 'Unbekannter Uploader';

  String get initials {
    final source = title.isNotEmpty ? title : uploaderOrFallback;
    final parts = source.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }

  LearningMaterial copyWith({
    int? views,
  }) {
    return LearningMaterial(
      id: id,
      title: title,
      description: description,
      type: type,
      createdAt: createdAt,
      universityCode: universityCode,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      fileUrl: fileUrl,
      views: views ?? this.views,
      semester: semester,
      thumbnailUrl: thumbnailUrl,
      downloads: downloads,
    );
  }

  static String _normalizeType(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'skripte':
      case 'skript':
        return 'skripte';
      case 'folien':
      case 'slides':
        return 'folien';
      case 'zusammenfassungen':
      case 'summary':
        return 'zusammenfassungen';
      case 'dokumente':
      case 'documents':
      case 'other':
        return 'dokumente';
      case 'exam':
      case 'altklausuren':
        return 'dokumente';
      default:
        return normalized.isEmpty ? 'dokumente' : normalized;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
