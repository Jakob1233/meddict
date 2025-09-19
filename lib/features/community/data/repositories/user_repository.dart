// COMMUNITY 2.0
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserRepository {
  // COMMUNITY 2.0
  UserRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users');

  Future<AppUser?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  // COMMUNITY 2.0 batched lookup helper
  Stream<Map<String, AppUser>> streamUsersByIds(List<String> ids) async* {
    if (ids.isEmpty) {
      yield <String, AppUser>{};
      return;
    }
    // Firestore does not allow more than 10 in whereIn; batch in chunks of 10
    final chunks = <List<String>>[];
    for (int i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final controllers = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final chunk in chunks) {
      controllers.add(
        _col.where(FieldPath.documentId, whereIn: chunk).snapshots(),
      );
    }

    await for (final combined in StreamZip(controllers)) {
      final map = <String, AppUser>{};
      for (final snap in combined) {
        for (final doc in snap.docs) {
          final u = AppUser.fromDoc(doc);
          map[u.id] = u;
        }
      }
      yield map;
    }
  }
}

// COMMUNITY 2.0: lightweight StreamZip to avoid external deps
class StreamZip<T> extends Stream<List<T>> {
  StreamZip(this._streams);
  final List<Stream<T>> _streams;

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<List<T>>();
    final latest = List<T?>.filled(_streams.length, null);
    final received = List<bool>.filled(_streams.length, false);
    late List<StreamSubscription<T>> subs;

    void emitIfReady() {
      if (received.every((v) => v)) {
        controller.add(latest.cast<T>());
      }
    }

    subs = List.generate(_streams.length, (i) {
      return _streams[i].listen(
        (event) {
          latest[i] = event;
          received[i] = true;
          emitIfReady();
        },
        onError: controller.addError,
        onDone: () {
          // no-op
        },
        cancelOnError: cancelOnError,
      );
    });

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
