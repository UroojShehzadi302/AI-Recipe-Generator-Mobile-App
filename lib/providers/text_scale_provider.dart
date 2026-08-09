import 'package:flutter/material.dart';

import '../services/settings_store.dart';

/// The three text sizes offered in Settings → Preferences → Text Size.
///
/// Deliberately three named steps rather than a continuous slider. A slider
/// implies precision the user cannot judge ("is 1.17 better than 1.21?") and
/// invites values that break layout; three steps are a choice someone can
/// actually make, and every one of them can be checked on a device.
///
/// [medium] is 1.0 — exactly what the app rendered before this setting existed,
/// so an existing user who never opens Settings sees no change whatsoever.
enum AppTextScale {
  /// 0.9 — a little tighter. Not smaller than this: [AppTextStyles.label] is
  /// 11px, and 0.85 would put it under 10px, which is below the point where
  /// Inter stays comfortably legible on a phone.
  small('small', 0.9),

  /// 1.0 — the shipped default.
  medium('medium', 1.0),

  /// 1.3 — meaningfully larger without being a different layout. See
  /// [TextScaleProvider.maxEffectiveScale] for why this is not higher.
  large('large', 1.3);

  const AppTextScale(this.storageName, this.factor);

  /// The stable string persisted by [SettingsStore].
  ///
  /// Not `Enum.name` by accident — this is the storage contract, and it is
  /// spelled out so renaming the Dart identifier cannot silently orphan every
  /// stored preference.
  final String storageName;

  /// The multiplier applied on top of the OS text size.
  final double factor;

  /// Resolves a persisted name, falling back to [medium].
  ///
  /// Handles null (nothing stored yet) and anything unrecognised (a value from
  /// a future version, or corruption) the same way: the default the app shipped
  /// with is always a safe thing to render.
  static AppTextScale fromName(String? name) {
    for (final AppTextScale scale in AppTextScale.values) {
      if (scale.storageName == name) return scale;
    }
    return medium;
  }
}

/// Owns the user's in-app text size preference and remembers it.
///
/// ## Why this scales via MediaQuery rather than the type tokens
///
/// The obvious-looking implementation is to make every [AppTextStyles] getter
/// multiply its `fontSize` by a scale factor, mirroring how [AppColors] became
/// getters over [AppPalette]. That would be the wrong call here, for three
/// reasons:
///
/// 1. **Flutter already has this mechanism.** `MediaQuery.textScaler` is what
///    every `Text` and `RichText` in the tree consults at layout time, and it
///    is the same channel Android's own font-size setting arrives on. Wrapping
///    the app once in a modified [MediaQuery] scales *all* text — including
///    Material's internal widgets (dialog titles, snackbars, `Switch` labels,
///    tooltips, the date picker) that never touch `AppTextStyles` at all.
/// 2. **Scaling the tokens would miss those Material widgets** and would also
///    miss every `.copyWith(fontSize:)` call site, producing a half-scaled app
///    — the exact failure mode the palette note in `app_palette.dart` warns
///    about, but with no equivalent forcing function to catch it.
/// 3. **`ui_polish_test.dart` pins the type scale** to literal numbers
///    (`display.fontSize == 28`, `body == 14`, …). Those assertions are a
///    deliberate guard on the visual rhythm, and making the tokens
///    scale-dependent would either break them or force them to be weakened.
///
/// So the token layer is untouched. This provider produces a [TextScaler], and
/// `app.dart` installs it once above the navigator.
///
/// ## Multiply, don't replace — and the clamp that makes it safe
///
/// The app is scaled *on top of* the OS setting rather than replacing it. That
/// choice matters:
///
/// - **Replacing** would mean a user who enlarged text device-wide for a real
///   visual impairment gets their accommodation silently thrown away the moment
///   this app launches — and picking "Medium" here would actively *shrink*
///   their text back to 1.0. That is a regression dressed as a feature, and it
///   is an accessibility failure specifically for the users this setting is for.
/// - **Multiplying** keeps the OS preference as the baseline and treats this
///   setting as what it says it is: an in-app adjustment relative to how the
///   user already reads. "Medium" then genuinely means "no change", which is
///   what a default should mean.
///
/// The cost of multiplying is compounding: Android allows up to 2.0 (and more
/// on some OEM skins), so 2.0 × [AppTextScale.large]'s 1.3 would be 2.6× —
/// comfortably past the point where this app's layout survives. Hence
/// [maxEffectiveScale]: the *product* is clamped, not the app's own factor. A
/// user already at the OS maximum simply finds that "Large" changes little,
/// which is the correct outcome — their text is already as large as this app
/// can render coherently.
///
/// ## Constructible without a binding
///
/// Like every provider here, this one must build in a plain unit test: no
/// Firebase, no `WidgetsBinding.instance`. The OS scale is *passed in* by the
/// widget layer via [scalerFor] rather than read from the binding, for exactly
/// that reason.
class TextScaleProvider extends ChangeNotifier {
  TextScaleProvider({AppTextScale initialScale = AppTextScale.medium})
      : _scale = initialScale;

