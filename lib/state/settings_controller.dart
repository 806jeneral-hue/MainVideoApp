import 'package:flutter/material.dart';

import '../data/models/enums.dart';
import '../core/theme/accent_palette.dart';
import '../data/repositories/settings_repository.dart';

/// Holds every user setting (phases 5 and 7) and writes each change straight
/// back to the local database, so the app always starts in the state it was
/// left in.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repo) {
    _load();
  }

  final SettingsRepository _repo;

  // appearance
  ThemeMode _themeMode = ThemeMode.light;

  // history
  bool _showHistory = true;

  // playback
  bool _resumePlayback = true;
  bool _autoplayNext = true;
  bool _pipEnabled = true;
  bool _backgroundPlayback = false;
  bool _gesturesEnabled = true;
  double _defaultSpeed = 1.0;
  bool _abRepeatEnabled = true;
  bool _sleepTimerEnabled = true;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool _keepScreenOn = true;
  int _seekSeconds = 10;
  int _swipeSeekSeconds = 0;
  bool _hapticsEnabled = true;

  // privacy and personalisation
  bool _recycleBinEnabled = false;
  String _accentKey = AccentPalette.defaultKey;
  String _backgroundImage = '';
  double _backgroundBlur = 14;
  double _glassStrength = 0.5;

  // language
  String? _localeCode;

  void _load() {
    _themeMode = _repo.themeMode;
    _showHistory = _repo.showHistory;
    _resumePlayback = _repo.resumePlayback;
    _autoplayNext = _repo.autoplayNext;
    _pipEnabled = _repo.pipEnabled;
    _backgroundPlayback = _repo.backgroundPlayback;
    _gesturesEnabled = _repo.gesturesEnabled;
    _defaultSpeed = _repo.defaultSpeed;
    _abRepeatEnabled = _repo.abRepeatEnabled;
    _sleepTimerEnabled = _repo.sleepTimerEnabled;
    _shuffle = _repo.shuffle;
    _loopMode = _repo.repeatMode;
    _keepScreenOn = _repo.keepScreenOn;
    _seekSeconds = _repo.seekSeconds;
    _swipeSeekSeconds = _repo.swipeSeekSeconds;
    _hapticsEnabled = _repo.hapticsEnabled;
    _recycleBinEnabled = _repo.recycleBinEnabled;
    _accentKey = _repo.accentKey;
    _backgroundImage = _repo.backgroundImage;
    _backgroundBlur = _repo.backgroundBlur;
    _glassStrength = _repo.glassStrength;
    _localeCode = _repo.localeCode;
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get showHistory => _showHistory;
  bool get resumePlayback => _resumePlayback;
  bool get autoplayNext => _autoplayNext;
  bool get pipEnabled => _pipEnabled;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get gesturesEnabled => _gesturesEnabled;
  double get defaultSpeed => _defaultSpeed;
  bool get abRepeatEnabled => _abRepeatEnabled;
  bool get sleepTimerEnabled => _sleepTimerEnabled;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  bool get keepScreenOn => _keepScreenOn;
  int get seekSeconds => _seekSeconds;

  /// How far a full-width swipe on the video moves it, in seconds; 0 means
  /// in proportion to the video's length.
  int get swipeSeekSeconds => _swipeSeekSeconds;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get recycleBinEnabled => _recycleBinEnabled;

  String get accentKey => _accentKey;
  AccentOption get accent => AccentPalette.byKey(_accentKey);

  /// Null when the plain page colour is used.
  String? get backgroundImage =>
      _backgroundImage.isEmpty ? null : _backgroundImage;
  double get backgroundBlur => _backgroundBlur;
  double get glassStrength => _glassStrength;
  Duration get seekStep => Duration(seconds: _seekSeconds);

  /// Null means the interface follows the device language.
  String? get localeCode => _localeCode;
  Locale? get locale => _localeCode == null ? null : Locale(_localeCode!);

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _repo.setThemeMode(mode);
  }

  Future<void> toggleDarkMode(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

  Future<void> setShowHistory(bool v) async {
    _showHistory = v;
    notifyListeners();
    await _repo.setShowHistory(v);
  }

  Future<void> setResumePlayback(bool v) async {
    _resumePlayback = v;
    notifyListeners();
    await _repo.setResumePlayback(v);
  }

  Future<void> setAutoplayNext(bool v) async {
    _autoplayNext = v;
    notifyListeners();
    await _repo.setAutoplayNext(v);
  }

  Future<void> setPipEnabled(bool v) async {
    _pipEnabled = v;
    notifyListeners();
    await _repo.setPipEnabled(v);
  }

  Future<void> setBackgroundPlayback(bool v) async {
    _backgroundPlayback = v;
    notifyListeners();
    await _repo.setBackgroundPlayback(v);
  }

  Future<void> setGesturesEnabled(bool v) async {
    _gesturesEnabled = v;
    notifyListeners();
    await _repo.setGesturesEnabled(v);
  }

  Future<void> setDefaultSpeed(double v) async {
    _defaultSpeed = v;
    notifyListeners();
    await _repo.setDefaultSpeed(v);
  }

  Future<void> setAbRepeatEnabled(bool v) async {
    _abRepeatEnabled = v;
    notifyListeners();
    await _repo.setAbRepeatEnabled(v);
  }

  Future<void> setSleepTimerEnabled(bool v) async {
    _sleepTimerEnabled = v;
    notifyListeners();
    await _repo.setSleepTimerEnabled(v);
  }

  Future<void> setShuffle(bool v) async {
    _shuffle = v;
    notifyListeners();
    await _repo.setShuffle(v);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    _loopMode = mode;
    notifyListeners();
    await _repo.setRepeatMode(mode);
  }

  Future<void> setKeepScreenOn(bool v) async {
    _keepScreenOn = v;
    notifyListeners();
    await _repo.setKeepScreenOn(v);
  }

  Future<void> setHapticsEnabled(bool v) async {
    _hapticsEnabled = v;
    notifyListeners();
    await _repo.setHapticsEnabled(v);
  }

  Future<void> setRecycleBinEnabled(bool v) async {
    _recycleBinEnabled = v;
    notifyListeners();
    await _repo.setRecycleBinEnabled(v);
  }

  Future<void> setAccentKey(String key) async {
    _accentKey = key;
    notifyListeners();
    await _repo.setAccentKey(key);
  }

  Future<void> setBackgroundImage(String? path) async {
    _backgroundImage = path ?? '';
    notifyListeners();
    await _repo.setBackgroundImage(_backgroundImage);
  }

  Future<void> setBackgroundBlur(double value) async {
    _backgroundBlur = value;
    notifyListeners();
    await _repo.setBackgroundBlur(value);
  }

  Future<void> setGlassStrength(double value) async {
    _glassStrength = value;
    notifyListeners();
    await _repo.setGlassStrength(value);
  }

  Future<void> setSeekSeconds(int v) async {
    _seekSeconds = v;
    notifyListeners();
    await _repo.setSeekSeconds(v);
  }

  Future<void> setSwipeSeekSeconds(int v) async {
    _swipeSeekSeconds = v;
    notifyListeners();
    await _repo.setSwipeSeekSeconds(v);
  }

  Future<void> setLocaleCode(String? code) async {
    _localeCode = code;
    notifyListeners();
    await _repo.setLocaleCode(code);
  }
}
