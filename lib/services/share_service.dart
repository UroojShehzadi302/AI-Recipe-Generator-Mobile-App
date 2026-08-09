// The seam between the app and the platform's "share" capability.
//
// Mirrors the [AiService] pattern: repositories/providers depend on THIS
// interface, never on a concrete implementation, so the delivery mechanism can
// change without touching anything above it.
//
// Implementations:
// * [PlatformShareService] — dev/prod today: hands the text to the OS share
//                            sheet via Flutter's built-in `Share.invoke`
//                            platform channel, falling back to the clipboard
//                            wherever that channel is unimplemented.
// * (future) a `share_plus`-backed service — see the note in
//   [PlatformShareService] for exactly what changes.
//
// Contract notes:
// * [share] MUST NOT throw. Sharing is a convenience action; a platform that
//   cannot show a share sheet should degrade (copy to clipboard) rather than
//   surface an error to the user.
// * The RESULT tells the caller which path ran, so the UI can word its
//   confirmation honestly ("Shared" vs "Recipe copied to clipboard") instead
//   of guessing.
// * Composing the shared TEXT is NOT this interface's job — that is
//   [RecipeShareText], a pure function with no platform dependency, so the
//   formatting is fully testable and identical across implementations.

/// What actually happened when the app tried to share something.
enum ShareOutcome {
  /// The OS share sheet was invoked successfully.
  shared,

  /// No share sheet was available, so the text was copied to the clipboard
  /// instead. The UI should tell the user this rather than claim a share.
  copiedToClipboard,

  /// Nothing could be done (neither channel worked). The UI should apologise.
  failed,
}

/// Transport-level contract for sharing plain text out of the app.
abstract interface class ShareService {
  /// Shares [text] via the platform's share sheet.
  ///
  /// [subject] is a title used by targets that support one (email subject
  /// lines, for example); platforms without the concept ignore it.
  ///
  /// Never throws — inspect the returned [ShareOutcome] to see which path ran.
  Future<ShareOutcome> share(String text, {String? subject});
}
