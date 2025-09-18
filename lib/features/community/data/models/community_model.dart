// COMMUNITY INTEGRATION
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  CommunityModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.members = const [],
    this.moderators = const [],
  });

  final String id;
  final String name;
  final String createdBy;
  final Timestamp createdAt;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final List<String> members;
  final List<String> moderators;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'description': description,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'members': members,
      'moderators': moderators,
    };
  }

  factory CommunityModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CommunityModel(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      createdBy: (d['createdBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?) ?? Timestamp.now(),
      description: d['description'] as String?,
      avatarUrl: d['avatarUrl'] as String?,
      bannerUrl: d['bannerUrl'] as String?,
      members: (d['members'] as List?)?.cast<String>() ?? const [],
      moderators: (d['moderators'] as List?)?.cast<String>() ?? const [],
    );
  }
}

