// Dart forbids named parameters that start with an underscore, so the
// dependencies below cannot be written as initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/utils/formatters.dart';
import '../data/models/enums.dart';
import '../data/models/video.dart';
import '../data/services/background_audio_service.dart';
import '../data/services/pip_service.dart';
import 'library_controller.dart';
import 'settings_controller.dart';

/// What the on-screen indicator is currently showing during a gesture.
enum HudKind { volume, brightness, seek, speed }

/// How far the video is pinched in, and where it has been dragged to.
class ZoomState {
  const ZoomState({required this.scale, required this.offset});

  static const ZoomState none = ZoomState(scale: 1, offset: Offset.zero);

  final double scale;
  final Offset offset;

  bool get isZoomed => scale > 1.0;
}

/// One reading of the gesture indicator.
class HudState {
  const HudState(this.kind, this.value, this.label);

  final HudKind kind;
  final double value;
  final String label;
}

/// The app's single playback session.
///
/// There is exactly one of these for the whole app, which is what makes the
/// mini player possible: leaving the player screen keeps the session alive,
/// and opening another video replaces this one rather than starting a second
/// player alongside it.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required SettingsController settings,
    required LibraryController library,
  }) : _settings = settings,
       _library = library;

  final SettingsController _settings;
  final LibraryController _library;

  VideoPlayerController? _vp;

  List<Video> _queue = const [];
  int _index = 0;
  String _queueTitle = '';

  /// Playback order — identical to the queue unless shuffle is on.
  List<int> _order = const [];

  bool _hasSession = false;
  bool _fullscreen = false;
  bool _ready = false;
  String? _error;

  /// Guards against a slow open finishing after a newer one started.
  int _openToken = 0;

  // Anything that changes at the speed of a finger or of playback lives in its
  // own notifier. Putting these on the controller itself would rebuild the
  // whole control overlay on every drag event and every position tick, which
  // is what made dragging and fading feel rough.

  /// Whether the control overlay is on screen.
  final ValueNotifier<bool> controlsVisible = ValueNotifier<bool>(true);

  /// Progress of the swipe-down-to-minimise gesture, 0..1.
  final ValueNotifier<double> dismissDrag = ValueNotifier<double>(0);

  /// Non-null only while the user is dragging the seek bar or swiping to seek.
  final ValueNotifier<Duration?> scrubPosition = ValueNotifier<Duration?>(null);

  /// The floating gesture readout; null hides it.
  final ValueNotifier<HudState?> hud = ValueNotifier<HudState?>(null);

  bool _locked = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  double _speed = 1.0;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;

  Duration? _pointA;
  Duration? _pointB;

  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;

  Timer? _hudTimer;

  double _volume = 0.5;
  double _brightness = 0.5;
  bool _brightnessTouched = false;

  bool _isPip = false;
  bool _pipRequested = false;
  Duration _scrubStart = Duration.zero;

  // ------------------------------------------------------------------ getters
  VideoPlayerController? get player => _vp;

  bool get hasSession => _hasSession && _queue.isNotEmpty;
  bool get isFullscreen => _fullscreen;

  /// The mini player shows whenever something is loaded and the full screen
  /// is not on top of it.
  bool get showMiniPlayer => hasSession && !_fullscreen;

  Video? get currentOrNull =>
      _queue.isEmpty ? null : _queue[_index.clamp(0, _queue.length - 1)];
  Video get current => _queue[_index];

  List<Video> get queue => _queue;
  String get queueTitle => _queueTitle;
  int get index => _index;
  bool get ready => _ready;
  String? get error => _error;

  bool get locked => _locked;
  bool get isPip => _isPip;
  bool get seeking => scrubPosition.value != null;

  bool get isPlaying => _vp?.value.isPlaying ?? false;
  bool get isBuffering => _vp?.value.isBuffering ?? false;

  Duration get position =>
      scrubPosition.value ?? (_vp?.value.position ?? Duration.zero);
  Duration get duration => _vp?.value.duration ?? Duration.zero;

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get speed => _speed;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;

  Duration? get pointA => _pointA;
  Duration? get pointB => _pointB;
  bool get abActive => _pointA != null && _pointB != null;

  DateTime? get sleepEndsAt => _sleepEndsAt;
  Duration? get sleepRemaining {
    final end = _sleepEndsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  double get volume => _volume;
  double get brightness => _brightness;

  bool get hasNext => _order.indexOf(_index) < _order.length - 1;
  bool get hasPrevious => _order.indexOf(_index) > 0;

  SettingsController get settings => _settings;

  // ------------------------------------------------------------------ session
  /// Starts (or replaces) the playback session. Any video already playing is
  /// stopped first — there is only ever one player.
  Future<void> open({
    required List<Video> queue,
    required int startIndex,
    String queueTitle = '',
    bool? shuffle,
  }) async {
    if (queue.isEmpty) return;

    _queue = List<Video>.from(queue);
    _queueTitle = queueTitle;
    _hasSession = true;
    _index = startIndex.clamp(0, _queue.length - 1);
    _shuffle = shuffle ?? _settings.shuffle;
    _loopMode = _settings.loopMode;
    _speed = _settings.defaultSpeed;
    _buildOrder();
    await _load(_index);
  }

  /// Ends the session completely and takes the mini player away.
  Future<void> stop() async {
    _openToken++;
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepEndsAt = null;
    await _savePosition();

    final controller = _vp;
    _vp = null;
    controller?.removeListener(_onPlayerTick);
    await controller?.dispose();

    _hasSession = false;
    _queue = const [];
    _order = const [];
    _ready = false;
    _error = null;
    _locked = false;
    _isPip = false;
    _pipRequested = false;
    clearAb();
    await _restoreBrightness();
    await WakelockPlus.disable();
    await BackgroundAudioService.stop();
    notifyListeners();
  }

  // ------------------------------------------------- background audio service
  /// Keeps the foreground service in step with what is playing, so the
  /// notification is right and Android does not reclaim the process mid-video.
  Future<void> _syncBackgroundService() async {
    if (!_settings.backgroundPlayback || !hasSession) {
      await BackgroundAudioService.stop();
      return;
    }

    final video = currentOrNull;
    if (video == null) return;

    final subtitle = _queueTitle.isEmpty ? video.folderName : _queueTitle;
    if (BackgroundAudioService.isRunning) {
      await BackgroundAudioService.update(
        title: video.displayName,
        subtitle: subtitle,
        playing: isPlaying,
      );
      return;
    }

    await BackgroundAudioService.start(
      title: video.displayName,
      subtitle: subtitle,
      playing: isPlaying,
    );
  }

  /// Wired once at start-up so the notification buttons and audio focus reach
  /// playback.
  void bindBackgroundService() {
    BackgroundAudioService.ensureWired();
    BackgroundAudioService.onAction = (action) {
      switch (action) {
        case 'toggle':
          togglePlay();
        case 'next':
          next();
        case 'previous':
          previous();
        case 'pause':
          // Something else took audio focus — a call, another player.
          _vp?.pause();
          _syncBackgroundService();
          notifyListeners();
        case 'stop':
          stop();
      }
    };
  }

  // ---------------------------------------------------------- display / zoom
  VideoFit _videoFit = VideoFit.fit;
  VideoFit get videoFit => _videoFit;

  /// Pinch zoom on top of the fit mode. Its own notifier so a pinch repaints
  /// the video surface alone rather than rebuilding the whole player.
  final ValueNotifier<ZoomState> zoom = ValueNotifier<ZoomState>(
    ZoomState.none,
  );

  static const double maxZoom = 5;

  void cycleVideoFit() {
    _videoFit = switch (_videoFit) {
      VideoFit.fit => VideoFit.fill,
      VideoFit.fill => VideoFit.fit,
    };
    // A zoom made sense for the old framing, not the new one.
    zoom.value = ZoomState.none;
    notifyListeners();
  }

  /// [scale] is absolute; [panBy] moves the zoomed frame under the fingers.
  void setZoom(double scale, {Offset panBy = Offset.zero}) {
    final next = scale.clamp(1.0, maxZoom);
    if (next <= 1.0) {
      zoom.value = ZoomState.none;
      return;
    }
    zoom.value = ZoomState(
      scale: next,
      offset: zoom.value.offset + panBy,
    );
  }

  void resetZoom() => zoom.value = ZoomState.none;

  bool get isZoomed => zoom.value.scale > 1.0;

  // -------------------------------------------------------------- rotation
  /// Forces the player into landscape or portrait, whatever the device's
  /// auto-rotate setting says. Null follows the device.
  Orientation? _forcedOrientation;
  Orientation? get forcedOrientation => _forcedOrientation;

  /// Cycles: follow device → landscape → portrait → follow device.
  Future<void> cycleOrientation() async {
    _forcedOrientation = switch (_forcedOrientation) {
      null => Orientation.landscape,
      Orientation.landscape => Orientation.portrait,
      Orientation.portrait => null,
    };
    await applyOrientation();
    notifyListeners();
  }

  Future<void> applyOrientation() async {
    await SystemChrome.setPreferredOrientations(switch (_forcedOrientation) {
      Orientation.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      Orientation.portrait => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      null => DeviceOrientation.values,
    });
  }

  void setDismissDrag(double value) =>
      dismissDrag.value = value.clamp(0.0, 1.0);

  void resetDismissDrag() => dismissDrag.value = 0;

  /// Guards the full-screen route against being popped twice.
  ///
  /// Several things can ask to close it at once — the back button, the
  /// minimise button, and the automatic close when the session ends because
  /// the file went away. Two pops would take the home screen with them and
  /// leave a black window, so only the first request wins.
  bool _closingFullscreen = false;

  bool beginClose() {
    if (_closingFullscreen) return false;
    _closingFullscreen = true;
    return true;
  }

  void enterFullscreen() {
    dismissDrag.value = 0;
    _closingFullscreen = false;
    if (_fullscreen) return;
    _fullscreen = true;
    _showControlsBriefly();
    notifyListeners();
  }

  Future<void> exitFullscreen() async {
    if (!_fullscreen) return;
    _fullscreen = false;
    // A forced rotation belongs to the full-screen player only.
    _forcedOrientation = null;
    _locked = false;
    dismissDrag.value = 0;
    await _restoreBrightness();
    notifyListeners();
  }

  // -------------------------------------------------------------------- setup
  Future<void> initSystemLevels() async {
    try {
      VolumeController.instance.showSystemUI = false;
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {
      _volume = 0.5;
    }
    try {
      _brightness = await ScreenBrightness.instance.application;
    } catch (_) {
      _brightness = 0.5;
    }
    notifyListeners();
  }

  void _buildOrder() {
    final indices = List<int>.generate(_queue.length, (i) => i);
    if (_shuffle) {
      indices.shuffle();
      // Whatever is playing now stays first so shuffle never skips it.
      indices.remove(_index);
      indices.insert(0, _index);
    }
    _order = indices;
  }

  Future<void> _load(int newIndex) async {
    final token = ++_openToken;

    await _savePosition();
    _saveTimer?.cancel();

    final old = _vp;
    _vp = null;
    old?.removeListener(_onPlayerTick);

    _ready = false;
    _error = null;
    // A pinch belongs to the video it was made on.
    zoom.value = ZoomState.none;
    _pointA = null;
    _pointB = null;
    _index = newIndex;
    notifyListeners();

    await old?.dispose();

    final video = _queue[_index];
    final controller = VideoPlayerController.file(File(video.path));

    try {
      await controller.initialize();
    } catch (_) {
      if (token != _openToken) {
        await controller.dispose();
        return;
      }
      _error = 'This video could not be opened.';
      _ready = true;
      notifyListeners();
      return;
    }

    // A newer open() landed while this one was initialising.
    if (token != _openToken) {
      await controller.dispose();
      return;
    }

    _vp = controller;
    controller.addListener(_onPlayerTick);

    await controller.setPlaybackSpeed(_speed);
    await controller.setLooping(false);

    if (_settings.resumePlayback) {
      final resumeMs = _library.resumePositionMs(video.id);
      if (resumeMs > 2000 && resumeMs < video.durationMs - 3000) {
        await controller.seekTo(Duration(milliseconds: resumeMs));
      }
    }

    _ready = true;
    await controller.play();
    _applyWakelock();
    _startSaveTimer();
    _showControlsBriefly();
    unawaited(_syncBackgroundService());
    notifyListeners();
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      // Silent: the library is kept in step without rebuilding the screens
      // sitting underneath the player every five seconds.
      (_) => _savePosition(notify: false),
    );
  }

  Future<void> _savePosition({bool notify = true}) async {
    final controller = _vp;
    if (controller == null || !controller.value.isInitialized) return;
    if (_queue.isEmpty) return;
    final total = controller.value.duration.inMilliseconds;
    if (total <= 0) return;

    await _library.savePosition(
      videoId: _queue[_index].id,
      positionMs: controller.value.position.inMilliseconds,
      durationMs: total,
      notify: notify,
    );
  }

  // ------------------------------------------------------------------- ticker
  bool _handlingCompletion = false;

  void _onPlayerTick() {
    final controller = _vp;
    if (controller == null || !controller.value.isInitialized) return;

    // A-B repeat: jump back to A as soon as B is passed.
    final a = _pointA;
    final b = _pointB;
    if (a != null && b != null && controller.value.position >= b) {
      controller.seekTo(a);
    }

    final total = controller.value.duration;
    final pos = controller.value.position;
    // isCompleted is the reliable signal; the position check catches players
    // that stop just short of the reported duration.
    final finished =
        controller.value.isCompleted ||
        (total > Duration.zero &&
            pos >= total - const Duration(milliseconds: 250) &&
            !controller.value.isPlaying);

    if (finished && !_handlingCompletion) {
      _handlingCompletion = true;
      _onCompleted().whenComplete(() => _handlingCompletion = false);
    }

    notifyListeners();
  }

  Future<void> _onCompleted() async {
    await _library.savePosition(
      videoId: current.id,
      positionMs: duration.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );

    if (_loopMode == LoopMode.one) {
      await _vp?.seekTo(Duration.zero);
      await _vp?.play();
      return;
    }

    if (!_settings.autoplayNext) {
      _showControls();
      return;
    }

    if (hasNext) {
      await next();
      return;
    }

    if (_loopMode == LoopMode.all && _order.isNotEmpty) {
      await _load(_order.first);
      return;
    }

    _showControls();
  }

  // ---------------------------------------------------------------- transport
  Future<void> togglePlay() async {
    final controller = _vp;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await _savePosition();
    } else {
      await controller.play();
    }
    _applyWakelock();
    _showControlsBriefly();
    unawaited(_syncBackgroundService());
    notifyListeners();
  }

  Future<void> next() async {
    final at = _order.indexOf(_index);
    if (at < 0 || at >= _order.length - 1) return;
    await _load(_order[at + 1]);
  }

  Future<void> previous() async {
    // Restart the current video first, the way most players do.
    if (position > const Duration(seconds: 3)) {
      await seekTo(Duration.zero);
      return;
    }
    final at = _order.indexOf(_index);
    if (at <= 0) return;
    await _load(_order[at - 1]);
  }

  Future<void> playAt(int queueIndex) async {
    if (queueIndex < 0 || queueIndex >= _queue.length) return;
    await _load(queueIndex);
  }

  Future<void> seekTo(Duration target) async {
    final controller = _vp;
    if (controller == null) return;
    final total = controller.value.duration;
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (total > Duration.zero && clamped > total) clamped = total;
    await controller.seekTo(clamped);
    notifyListeners();
  }

  Future<void> seekBy(Duration delta) => seekTo(position + delta);

  void beginScrub(Duration at) {
    scrubPosition.value = at;
    _scrubStart = at;
    _cancelHideTimer();
  }

  /// [withHud] also updates the gesture readout. Both go through their own
  /// notifiers, so a seek drag repaints two small widgets rather than
  /// rebuilding the whole overlay on every frame.
  void updateScrub(Duration at, {bool withHud = false}) {
    scrubPosition.value = at;
    if (!withHud) return;

    final delta = at - _scrubStart;
    final sign = delta.isNegative ? '-' : '+';
    _hudTimer?.cancel();
    hud.value = HudState(
      HudKind.seek,
      duration.inMilliseconds == 0
          ? 0
          : (at.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
      '$sign${delta.inSeconds.abs()}s',
    );
  }

  Future<void> endScrub() async {
    final target = scrubPosition.value;
    scrubPosition.value = null;
    if (target != null) await seekTo(target);
    _showControlsBriefly();
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _vp?.setPlaybackSpeed(value);
    _flashHud(HudKind.speed, value / 3, Fmt.speed(value));
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    _buildOrder();
    await _settings.setShuffle(_shuffle);
    notifyListeners();
  }

  Future<void> cycleLoopMode() async {
    _loopMode = switch (_loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _settings.setLoopMode(_loopMode);
    notifyListeners();
  }

  // ---------------------------------------------------------------- A-B repeat
  void markAbPoint() {
    if (_pointA == null) {
      _pointA = position;
    } else if (_pointB == null) {
      final candidate = position;
      if (candidate <= _pointA!) {
        // Second tap landed before A — treat it as a new A.
        _pointA = candidate;
      } else {
        _pointB = candidate;
      }
    } else {
      _pointA = null;
      _pointB = null;
    }
    _showControlsBriefly();
    notifyListeners();
  }

  void clearAb() {
    _pointA = null;
    _pointB = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- sleep timer
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      await _vp?.pause();
      await _savePosition();
      _sleepEndsAt = null;
      _applyWakelock();
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ controls
  /// A tap anywhere on the video toggles the overlay.
  void toggleControls() {
    if (_locked) {
      // Tapping a locked screen only reveals the unlock button.
      _showControlsBriefly();
      return;
    }
    controlsVisible.value ? _hideControls() : _showControlsBriefly();
  }

  void _showControls() {
    controlsVisible.value = true;
    _cancelHideTimer();
  }

  void _showControlsBriefly() {
    controlsVisible.value = true;
    _cancelHideTimer();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (isPlaying) _hideControls();
    });
  }

  void keepControlsAlive() => _showControlsBriefly();

  void _hideControls() {
    controlsVisible.value = false;
    _cancelHideTimer();
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void toggleLock() {
    _locked = !_locked;
    controlsVisible.value = true;
    _cancelHideTimer();
    if (_locked) {
      _hideTimer = Timer(const Duration(seconds: 2), () {
        controlsVisible.value = false;
      });
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ gestures
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await VolumeController.instance.setVolume(_volume);
    } catch (_) {
      // Ignore: the device refused the change, the HUD still reflects intent.
    }
    _flashHud(HudKind.volume, _volume, '${(_volume * 100).round()}%');
  }

  Future<void> setBrightness(double value) async {
    _brightness = value.clamp(0.0, 1.0);
    _brightnessTouched = true;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        _brightness,
      );
    } catch (_) {
      // Ignore: some devices block app brightness control.
    }
    _flashHud(
      HudKind.brightness,
      _brightness,
      '${(_brightness * 100).round()}%',
    );
  }

  void showSeekHud(Duration target, Duration delta) {
    final sign = delta.isNegative ? '-' : '+';
    final seconds = delta.inSeconds.abs();
    _flashHud(
      HudKind.seek,
      duration.inMilliseconds == 0
          ? 0
          : target.inMilliseconds / duration.inMilliseconds,
      '$sign${seconds}s',
    );
  }

  void _flashHud(HudKind kind, double value, String label) {
    hud.value = HudState(kind, value.clamp(0.0, 1.0), label);
    _hudTimer?.cancel();
    _hudTimer = Timer(
      const Duration(milliseconds: 750),
      () => hud.value = null,
    );
  }

  void hideHud() {
    _hudTimer?.cancel();
    hud.value = null;
  }

  // ----------------------------------------------------------------------- PiP
  Future<bool> enterPip() async {
    if (!_settings.pipEnabled || !hasSession) return false;
    _pipRequested = true;
    final entered = await PipService.enterPip();
    if (entered) {
      _isPip = true;
      controlsVisible.value = false;
      notifyListeners();
    } else {
      _pipRequested = false;
    }
    return entered;
  }

  void setPipState(bool value) {
    if (!value) _pipRequested = false;
    if (_isPip == value) return;
    _isPip = value;
    if (!value) _showControlsBriefly();
    notifyListeners();
  }

  /// Called when the app goes to the background. Playback only continues if
  /// the user allowed background playback or the window is in PiP.
  Future<void> handleAppPaused() async {
    if (!hasSession) return;
    await _savePosition();
    if (_isPip || _pipRequested || _settings.backgroundPlayback) return;
    await _vp?.pause();
    notifyListeners();
  }

  void _applyWakelock() {
    final shouldHold = _settings.keepScreenOn && isPlaying;
    WakelockPlus.toggle(enable: shouldHold);
  }

  Future<void> _restoreBrightness() async {
    if (!_brightnessTouched) return;
    _brightnessTouched = false;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      // Nothing to restore.
    }
  }

  /// Keeps the session pointing at the right file after a rename, and closes
  /// it if the file playing was the one deleted.
  Future<void> onLibraryVideoChanged({
    required String oldId,
    Video? replacement,
  }) async {
    final at = _queue.indexWhere((v) => v.id == oldId);
    if (at < 0) return;

    if (replacement == null) {
      final wasCurrent = at == _index;
      final queue = List<Video>.from(_queue)..removeAt(at);
      if (queue.isEmpty) {
        await stop();
        return;
      }
      _queue = queue;
      if (at < _index) _index--;
      _buildOrder();
      if (wasCurrent) {
        await _load(_index.clamp(0, _queue.length - 1));
      } else {
        notifyListeners();
      }
      return;
    }

    final queue = List<Video>.from(_queue);
    queue[at] = replacement;
    _queue = queue;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _sleepTimer?.cancel();
    _saveTimer?.cancel();

    final controller = _vp;
    _vp = null;
    if (controller != null) {
      controller.removeListener(_onPlayerTick);
      await controller.dispose();
    }
    await _restoreBrightness();
    await WakelockPlus.disable();

    controlsVisible.dispose();
    zoom.dispose();
    dismissDrag.dispose();
    scrubPosition.dispose();
    hud.dispose();
    super.dispose();
  }
}
