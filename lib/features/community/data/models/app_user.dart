// COMMUNITY 2.0
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // COMMUNITY 2.0
  const AppUser({
    required this.id,
    required this.displayName,
    this.photoURL,
  });

  final String id;
  final String displayName; // COMMUNITY 2.0
  final String? photoURL; // COMMUNITY 2.0

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final email = (d['email'] as String?) ?? '';
    final dn = (d['displayName'] as String?) ??
        (email.isNotEmpty ? email.split('@').first : 'User');
    return AppUser(
      id: doc.id,
      displayName: dn,
      photoURL: d['photoURL'] as String?,
    );
  }
}

