import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Port of AppFontSizePreference from Theme.swift. The scale factors are
/// derived from iOS Dynamic Type body sizes relative to .large (17pt).
enum AppFontSizePreference {
  xSmall('xSmall', 'xSmall', 14 / 17),
  small('small', 'Small', 15 / 17),
  medium('medium', 'Medium', 16 / 17),
  large('large', 'Large', 1.0),
  xLarge('xLarge', 'xLarge', 19 / 17),
  xxLarge('xxLarge', 'xxLarge', 21 / 17),
  xxxLarge('xxxLarge', 'xxxLarge', 23 / 17);

  const AppFontSizePreference(this.rawValue, this.title, this.scaleFactor);

  final String rawValue;
  final String title;
  final double scaleFactor;

  static const storageKey = 'appFontSizePreference';

  static AppFontSizePreference? fromRaw(String? raw) {
    for (final value in values) {
      if (value.rawValue == raw) return value;
    }
    return null;
  }

  /// Port of snapshotDefault(for:) — picks the preference closest to the
  /// system text scale at first launch.
  static AppFontSizePreference snapshotDefault(double systemScale) {
    var best = AppFontSizePreference.large;
    var bestDistance = double.infinity;
    for (final value in values) {
      final distance = (value.scaleFactor - systemScale).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = value;
      }
    }
    return best;
  }
}

/// App-wide user preferences, persisted via SharedPreferences
/// (port of the @AppStorage values in the Swift app).
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs)
      : _fontSize = AppFontSizePreference.fromRaw(
            _prefs.getString(AppFontSizePreference.storageKey));

  final SharedPreferences _prefs;

  /// Null until the first-launch snapshot of the system size has happened.
  AppFontSizePreference? _fontSize;
  AppFontSizePreference get fontSize =>
      _fontSize ?? AppFontSizePreference.large;
  bool get hasFontSize => _fontSize != null;
  set fontSize(AppFontSizePreference value) {
    if (value == _fontSize) return;
    _fontSize = value;
    _prefs.setString(AppFontSizePreference.storageKey, value.rawValue);
    notifyListeners();
  }

  void snapshotDefaultFontSize(double systemScale) {
    if (_fontSize != null) return;
    fontSize = AppFontSizePreference.snapshotDefault(systemScale);
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppSettingsScope>()!
      .notifier!;
}
