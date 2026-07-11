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
