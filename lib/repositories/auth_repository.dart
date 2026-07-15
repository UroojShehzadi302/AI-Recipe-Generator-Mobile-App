// Orchestrates authentication + user-profile persistence for the AUTH slice.
//
// Sits between the dumb [AuthService] (FirebaseAuth pass-through) and the
// [UserRepository] (Firestore `/users`). This is the layer that turns raw
// Firebase exceptions into domain [Failure]s and guarantees a [UserModel]
// exists for every authenticated account.

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'user_repository.dart';

/// Coordinates sign-in/registration with user-profile storage.
///
/// All methods surface errors as thrown [Failure] values:
/// [AuthFailure] for mapped [FirebaseAuthException]s and [UnknownFailure]
/// for anything unexpected.
class AuthRepository {
  final AuthService _authService;
  final UserRepository _userRepository;

  /// Creates an [AuthRepository] with its collaborators injected.
  AuthRepository({
    required AuthService authService,
    required UserRepository userRepository,
  })  : _authService = authService,
        _userRepository = userRepository;

  /// Streams the raw FirebaseAuth [User] (or `null` when signed out).
  Stream<User?> get authState => _authService.authStateChanges();

  /// Whether a signed-in session already exists (used by the app-launch gate).
  ///
  /// Resolves immediately with the current auth state without forcing the UI to
  /// depend on FirebaseAuth types.
  Future<bool> hasActiveSession() async =>
      (await _authService.authStateChanges().first) != null;

  /// The current signed-in user's uid, or null when signed out. Used by
  /// features that scope data per user (favorites, saved, chat history).
  String? get currentUid => _authService.currentUser?.uid;

