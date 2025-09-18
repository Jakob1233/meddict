// COMMUNITY INTEGRATION
// Centralized Riverpod providers for Community feature.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutterquiz/core/constants/constants.dart';

import 'data/models/community_model.dart';
// COMMUNITY 2.0
import 'data/models/app_user.dart';
import 'data/models/room_model.dart';
import 'data/models/uni_event.dart';
import 'data/models/post_model.dart';
import 'data/models/comment_model.dart';
import 'data/repositories/community_repository.dart';
import 'data/repositories/post_repository.dart';
import 'package:flutterquiz/data/repositories/exams_repository.dart';
import 'package:flutterquiz/models/exam.dart';
import 'package:flutterquiz/models/exam_note.dart';
import 'package:flutterquiz/models/exam_rating.dart';
import 'application/paged_posts_controller.dart';
// COMMUNITY 2.0
import 'data/repositories/user_repository.dart';
import 'data/repositories/room_repository.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/comment_repository.dart';
import 'package:flutterquiz/features/onboarding/data/onboarding_repository.dart';
import 'package:flutterquiz/features/profile_management/profile_management_local_data_source.dart';

class CommunityUserContext {
  CommunityUserContext({
    required this.semester,
    required this.universityName,
    required this.universityCode,
  });

  final String semester;
  final String universityName;
  final String universityCode;

  bool get hasSemester => semester.isNotEmpty;
  bool get hasUniversity => universityCode.isNotEmpty && universityName.isNotEmpty;
}

class TopPostsArgs {
  const TopPostsArgs({
    this.category,
    this.window = const Duration(days: 30),
    this.limit = 10,
  });

  final String? category;
  final Duration window;
  final int limit;
}

// Firebase instances (reuse existing Firebase initialization from the app)
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Repositories
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.read(firestoreProvider));
});

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(
    ref.read(firestoreProvider),
    ref.read(storageProvider),
  );
});

final examsRepositoryProvider = Provider<ExamsRepository>((ref) {
  return ExamsRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(authProvider),
  );
});

// COMMUNITY 2.0
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(firestoreProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.read(firestoreProvider));
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.read(firestoreProvider), ref.read(storageProvider));
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(ref.read(firestoreProvider));
});

// Auth user id
// Make auth state reactive so dependent UI (e.g., post buttons) updates
// when the user logs in/out. We expose a StreamProvider for Firebase
// auth state changes, then derive a simple `String?` userId provider
// from it to keep the existing API unchanged.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.read(authProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.maybeWhen(
    data: (user) => user?.uid,
    orElse: () => ref.read(authProvider).currentUser?.uid,
  );
});

// Feed: latest posts (optionally filtered by joined communities later)
final communityFeedProvider = StreamProvider<List<PostModel>>((ref) {
  final repo = ref.read(postRepositoryProvider);
  return repo.feedStream(limit: 50);
});

// COMMUNITY 2.0 alias
final medThreadProvider = StreamProvider<List<PostModel>>((ref) {
  final repo = ref.read(postRepositoryProvider);
  return repo.streamMedThreadLatest(limit: 50);
});

// Posts by community
final communityPostsProvider = StreamProvider.family<List<PostModel>, String>((ref, communityId) {
  final repo = ref.read(postRepositoryProvider);
  return repo.postsByCommunityStream(communityId: communityId, limit: 50);
});

// Single Post
final postProvider = StreamProvider.family<PostModel?, String>((ref, postId) {
  final repo = ref.read(postRepositoryProvider);
  return repo.postStream(postId);
});

// Comments for a post
final commentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  final repo = ref.read(commentRepositoryProvider);
  return repo.commentsStream(postId: postId);
});

// COMMUNITY 2.0 Rooms
final roomsProvider = StreamProvider<List<Room>>((ref) {
  return ref.read(roomRepositoryProvider).streamRooms();
});

// COMMUNITY 3.0: single room stream
final roomProvider = StreamProvider.family<Room?, String>((ref, id) {
  final fs = ref.read(firestoreProvider);
  return fs.collection('rooms').doc(id).snapshots().map((d) => d.exists ? Room.fromDoc(d) : null);
});

// COMMUNITY 2.0 Events
final eventsUpcomingProvider = StreamProvider<List<UniEvent>>((ref) {
  return ref.read(eventRepositoryProvider).streamUpcoming();
});