  AppTextScale _scale;

  /// Lower bound on the combined scale.
  ///
  /// The OS can go below 1.0 too (Android's "Small"), and combining that with
  /// this app's [AppTextScale.small] would reach 0.7 — at which point the 11px
  /// label token renders under 8px and is genuinely hard to read.
  static const double minEffectiveScale = 0.8;

  /// Upper bound on the combined scale.
  ///
  /// 1.6 is a judgement call, chosen against this app's actual layout rather
  /// than a spec. Clamping is the honest response — better a ceiling than an
  /// app that renders overflow stripes for the users who most need large text.
  ///
  /// ⚠️ **The clamp is load-bearing, and 1.6 is not a comfortable margin.** A
  /// survey of `lib/` found these already tight at or near this ceiling. None
  /// were fixed as part of adding this setting — the scope was the preference
  /// itself — so they are listed here rather than left to be rediscovered:
  ///
  /// - **`app_bottom_nav.dart`** — the bar is a hard 64px
  ///   ([AppDimensions.navBarHeight]) holding a 22px icon plus a label whose
  ///   *line box* grows with scale. `maxLines: 1` caps the width, not the
  ///   height. This is the same surface that overflowed by 15px during the
  ///   polish pass.
  /// - **`home_screen.dart`** — the search bar's placeholder is a bare `Text`
  ///   in a `Row` with no `Expanded`, and the category rail is a fixed
  ///   `SizedBox(height: 40)` around chips with 10px of vertical padding.
  /// - **`search_screen.dart`** — the same 40px chip rail.
  /// - **`delete_account_screen.dart`** — a 52px `SizedBox` around a bare,
  ///   unbounded `Text('DELETE MY ACCOUNT')`. It does not use [PrimaryButton],
  ///   so it misses that widget's `Flexible` + ellipsis protection.
  /// - **`recipe_detail_screen.dart`** — four `Expanded` nutrition cells in one
  ///   `Row` leave ~68px each on a 360dp screen, with no `maxLines` or
  ///   `FittedBox` on the value or label.
  /// - The `childAspectRatio` recipe grids (favorites / saved / search /
  ///   category) do not hard-overflow, because `recipe_card.dart` makes the
  ///   image `Flexible` — but the photo collapses and the second title line
  ///   clips, which is a quiet degradation rather than a visible error.
  ///
  /// Raising this number is therefore a layout project, not a one-line change.
  /// `settings_screen.dart`'s own rows are the pattern to copy: every label in
  /// an `Expanded`, no fixed row height.
  static const double maxEffectiveScale = 1.6;

  /// The user's choice.
  AppTextScale get scale => _scale;

  /// Loads the persisted choice. Falls back to [AppTextScale.medium] if nothing
  /// was stored or the read fails.
  static Future<TextScaleProvider> load() async {
    final AppTextScale stored = await SettingsStore.loadTextScale();
    return TextScaleProvider(initialScale: stored);
  }

  /// Switches to [scale] and persists it.
  ///
  /// No-ops when unchanged so a stray call cannot cause a rebuild.
  Future<void> setScale(AppTextScale scale) async {
    if (scale == _scale) return;
    _scale = scale;
    notifyListeners();
    await SettingsStore.saveTextScale(scale);
  }

  /// The effective multiplier for an OS text scale of [systemScale].
  ///
  /// This is the whole policy in one expression: multiply, then clamp. Exposed
  /// separately from [scalerFor] so it can be asserted directly in a test
  /// without building a widget tree.
  double effectiveScaleFor(double systemScale) {
    final double combined = systemScale * _scale.factor;
    return combined.clamp(minEffectiveScale, maxEffectiveScale);
  }

  /// The [TextScaler] to install into [MediaQuery].
  ///
  /// [systemScaler] is the one already in the tree — i.e. the OS setting. It is
  /// sampled at the app's own font size (1.0 logical px scaled) rather than
  /// assumed linear, so a platform that ever ships a non-linear curve is read
  /// correctly instead of guessed at.
  TextScaler scalerFor(TextScaler systemScaler) {
    final double systemScale = systemScaler.scale(1);
    return TextScaler.linear(effectiveScaleFor(systemScale));
  }
}
