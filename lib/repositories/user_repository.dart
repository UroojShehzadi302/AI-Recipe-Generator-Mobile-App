// Data access for the `/users/{uid}` Firestore collection.
//
// Wraps `FirebaseFirestore.instance.collection('users')` and translates
// between raw document maps and [UserModel]. Parsing is delegated to the
// tolerant [UserModel.fromJson] factory, so malformed or partial documents
// never throw here.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Reads and writes user profile documents in Cloud Firestore.
class UserRepository {
  final FirebaseFirestore? _injected;

  /// Creates a [UserRepository].
  ///
  /// [firestore] is injectable for testing; the default
  /// `FirebaseFirestore.instance` resolves lazily on first use so construction
  /// never requires Firebase to be initialized.
  UserRepository({FirebaseFirestore? firestore}) : _injected = firestore;

  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  /// The `users` collection reference.
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Fetches the user document for [uid].
  ///
  /// Returns `null` if the document does not exist. [UserModel.fromJson] is
  /// tolerant of missing/extra fields (e.g. Firestore `Timestamp`s such as
  /// `createdAt`/`updatedAt`), so no manual conversion is needed here.
  Future<UserModel?> getUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _users.doc(uid).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return UserModel.fromJson(data);
  }

  /// Creates or updates the user document, merging with any existing data.
  ///
  /// Uses `set(..., merge: true)` so partial writes never clobber
  /// server-maintained counters or timestamp fields.
  Future<void> upsertUser(UserModel user) {
    return _users.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  /// Subcollections owned by a user document, deleted alongside the profile.
  ///
  /// `chats` is handled separately because its documents own a nested
  /// `messages` subcollection.
  static const List<String> _flatSubcollections = <String>[
    'favorites',
    'generatedRecipes',
    'usage',
  ];

  /// Permanently deletes [uid]'s profile document and everything beneath it.
  ///
  /// Firestore has no client-side recursive delete: deleting a document leaves
  /// its subcollections orphaned but still stored (and still billable, still
  /// readable by a rules-permitted query). So this walks the tree explicitly —
  /// favorites, generated recipes, every chat's messages, the chats themselves,
  /// and finally the profile doc.
  ///
  /// Ordering matters: the profile document goes LAST, so a failure partway
  /// through leaves the account still owning its data rather than stranding
  /// unreachable orphans.
  Future<void> deleteUserData(String uid) async {
    final DocumentReference<Map<String, dynamic>> userDoc = _users.doc(uid);

    for (final String name in _flatSubcollections) {
      await _deleteCollection(userDoc.collection(name));
    }

    // Chats nest one level deeper: drain each chat's messages before the chat.
    final QuerySnapshot<Map<String, dynamic>> chats =
        await userDoc.collection('chats').get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> chat in chats.docs) {
      await _deleteCollection(chat.reference.collection('messages'));
    }
    await _deleteCollection(userDoc.collection('chats'));

    await userDoc.delete();
  }

  /// Batch-deletes every document in [collection], paging until it is empty.
  ///
  /// A single batch is capped at 500 writes, so this pages at 300 to stay well
  /// clear of the limit even if the collection grows between reads.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection, {
    int batchSize = 300,
  }) async {
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await collection.limit(batchSize).get();
      if (snap.docs.isEmpty) return;

      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      // A short page means the collection is drained.
      if (snap.docs.length < batchSize) return;
    }
  }

  /// Streams the user document for [uid].
  ///
  /// Emits `null` while the document is missing, then a [UserModel] once it
  /// exists (and again on every change).
  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return UserModel.fromJson(data);
    });
  }
}
