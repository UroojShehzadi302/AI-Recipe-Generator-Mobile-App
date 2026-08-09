// Dependency-free [ShareService]: OS share sheet, clipboard as the safety net.
//
// WHY THERE IS NO `share_plus` HERE
// --------------------------------
// Flutter's own engine already implements a share hook on
// `SystemChannels.platform` — the `Share.invoke` method, which the framework
// calls itself for the "Share" button in text-selection context menus (see
// `EditableText.shareSelection` and `SelectableRegion._share` in the Flutter
// SDK). It is implemented natively on **iOS and Android**, which is exactly
// this app's target, and it costs no new dependency, no Gradle change, and no
// Android manifest entry.
//
// Its limitations: it is not part of Flutter's documented public API, it takes
// plain text only (no files/images), and only Android/iOS implement it. That is
// why [share] checks the platform up front and falls back to the clipboard
// elsewhere — the user still gets the recipe, just through a different door.
//
// ⚠️ The unsupported case does NOT announce itself with an exception.
// `SystemChannels.platform` always has a handler (Clipboard, HapticFeedback,
// SystemSound all ride the same channel), so an unrecognised method name
// returns null and looks exactly like success. Detecting "unsupported" by
// catching [MissingPluginException] would report a phantom share on desktop and
// web. Hence the explicit platform check in `_platformSupportsShareSheet`.
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ TODO(share_plus): UPGRADING TO `share_plus` IS A ONE-LINE CHANGE.        │
// │                                                                          │
// │ If the owner ever wants richer sharing (share the recipe PHOTO, or a     │
// │ share-sheet on desktop/web), add `share_plus` to pubspec.yaml and swap   │
// │ the body of `_invokePlatformShare` below — the ONLY line that touches    │
// │ the platform:                                                            │
// │                                                                          │
// │   FROM: await SystemChannels.platform.invokeMethod('Share.invoke', text);│
// │   TO:   await SharePlus.instance.share(ShareParams(text: text,           │
// │                                                    subject: subject));   │
// │                                                                          │
// │ Nothing else changes anywhere in the app: `ShareService`, the composed   │
// │ text, `RecipeDetailScreen`, and every test all stay exactly as they are, │
// │ because they depend on the interface and not on this file.               │
// └──────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'share_service.dart';

/// A [ShareService] backed by Flutter's built-in `Share.invoke` platform
/// channel, degrading to [Clipboard] where that channel is unavailable.
class PlatformShareService implements ShareService {
  /// Creates a [PlatformShareService].
  const PlatformShareService();

  /// Platforms whose engine implements the `Share.invoke` channel method.
  ///
  /// ⚠️ This is checked UP FRONT rather than by catching an error, because an
  /// unsupported platform does NOT throw: `SystemChannels.platform` always has
  /// a handler (it serves Clipboard, HapticFeedback, SystemSound, …), so an
  /// unrecognised method name simply returns null. Relying on a
  /// [MissingPluginException] therefore reports a phantom success on desktop
  /// and web — the share sheet never opens and the user is told it did.
  static bool get _platformSupportsShareSheet {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<ShareOutcome> share(String text, {String? subject}) async {
    // Nothing to share is a no-op, not an error: an empty payload would open a
    // share sheet containing nothing, which reads as a bug to the user.
    if (text.trim().isEmpty) return ShareOutcome.failed;

    // Desktop/web have no share sheet behind this channel — go straight to the
    // clipboard rather than issuing a call that silently does nothing.
    if (!_platformSupportsShareSheet) return _copyToClipboard(text);

    try {
      await _invokePlatformShare(text, subject);
      return ShareOutcome.shared;
    } on MissingPluginException {
      // Belt-and-braces: a custom embedder on a nominally supported platform
      // may still not implement it.
      return _copyToClipboard(text);
    } catch (error, stack) {
      // Any other platform error (a target that rejected the intent, a
      // transaction that was too large). Still recoverable via the clipboard.
      if (kDebugMode) {
        debugPrint('PlatformShareService: share sheet failed: $error\n$stack');
      }
      return _copyToClipboard(text);
    }
  }

  /// The single line that touches the platform's share mechanism.
  ///
  /// See the `TODO(share_plus)` box at the top of this file — replacing the
  /// body of this method is the entire migration to `share_plus`.
  Future<void> _invokePlatformShare(String text, String? subject) async {
    // `Share.invoke` takes the text directly; it has no subject parameter, so
    // [subject] is accepted at the interface for a future implementation that
    // supports one (share_plus does) and is intentionally unused here.
    await SystemChannels.platform.invokeMethod<void>('Share.invoke', text);
  }

  /// Puts [text] on the clipboard. Returns [ShareOutcome.failed] only if even
  /// this does not work, which would mean the whole services binding is down.
  Future<ShareOutcome> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return ShareOutcome.copiedToClipboard;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PlatformShareService: clipboard fallback failed: $error');
      }
      return ShareOutcome.failed;
    }
  }
}