final eventsPastProvider = StreamProvider<List<UniEvent>>((ref) {
  return ref.read(eventRepositoryProvider).streamPast();
});

// COMMUNITY UI: selected room shared state
final selectedRoomIdProvider = StateProvider<String?>((ref) => null);

// COMMUNITY UI: posts feed for selected room
final roomFeedProvider = StreamProvider.family<List<PostModel>, String>((ref, roomId) {
  return ref.read(postRepositoryProvider).streamRoomPosts(roomId);
});

// COMMUNITY 3.0: create event provider
final createEventProvider = FutureProvider.family<String, ({
  String title,
  String? description,
  DateTime startAt,
  DateTime? endAt,
  String? location,
  String createdBy,
  dynamic imageFile, // XFile (kept dynamic to avoid import here)
})>((ref, args) async {
  return ref.read(eventRepositoryProvider).createEvent(
        title: args.title,
        description: args.description,
        startAt: args.startAt,
        endAt: args.endAt,
        location: args.location,
        createdBy: args.createdBy,
        imageFile: args.imageFile,
      );
});

// COMMUNITY 3.0: create room provider
final createRoomProvider = FutureProvider.family<String, ({
  String name,
  String? description,
  String createdBy,
  String imageAsset,
  String semester,
  String topic,
})>((ref, args) async {
  return ref.read(roomRepositoryProvider).createRoom(
        name: args.name,
        description: args.description,
        createdBy: args.createdBy,
        imageAsset: args.imageAsset,
        semester: args.semester,
        topic: args.topic,
      );
});

// COMMUNITY 3.0: create room post provider
final createRoomPostProvider = FutureProvider.family<void, ({
  String roomId,
  String createdBy,
  String body,
  String? title,
  List<String>? tags,
})>((ref, args) async {
  await ref.read(postRepositoryProvider).createRoomPost(
        roomId: args.roomId,
        createdBy: args.createdBy,
        body: args.body,
        title: args.title,
        tags: args.tags,
      );
});

final _userDetailsWatchProvider =
    StreamProvider.autoDispose<void>((ref) {
  final box = Hive.box<dynamic>(userDetailsBox);
  return box.watch().map((event) => null);
});

final communityUserContextProvider = Provider<CommunityUserContext>((ref) {
  ref.watch(_userDetailsWatchProvider);
  final local = ProfileManagementLocalDataSource();
  final semester = FirstLoginOnboardingController.normalizeSemester(local.getSemester());
  final universityName = local.getUniversityName();
  final universityCode = local.getUniversityCode();
  return CommunityUserContext(
    semester: semester,
    universityName: universityName,
    universityCode: universityCode,
  );
});

class ExamsQueryArgs {
  const ExamsQueryArgs({
    required this.uniCode,
    required this.semester,
    this.limit,
    this.sort = 'relevant',
    this.searchTerm = '',
  });

  final String uniCode;
  final String semester;
  final int? limit;
  final String sort;
  final String searchTerm;

  @override
  int get hashCode => Object.hash(uniCode, semester, limit, sort, searchTerm);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExamsQueryArgs &&
        other.uniCode == uniCode &&
        other.semester == semester &&
        other.limit == limit &&
        other.sort == sort &&
        other.searchTerm == searchTerm;
  }
}

final examsListProvider = FutureProvider.autoDispose.family<List<Exam>, ExamsQueryArgs>((ref, args) async {
  final ordering = args.sort.toLowerCase() == 'relevant'
      ? ExamsListOrdering.compositeScore
      : ExamsListOrdering.createdAt;
  final page = await ref.read(examsRepositoryProvider).fetchExamsPage(
        universityCode: args.uniCode,
        semesterFilter: args.semester,
        ordering: ordering,
        limit: args.limit ?? 20,
      );
  return page.exams;
});

final examProvider = StreamProvider.autoDispose.family<Exam?, String>((ref, examId) {
  return ref.read(examsRepositoryProvider).watchExam(examId);
});

class ExamNotesArgs {
  const ExamNotesArgs({required this.examId, required this.type});

  final String examId;
  final ExamNoteType type;

  @override
  int get hashCode => Object.hash(examId, type);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExamNotesArgs && other.examId == examId && other.type == type;
  }
}

