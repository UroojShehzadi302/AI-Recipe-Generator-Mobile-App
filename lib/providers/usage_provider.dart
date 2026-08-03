// Presentation-layer state for AI credit usage.
//
// [UsageProvider] drives the Credit Usage screen: it loads the user's token-usage
// log through [UsageRepository] and exposes the entries plus a computed
// [UsageSummary] for the UI to bind to.
//
// It does NOT record usage — that happens on the write path, where the AI
// service reports each call's cost straight to the repository (which is the
// [UsageSink]). Keeping the recording out of the provider means an AI call
// costs nothing in rebuilds and works even on screens that never read this.
//
// Like the other providers here: nothing throws to the UI, every repository
// call is guarded, and [notifyListeners] follows each state transition.

import 'package:flutter/foundation.dart';

import '../core/error/failure.dart';
import '../models/usage_entry.dart';
import '../repositories/usage_repository.dart';
import 'recipe_provider.dart' show LoadStatus;

/// Generic fallback shown when an error is not a domain [Failure].
const String _genericError = 'Something went wrong. Please try again.';

/// Holds the user's AI usage log and its aggregate totals.
class UsageProvider extends ChangeNotifier {
  /// Creates a provider backed by [_repository].
  UsageProvider(this._repository);

  final UsageRepository _repository;

  LoadStatus _status = LoadStatus.idle;
  List<UsageEntry> _entries = const <UsageEntry>[];
  UsageSummary _summary = UsageSummary.empty;
  String? _error;

  /// Status of the last [load] call.
  LoadStatus get status => _status;

  /// The user's recorded AI calls, newest first.
  List<UsageEntry> get entries => _entries;

  /// Aggregate totals across [entries].
  UsageSummary get summary => _summary;

  /// User-friendly message for the last failure, or `null`.
  String? get error => _error;

  /// Total tokens consumed — the headline number on the Credit Usage screen
  /// and the Profile stat tile.
  int get totalTokens => _summary.totalTokens;

  /// True once a load has completed and found nothing to show.
  bool get isEmpty => _status == LoadStatus.loaded && _entries.isEmpty;

  /// Loads [uid]'s usage log. Never throws; sets [error] on failure.
  Future<void> load(String uid) async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getUsage(uid);
      _summary = UsageSummary.from(_entries);
      _status = LoadStatus.loaded;
    } on Failure catch (failure) {
      _error = failure.message;
      _status = LoadStatus.error;
    } catch (_) {
      _error = _genericError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Reloads the log (pull-to-refresh / retry).
  Future<void> refresh(String uid) => load(uid);

  /// Clears [uid]'s entire usage log.
  ///
  /// Optimistic: the list empties immediately and is restored if the delete
  /// fails, so the action never feels laggy but also never lies about the
  /// result. Returns `true` on success. Never throws.
  Future<bool> clear(String uid) async {
    final List<UsageEntry> previous = _entries;
    final UsageSummary previousSummary = _summary;

    _entries = const <UsageEntry>[];
    _summary = UsageSummary.empty;
    _status = LoadStatus.loaded;
    notifyListeners();

    try {
      await _repository.clearUsage(uid);
      _error = null;
      notifyListeners();
      return true;
    } on Failure catch (failure) {
      _entries = previous;
      _summary = previousSummary;
      _error = failure.message;
      notifyListeners();
      return false;
    } catch (_) {
      _entries = previous;
      _summary = previousSummary;
      _error = _genericError;
      notifyListeners();
      return false;
    }
  }

  /// Drops all loaded usage state (called on sign-out so the next user never
  /// sees the previous one's numbers).
  void reset() {
    _entries = const <UsageEntry>[];
    _summary = UsageSummary.empty;
    _status = LoadStatus.idle;
    _error = null;
    notifyListeners();
  }
}
