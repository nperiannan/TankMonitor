import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dashboard concept identifiers — order matches the mockup.
enum DashboardConcept {
  waterFill,   // A — Water fill gauges
  arcGauge,    // B — Arc gauges + LoRa lost
  compact,     // C — Compact horizontal cards
  grid,        // D — 2×3 grid layout
  pill,        // E — Pill cards
  hybrid,      // F — Arc gauges + grid motors  (default)
  pro,         // G — Pro unified cards
}

/// App theme mode.
enum AppThemeMode { light, dark, system }

/// Persistence keys.
const _kDashboardConcept = 'dashboard_concept';
const _kAppThemeMode     = 'app_theme_mode';
const _kUgMotorName      = 'ug_motor_name';
const _kOhMotorName      = 'oh_motor_name';
const _kPrefsVersion     = 'prefs_version';

/// Current prefs schema version.
/// Bump this when adding new keys — the migration guard ensures smooth
/// upgrades without crashing existing installs.
const _currentPrefsVersion = 1;

class AppPreferences extends ChangeNotifier {
  DashboardConcept _concept = DashboardConcept.hybrid;
  AppThemeMode     _themeMode = AppThemeMode.dark;
  String _ugMotorName = 'UG Motor';
  String _ohMotorName = 'OH Motor';

  DashboardConcept get concept   => _concept;
  AppThemeMode     get themeMode => _themeMode;
  String get ugMotorName => _ugMotorName;
  String get ohMotorName => _ohMotorName;

  /// Load saved preferences with migration guard.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Migration guard ──────────────────────────────────────────────────
    final savedVersion = prefs.getInt(_kPrefsVersion) ?? 0;
    if (savedVersion < _currentPrefsVersion) {
      // First time or upgrading from an older version.
      // Set defaults for any keys that don't exist yet; never overwrite
      // values the user already saved.
      if (!prefs.containsKey(_kDashboardConcept)) {
        await prefs.setString(_kDashboardConcept, DashboardConcept.hybrid.name);
      }
      if (!prefs.containsKey(_kAppThemeMode)) {
        await prefs.setString(_kAppThemeMode, AppThemeMode.dark.name);
      }
      await prefs.setInt(_kPrefsVersion, _currentPrefsVersion);
    }

    // ── Read values ──────────────────────────────────────────────────────
    final conceptStr  = prefs.getString(_kDashboardConcept);
    final themeModeStr = prefs.getString(_kAppThemeMode);

    _concept = DashboardConcept.values.firstWhere(
      (e) => e.name == conceptStr,
      orElse: () => DashboardConcept.hybrid,
    );
    _themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeModeStr,
      orElse: () => AppThemeMode.dark,
    );
    _ugMotorName = prefs.getString(_kUgMotorName) ?? 'UG Motor';
    _ohMotorName = prefs.getString(_kOhMotorName) ?? 'OH Motor';

    notifyListeners();
  }

  Future<void> setConcept(DashboardConcept c) async {
    if (_concept == c) return;
    _concept = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDashboardConcept, c.name);
  }

  Future<void> setThemeMode(AppThemeMode m) async {
    if (_themeMode == m) return;
    _themeMode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppThemeMode, m.name);
  }

  Future<void> setMotorName(String motor, String name) async {
    if (motor == 'UG') {
      _ugMotorName = name;
    } else {
      _ohMotorName = name;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      motor == 'UG' ? _kUgMotorName : _kOhMotorName, name);
  }

  /// Resolve effective ThemeMode for MaterialApp.
  ThemeMode get effectiveThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:  return ThemeMode.light;
      case AppThemeMode.dark:   return ThemeMode.dark;
      case AppThemeMode.system: return ThemeMode.system;
    }
  }
}
