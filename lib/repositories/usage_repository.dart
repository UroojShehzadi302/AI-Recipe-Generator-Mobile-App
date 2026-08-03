// Credit-usage data-access repository.
//
// [UsageRepository] owns the `users/{uid}/usage` schema: it persists one
// document per successful AI call (token counts + which feature spent them) and
// reads them back for the Credit Usage screen. Like every other repository here
// it sits over the generic [FirestoreService] and translates failures into a
// [FirestoreFailure] carrying a user-safe message.
//
// It also IS the [UsageSink] handed to the AI service, which is what closes the
// loop: the service reports a call's cost, this repository attributes it to the
// signed-in user and writes it. The sink half is deliberately fire-and-forget —
// see [record].

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/usage_entry.dart';
import '../services/firestore_service.dart';
import '../services/usage_sink.dart';

/// Reads and writes the user's AI token-usage log.
class UsageRepository implements UsageSink {
  /// Creates a repository backed by [_firestore].
  ///
  /// [currentUid] resolves the signed-in user at the moment a call is recorded.
  /// It is a callback rather than a stored value on purpose: the AI service
  /// reports usage without knowing who is signed in, and reading the uid lazily
  /// means no auth transition (sign-in, sign-out, token refresh) can leave this
  /// repository pointed at a stale user. Returning `null` means "signed out —
  /// nowhere to attribute this", and the record is dropped.
  UsageRepository(this._firestore, {this._currentUid});

  final FirestoreService _firestore;
  final String? Function()? _currentUid;

  /// The private usage subcollection for [uid].
  static String _usagePath(String uid) => 'users/$uid/usage';

  // ---------------------------------------------------------------------------
  // Diagnostics.
  //
  // The write path is fire-and-forget and swallows every error by design, which
  // makes a failure indistinguishable from "the feature does nothing". These
  // breadcrumbs record what actually happened on the last few calls so the
  // Credit Usage screen can show it instead of failing silently.
  //
  // Debug-only and capped; remove once the write path is confirmed working.
  // ---------------------------------------------------------------------------

  /// The most recent write-path events, oldest first (capped at [_maxTrace]).
  static final List<String> trace = <String>[];

  static const int _maxTrace = 12;

  /// Appends [message] to [trace] from outside this class (used by the AI
  /// service via the `usageTrace` hook).
  static void note(String message) => _note(message);

  /// Appends [message] to [trace], also mirroring it to the debug console.
  static void _note(String message) {
    if (!kDebugMode) return;
    debugPrint('[usage] $message');
    trace.add(message);
    if (trace.length > _maxTrace) trace.removeAt(0);
  }

  /// Resolves the uid to attribute a recording to, or `null` when signed out.
  String? _resolveUid() {
    try {
      final String? uid = _currentUid?.call();
      return (uid != null && uid.trim().isNotEmpty) ? uid.trim() : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // UsageSink — the write path used by the AI service.
  // ---------------------------------------------------------------------------

  /// Records one AI call's token cost for the current user.
  ///
  /// Fire-and-forget by design: the caller is an AI service that has already
  /// produced a good reply, and a failed bookkeeping write must not turn that
  /// into an error the user sees. The future is intentionally not awaited and
  /// all errors are swallowed. Calls with no signed-in user, and calls that
  /// consumed no tokens, are dropped rather than written.
  @override
  void record({
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  }) {
    final String? uid = _resolveUid();
    if (uid == null) {
      _note('DROPPED ${kind.name}: no signed-in uid');
      return;
    }
    if (promptTokens <= 0 && outputTokens <= 0) {
      _note('DROPPED ${kind.name}: Gemini reported 0 tokens');
      return;
    }

    _note('recording ${kind.name}: in=$promptTokens out=$outputTokens');

    // Not awaited on purpose — see the doc comment above.
    unawaited(
      _write(
        uid: uid,
        kind: kind,
        promptTokens: promptTokens,
        outputTokens: outputTokens,
        model: model,
      ),
    );
  }

  /// Performs the actual usage write. Never throws.
  Future<void> _write({
    required String uid,
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  }) async {
    try {
      final DateTime now = DateTime.now();
      // Client-generated id: timestamp + kind. Unique enough in practice (two
      // AI calls of the same kind cannot complete in the same millisecond) and
      // it avoids a server round-trip just to learn the document id.
      final String id = 'u${now.millisecondsSinceEpoch}-${kind.name}';

      final UsageEntry entry = UsageEntry(
        id: id,
        kind: kind,
        promptTokens: promptTokens,
        outputTokens: outputTokens,
        createdAt: now,
        model: model,
      );

      await _firestore.setDoc(
        '${_usagePath(uid)}/$id',
        <String, dynamic>{
          ...entry.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
      _note('WROTE ok -> ${_usagePath(uid)}/$id');
    } catch (e) {
      // Bookkeeping is best-effort; never surface this to the user. It is
      // still traced, because a silent write failure here is exactly the kind
      // of thing that looks like "the feature does nothing".
      _note('WRITE FAILED -> ${_usagePath(uid)}: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read path — backs the Credit Usage screen.
  // ---------------------------------------------------------------------------

  /// Reads [uid]'s usage log, newest first.
  ///
  /// Sorted client-side rather than via `orderBy` so the read needs no
  /// composite index and still includes documents whose server timestamp has
  /// not resolved yet (which would otherwise sort as missing).
  Future<List<UsageEntry>> getUsage(String uid) async {
    try {
      final List<Map<String, dynamic>> docs =
          await _firestore.getCollection(_usagePath(uid));

      final List<UsageEntry> entries = <UsageEntry>[];
      for (final Map<String, dynamic> doc in docs) {
        final UsageEntry? entry = UsageEntry.fromMap(doc);
        if (entry != null) entries.add(entry);
      }
      entries.sort(
        (UsageEntry a, UsageEntry b) => b.createdAt.compareTo(a.createdAt),
      );
      _note(
        'READ ${_usagePath(uid)}: ${docs.length} docs -> ${entries.length} entries',
      );
      return entries;
    } on Failure {
      rethrow;
    } catch (e) {
      _note('READ FAILED -> ${_usagePath(uid)}: $e');
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Deletes [uid]'s entire usage log (the "Clear usage log" action).
  ///
  /// Firestore has no client-side recursive delete, so documents are removed
  /// one by one — the same approach [UserRepository.deleteUserData] takes.
  Future<void> clearUsage(String uid) async {
    try {
      final List<Map<String, dynamic>> docs =
          await _firestore.getCollection(_usagePath(uid));

      for (final Map<String, dynamic> doc in docs) {
        final Object? rawId = doc['usageId'] ?? doc['id'];
        if (rawId is String && rawId.trim().isNotEmpty) {
          await _firestore.deleteDoc('${_usagePath(uid)}/${rawId.trim()}');
        }
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }
}