final examNotesProvider =
    StreamProvider.autoDispose.family<List<ExamNote>, ExamNotesArgs>((ref, args) {
  return ref.read(examsRepositoryProvider).watchNotes(args.examId, args.type);
});

final examUserRatingProvider =
    StreamProvider.autoDispose.family<ExamRating?, String>((ref, examId) {
  return ref.read(examsRepositoryProvider).watchUserRating(examId);
});

final pagedPostsProvider = StateNotifierProvider.autoDispose.family<
    PagedPostsNotifier,
    PagedPostsState,
    PagedPostsArgs>((ref, args) {
  final notifier = PagedPostsNotifier(
    repo: ref.read(postRepositoryProvider),
    args: args,
  );
  notifier.loadInitial();
  return notifier;
});

final topPostsProvider =
    StreamProvider.autoDispose.family<List<PostModel>, TopPostsArgs>((ref, args) {
  return ref
      .read(postRepositoryProvider)
      .topPostsStream(window: args.window, limit: args.limit, category: args.category, type: 'question');
});

// COMMUNITY 3.0 — Firestore Indexes & Rules (deploy separately)
// Indexes (firestore.indexes.json)
// {
//   "indexes": [
//     { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
//       { "fieldPath": "roomId", "order": "ASCENDING" },
//       { "fieldPath": "createdAt", "order": "DESCENDING" }
//     ]},
//     { "collectionGroup": "comments", "queryScope": "COLLECTION", "fields": [
//       { "fieldPath": "postId", "order": "ASCENDING" },
//       { "fieldPath": "createdAt", "order": "DESCENDING" }
//     ]},
//     { "collectionGroup": "events", "queryScope": "COLLECTION", "fields": [
//       { "fieldPath": "startAt", "order": "ASCENDING" }
//     ]}
//   ],
//   "fieldOverrides": []
// }
// Deploy: firebase deploy --only firestore:indexes
//
// Firestore Rules (short pragmatic)
// rules_version = '2';
// service cloud.firestore {
//   match /databases/{db}/documents {
//     function authed() { return request.auth != null; }
//     match /rooms/{id}    { allow read: if true; allow create, update: if authed(); }
//     match /events/{id}   { allow read: if true; allow create, update: if authed(); }
//     match /posts/{id}    { allow read: if true; allow create, update: if authed(); }
//     match /comments/{id} { allow read: if true; allow create, update: if authed(); }
//     match /{path=**}/posts/{id}    { allow read: if true; allow create, update: if authed(); }
//     match /{path=**}/comments/{id} { allow read: if true; allow create, update: if authed(); }
//     match /{path=**}/events/{id}   { allow read: if true; allow create, update: if authed(); }
//   }
// }
//
// Storage Rules (events covers)
// rules_version = '2';
// service firebase.storage {
//   match /b/{bucket}/o {
//     function authed() { return request.auth != null; }
//     match /events/{eventId}/{allPaths=**} {
//       allow read: if true;
//       allow write: if authed();
//     }
//   }
// }

// COMMUNITY 2.0 User cache
class UserCacheNotifier extends StateNotifier<Map<String, AppUser>> {
  UserCacheNotifier(this._repo) : super(<String, AppUser>{});
  final UserRepository _repo;

  Future<void> ensure(String userId) async {
    if (userId.isEmpty || state.containsKey(userId)) return;
    final user = await _repo.getUser(userId);
    if (user != null) {
      state = {...state, user.id: user};
    }
  }
}

final userCacheProvider =
    StateNotifierProvider<UserCacheNotifier, Map<String, AppUser>>((ref) {
  return UserCacheNotifier(ref.read(userRepositoryProvider));
});

// Create Post
final createPostProvider = FutureProvider.family<String, ({
  String title,
  String body,
  List<String> tags,
  String type,
  String? communityId,
  File? imageFile,
})>((ref, args) async {
  final repo = ref.read(postRepositoryProvider);
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) throw StateError('User not logged in');
  final post = PostModel(
    id: '',
    type: args.type,
    title: args.title,
    body: args.body,
    tags: args.tags,
    createdBy: userId,
    communityId: args.communityId,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    upvotes: 0,
    answersCount: 0,
    imageUrl: null,
    upvoters: const [],
    downvoters: const [],
  );
  final postId = await repo.createPost(post, imageFile: args.imageFile);
  return postId;
});
