import 'package:flutter/material.dart';

import '../../core/theme/accent_palette.dart';
import '../local/app_database.dart';
import '../models/enums.dart';

/// Thin typed wrapper over the settings box. Everything the user can toggle
/// in phases 5 and 7 lives here, with the defaults the app ships with.
class SettingsRepository {
  const SettingsRepository();

  T _get<T>(String key, T fallback) {
    final value = AppDatabase.settings.get(key);
    return value is T ? value : fallback;
  }

  Future<void> _set(String key, Object? value) =>
      AppDatabase.settings.put(key, value);

  // ---------------------------------------------------------------- appearance
  ThemeMode get themeMode {
    final raw = _get<String>(SettingsKeys.themeMode, 'light');
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _set(SettingsKeys.themeMode, mode.name);

  // --------------------------------------------------------------------- home
  ViewMode get viewMode => _get<String>(SettingsKeys.viewMode, 'list') == 'grid'
      ? ViewMode.grid
      : ViewMode.list;

  Future<void> setViewMode(ViewMode mode) =>
      _set(SettingsKeys.viewMode, mode.name);

  SortField get sortField {
    final raw = _get<String>(SettingsKeys.sortField, SortField.dateAdded.name);
    return SortField.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => SortField.dateAdded,
    );
  }

  Future<void> setSortField(SortField field) =>
      _set(SettingsKeys.sortField, field.name);

  bool get sortDescending => _get<bool>(SettingsKeys.sortDescending, true);

  Future<void> setSortDescending(bool value) =>
      _set(SettingsKeys.sortDescending, value);

  // ------------------------------------------------------------------ folders
  /// Empty means "scan everything". Otherwise only these folder paths are used.
  List<String> get scanFolders =>
      (_get<List>(SettingsKeys.scanFolders, const [])).cast<String>();

  Future<void> setScanFolders(List<String> paths) =>
      _set(SettingsKeys.scanFolders, paths);

  List<String> get hiddenFolders =>
      (_get<List>(SettingsKeys.hiddenFolders, const [])).cast<String>();

  Future<void> setHiddenFolders(List<String> paths) =>
      _set(SettingsKeys.hiddenFolders, paths);

  // -------------------------------------------------------------------- pins
  List<String> get pinnedVideos =>
      (_get<List>(SettingsKeys.pinnedVideos, const [])).cast<String>();

  Future<void> setPinnedVideos(List<String> ids) =>
      _set(SettingsKeys.pinnedVideos, ids);

  List<String> get pinnedFolders =>
      (_get<List>(SettingsKeys.pinnedFolders, const [])).cast<String>();

  Future<void> setPinnedFolders(List<String> paths) =>
      _set(SettingsKeys.pinnedFolders, paths);

  // --------------------------------------------------------------- scan state
  DateTime? get lastScanAt {
    final ms = _get<int?>(SettingsKeys.lastScanAt, null);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastScanAt(DateTime value) =>
      _set(SettingsKeys.lastScanAt, value.millisecondsSinceEpoch);

  // ------------------------------------------------------------------ history
  bool get showHistory => _get<bool>(SettingsKeys.showHistory, true);

  Future<void> setShowHistory(bool value) =>
      _set(SettingsKeys.showHistory, value);

  // ----------------------------------------------------------------- playback
  bool get resumePlayback => _get<bool>(SettingsKeys.resumePlayback, true);
  Future<void> setResumePlayback(bool v) =>
      _set(SettingsKeys.resumePlayback, v);

  bool get autoplayNext => _get<bool>(SettingsKeys.autoplayNext, true);
  Future<void> setAutoplayNext(bool v) => _set(SettingsKeys.autoplayNext, v);

  bool get pipEnabled => _get<bool>(SettingsKeys.pipEnabled, true);
  Future<void> setPipEnabled(bool v) => _set(SettingsKeys.pipEnabled, v);

  bool get backgroundPlayback =>
      _get<bool>(SettingsKeys.backgroundPlayback, false);
  Future<void> setBackgroundPlayback(bool v) =>
      _set(SettingsKeys.backgroundPlayback, v);

  bool get gesturesEnabled => _get<bool>(SettingsKeys.gesturesEnabled, true);
  Future<void> setGesturesEnabled(bool v) =>
      _set(SettingsKeys.gesturesEnabled, v);

  double get defaultSpeed => _get<double>(SettingsKeys.defaultSpeed, 1.0);
  Future<void> setDefaultSpeed(double v) => _set(SettingsKeys.defaultSpeed, v);

  bool get abRepeatEnabled => _get<bool>(SettingsKeys.abRepeatEnabled, true);
  Future<void> setAbRepeatEnabled(bool v) =>
      _set(SettingsKeys.abRepeatEnabled, v);

  bool get sleepTimerEnabled =>
      _get<bool>(SettingsKeys.sleepTimerEnabled, true);
  Future<void> setSleepTimerEnabled(bool v) =>
      _set(SettingsKeys.sleepTimerEnabled, v);

  bool get shuffle => _get<bool>(SettingsKeys.shuffle, false);
  Future<void> setShuffle(bool v) => _set(SettingsKeys.shuffle, v);

  LoopMode get repeatMode {
    final raw = _get<String>(SettingsKeys.repeatMode, LoopMode.off.name);
    return LoopMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => LoopMode.off,
    );
  }

  Future<void> setRepeatMode(LoopMode mode) =>
      _set(SettingsKeys.repeatMode, mode.name);

  bool get keepScreenOn => _get<bool>(SettingsKeys.keepScreenOn, true);
  Future<void> setKeepScreenOn(bool v) => _set(SettingsKeys.keepScreenOn, v);

  /// How far a double-tap or a skip button moves, in seconds.
  int get seekSeconds => _get<int>(SettingsKeys.seekSeconds, 10);
  Future<void> setSeekSeconds(int v) => _set(SettingsKeys.seekSeconds, v);

  bool get hapticsEnabled => _get<bool>(SettingsKeys.hapticsEnabled, true);
  Future<void> setHapticsEnabled(bool v) =>
      _set(SettingsKeys.hapticsEnabled, v);

  // ------------------------------------------------------- privacy and safety
  /// Off by default: deleting means deleting unless the user asks for a net.
  bool get recycleBinEnabled =>
      _get<bool>(SettingsKeys.recycleBinEnabled, false);
  Future<void> setRecycleBinEnabled(bool v) =>
      _set(SettingsKeys.recycleBinEnabled, v);

  /// How long a video stays in the bin before it is cleared out.
  int get recycleBinDays => _get<int>(SettingsKeys.recycleBinDays, 30);
  Future<void> setRecycleBinDays(int v) => _set(SettingsKeys.recycleBinDays, v);

  List<String> get hiddenVideos =>
      (_get<List>(SettingsKeys.hiddenVideos, const [])).cast<String>();
  Future<void> setHiddenVideos(List<String> ids) =>
      _set(SettingsKeys.hiddenVideos, ids);

  // --------------------------------------------------------- personalisation
  String get accentKey =>
      _get<String>(SettingsKeys.accentKey, AccentPalette.defaultKey);
  Future<void> setAccentKey(String key) => _set(SettingsKeys.accentKey, key);

  // ----------------------------------------------------------------- language
  /// Null means "follow the device language".
  String? get localeCode {
    final raw = _get<String>(SettingsKeys.locale, 'system');
    return raw == 'system' ? null : raw;
  }

  Future<void> setLocaleCode(String? code) =>
      _set(SettingsKeys.locale, code ?? 'system');
}