  /// Loads the [UserModel] for the currently signed-in user (or null if none).
  ///
  /// Prefers the Firestore profile; falls back to an auth-only model if
  /// Firestore is unreachable/locked, so it never throws for the UI.
  Future<UserModel?> loadCurrentUser() async {
    final User? user = _authService.currentUser;
    if (user == null) return null;
    try {
      final UserModel? existing = await _userRepository.getUser(user.uid);
      if (existing != null) return existing;
    } catch (_) {
      // Fall through to the auth-only model.
    }
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      provider: 'password',
      emailVerified: user.emailVerified,
    );
  }

  /// Signs in with email/password and resolves the user's [UserModel].
  ///
  /// Fetches the profile from Firestore; if none exists yet (e.g. legacy or
  /// externally-created account) a minimal profile is built from the
  /// FirebaseAuth user and upserted. Throws [AuthFailure] on auth errors and
  /// [UnknownFailure] on anything else.
  Future<UserModel> signIn(String email, String password) async {
    try {
      final UserCredential credential =
          await _authService.signInWithEmail(email, password);
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure();
      }
      return _ensureUserProfile(user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authFailureMessage(e));
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Registers a new email/password account and persists its [UserModel].
  ///
  /// Sets the FirebaseAuth display name, sends a verification email, and
  /// writes a `provider: 'password'` profile document. Throws [AuthFailure]
  /// on auth errors and [UnknownFailure] otherwise.
  Future<UserModel> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final UserCredential credential =
          await _authService.registerWithEmail(email, password);
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure();
      }

      final UserModel model = UserModel(
        uid: user.uid,
        name: name,
        email: user.email ?? email,
        photoUrl: user.photoURL,
        provider: 'password',
        emailVerified: user.emailVerified,
      );

      // The account now exists — registration has succeeded. Display-name,
      // verification email, and the Firestore profile document are all
      // best-effort: a failure here (e.g. locked Firestore rules) must not
      // report the whole registration as failed, since the user is already
      // signed in.
      try {
        await user.updateDisplayName(name);
        await _authService.sendEmailVerification();
        await _userRepository.upsertUser(model);
      } catch (_) {
        // Non-fatal: profile enrichment can be retried later.
      }

      return model;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authFailureMessage(e));
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Sends a password-reset email, mapping errors to [Failure]s.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authFailureMessage(e));
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Updates the signed-in user's display [name] and, when [avatarFile] is
  /// given, stores it as their avatar.
  ///
  /// The avatar is saved as a compressed **base64 `data:` URI inside the
  /// Firestore user document** (free — no Cloud Storage / Blaze plan needed),
  /// not uploaded to Cloud Storage. Persists the name to FirebaseAuth
  /// (displayName) and the `/users/{uid}` document, returning the refreshed
  /// [UserModel]. Throws [AuthFailure] when signed out, [StorageFailure] when
  /// the image can't be read or is too large, and [UnknownFailure] otherwise.
  Future<UserModel> updateProfile({
    required String name,
    File? avatarFile,
  }) async {
    final User? user = _authService.currentUser;
    if (user == null) {
      throw const AuthFailure('You are signed out. Please sign in again.');
    }

    final String trimmedName = name.trim();

    try {
      final String? photoUrl =
          avatarFile == null ? null : await _encodeAvatar(avatarFile);

      // Only the name goes to FirebaseAuth — a base64 data: URI would exceed
      // the photoURL length limit, so the avatar lives in Firestore only (the
      // app reads the profile from Firestore, so it still shows everywhere).
      await user.updateDisplayName(trimmedName);

      // Merge into the existing profile so server-maintained fields are kept.
      final UserModel current = await _userRepository.getUser(user.uid) ??
          UserModel(
            uid: user.uid,
            email: user.email ?? '',
            provider: user.providerData
                    .any((info) => info.providerId == 'google.com')
                ? 'google'
                : 'password',
            emailVerified: user.emailVerified,
          );
      final UserModel updated = current.copyWith(
        uid: user.uid,
        name: trimmedName,
        photoUrl: photoUrl ?? current.photoUrl,
      );
      await _userRepository.upsertUser(updated);
      return updated;
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Reads [file] and returns a `data:image/jpeg;base64,...` URI for storing in
  /// Firestore. Rejects images that would blow past Firestore's ~1 MB document
  /// limit once base64-encoded (the picker already downscales, so this is a
  /// safety net). Throws [StorageFailure] on read errors / oversize.
  Future<String> _encodeAvatar(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      // base64 inflates ~33%; cap raw bytes so the encoded string + the rest of
      // the user doc stay under Firestore's 1 MB per-document limit.
      if (bytes.length > 700 * 1024) {
        throw const StorageFailure(
          'That photo is too large. Please choose a smaller image.',
        );
      }
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } on Failure {
      rethrow;
    } catch (_) {
      throw const StorageFailure();
    }
  }

  /// Runs Google sign-in and resolves the user's [UserModel].
  ///
  /// Returns `null` when the user **cancels** or the flow is interrupted (so
  /// the UI can quietly return to its prior state instead of showing an error).
  /// Throws [AuthFailure] for a misconfigured provider or a rejected Firebase
  /// credential, and [UnknownFailure] for anything else.
  Future<UserModel?> signInWithGoogle() async {
    try {
      final UserCredential credential =
          await _authService.signInWithGoogle();
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure();
      }
      return _ensureUserProfile(user, provider: 'google');
    } on GoogleSignInException catch (e) {
      // A user-driven dismissal is not an error — signal it with null.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AuthFailure(_googleFailureMessage(e));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authFailureMessage(e));
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Maps a [FirebaseAuthException] to a friendly message, special-casing the
  /// `CONFIGURATION_NOT_FOUND` internal error (raw `code == 'unknown'`) that
  /// Firebase returns when Email/Password sign-in is not enabled for the
  /// project.
  String _authFailureMessage(FirebaseAuthException e) {
    final String message = e.message ?? '';
    if (e.code == 'unknown' && message.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Email/Password sign-in is not enabled for this Firebase project. '
          'Enable it in the console: Authentication → Sign-in method.';
    }
    return ErrorMapper.authMessage(e.code);
  }

  /// Maps a non-cancellation [GoogleSignInException] to a friendly message.
  String _googleFailureMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured for this app yet. '
            'Enable the Google provider and add the SHA-1 in the Firebase '
            'console.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in is unavailable right now. Please try again.';
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }

  /// Returns the stored [UserModel] for [user], creating a minimal one if the
  /// Firestore document is missing. [provider] records how the account signed
  /// in (`'password'` or `'google'`).
  Future<UserModel> _ensureUserProfile(
    User user, {
    String provider = 'password',
  }) async {
    // Build a model straight from the auth account first, so sign-in never
    // fails just because Firestore is unreachable or locked down.
    final UserModel fallback = UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      provider: provider,
      emailVerified: user.emailVerified,
    );

    try {
      final UserModel? existing = await _userRepository.getUser(user.uid);
      if (existing != null) {
        return existing;
      }
      await _userRepository.upsertUser(fallback);
    } catch (_) {
      // Firestore read/write failed (e.g. rules) — proceed with the auth-only
      // profile; it can be persisted later once rules allow it.
    }
    return fallback;
  }
}
