// Thin Firebase Storage seam for user-uploaded files (currently avatars only).
//
// Follows the same pattern as the other services: FirebaseStorage is resolved
// LAZILY via a getter (not in the constructor) so the object is constructible
// in unit tests without Firebase being initialized. The repository layer owns
// the storage *paths* and error mapping; this service only performs the upload
// and returns a download URL.

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads binary assets to Cloud Storage and returns their download URLs.
class StorageService {
  /// Creates a [StorageService].
  ///
  /// [storage] is injectable for tests; the default resolves lazily on first
  /// use so construction never requires Firebase.
  StorageService({FirebaseStorage? storage}) : _injected = storage;

  final FirebaseStorage? _injected;

  FirebaseStorage get _storage => _injected ?? FirebaseStorage.instance;

  /// Uploads [file] as the avatar for [uid] to `avatars/{uid}.jpg` and returns
  /// its public download URL. Overwrites any previous avatar for that user.
  Future<String> uploadAvatar(String uid, File file) async {
    final Reference ref = _storage.ref().child('avatars/$uid.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }
}
