// Low-level Cloud Firestore access layer.
//
// [FirestoreService] is a *thin, schema-agnostic* wrapper over
// [FirebaseFirestore]. It exposes a handful of generic document/collection
// helpers that speak only in `Map<String, dynamic>` payloads and string paths.
// It deliberately knows **nothing** about the app's data model — the
// repository layer (e.g. `RecipeRepository`) owns the schema, path conventions,
// serialization, and error mapping. Keeping this class dumb makes it trivially
// reusable across features (recipes, users, chats, ...) and easy to fake in
// tests.
//
// Only `cloud_firestore` is imported here; no model, no Failure types.

import 'package:cloud_firestore/cloud_firestore.dart';

/// A generic, low-level wrapper around [FirebaseFirestore].
///
/// All methods take a slash-delimited Firestore [path]. Document helpers expect
/// an **even** number of path segments (`users/{uid}`); collection helpers
/// expect an **odd** number (`users/{uid}/favorites`).
class FirestoreService {
  /// Creates a service bound to [firestore], defaulting to
  /// [FirebaseFirestore.instance]. Injecting an instance keeps the class
  /// testable with a fake/emulator.
  FirestoreService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  /// Reads a single document at [path].
  ///
  /// Returns the document's data, or `null` when the document does not exist.
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _db.doc(path).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  /// Reads every document in the collection at [path].
  ///
  /// An optional [query] callback can refine the [CollectionReference]
  /// (ordering, `where`, `limit`, ...) before the read. Returns the list of raw
  /// document data maps (order follows the resolved query).
  Future<List<Map<String, dynamic>>> getCollection(
    String path, {
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>> collection,
    )? query,
  }) async {
    final CollectionReference<Map<String, dynamic>> collection =
        _db.collection(path);
    final Query<Map<String, dynamic>> resolved =
        query == null ? collection : query(collection);
    final QuerySnapshot<Map<String, dynamic>> snap = await resolved.get();
    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data())
        .toList(growable: false);
  }

  /// Writes [data] to the document at [path].
  ///
  /// When [merge] is `true` (the default) existing fields are preserved and
  /// only the provided keys are updated; when `false` the document is fully
  /// overwritten.
  Future<void> setDoc(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    return _db.doc(path).set(data, SetOptions(merge: merge));
  }

  /// Deletes the document at [path]. A no-op if it does not exist.
  Future<void> deleteDoc(String path) {
    return _db.doc(path).delete();
  }

  /// Streams the collection at [path], emitting the raw document data maps on
  /// every change. The stream honors Firestore's offline cache.
  Stream<List<Map<String, dynamic>>> watchCollection(String path) {
    return _db.collection(path).snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data(),
              )
              .toList(growable: false),
        );
  }
}
