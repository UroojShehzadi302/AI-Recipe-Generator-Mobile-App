import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../services/settings_store.dart';

/// Owns which theme the app is showing and remembers the choice.
///
/// Three states, matching what users expect from a modern app: follow the
/// device, force light, force dark. [ThemeMode.system] is the default — a fresh
/// install should match the phone rather than assert a preference.
///
/// ## Why this also pokes a global
///
/// Every colour in the app resolves through [AppPalette.current] (see the long
/// note in `app_palette.dart` for why). That global is not reactive, so simply
/// rebuilding with a new [ThemeData] would repaint Material's own surfaces
/// while every `AppColors.x` reference kept the old palette — a half-swapped
/// app.
///
/// So the order here is load-bearing: **set the palette, then notify.** The
/// rebuild triggered by [notifyListeners] is what re-reads the getters, and it
/// has to see the new value. Anything else produces a frame of mixed themes.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    ThemeMode initialMode = ThemeMode.system,
    Brightness platformBrightness = Brightness.light,
  })  : _mode = initialMode,
        _platformBrightness = platformBrightness;

  ThemeMode _mode;

  /// The last platform brightness this provider was told about.
  ///
  /// Held as state rather than read from `WidgetsBinding.instance` on demand,
  /// deliberately: reaching for the binding would make this provider
  /// un-constructible without one, and every provider in this codebase is
  /// designed to be built in a plain unit test. [syncWithPlatformBrightness]
  /// is how the widget layer keeps it current.
  Brightness _platformBrightness;

  /// The user's choice: system, light, or dark.
  ThemeMode get mode => _mode;

  /// Loads the persisted choice. Safe to call before the first frame; falls
  /// back to [ThemeMode.system] if nothing was stored or the read fails.
  ///
  /// [platformBrightness] seeds the initial resolution. `main()` passes the
  /// real value from the dispatcher; the default keeps this callable from a
  /// test without a binding.
  static Future<ThemeProvider> load({
    Brightness platformBrightness = Brightness.light,
  }) async {
    final ThemeMode stored = await SettingsStore.loadThemeMode();
    final ThemeProvider provider = ThemeProvider(
      initialMode: stored,
      platformBrightness: platformBrightness,
    );
    // Seed the palette before the first paint so the app does not start light
    // and flip a frame later.
    provider._syncPalette();
    return provider;
  }

  /// Switches the app to [mode] and persists it.
  ///
  /// No-ops when the mode is unchanged so a stray call cannot cause a rebuild.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    _syncPalette();
    notifyListeners();
    await SettingsStore.saveThemeMode(mode);
  }

  /// Re-resolves the palette against the current platform brightness.
  ///
  /// Only meaningful in [ThemeMode.system]: it is how the app follows the OS
  /// flipping to dark at sunset while it is running. `MaterialApp` already
  /// rebuilds on that change; this keeps [AppPalette.current] in step.
  ///
  /// Returns true when the palette actually changed, so the caller can decide
  /// whether a rebuild is warranted.
  bool syncWithPlatformBrightness(Brightness platformBrightness) {
    _platformBrightness = platformBrightness;
    final AppPalette before = AppPalette.current;
    _syncPalette();
    return !identical(before, AppPalette.current);
  }

  /// Whether [mode] resolves to dark given [platformBrightness].
  bool resolvesToDark(Brightness platformBrightness) {
    switch (_mode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return platformBrightness == Brightness.dark;
    }
  }

  void _syncPalette() {
    AppPalette.apply(
      resolvesToDark(_platformBrightness) ? AppPalette.dark : AppPalette.light,
    );
  }
}
