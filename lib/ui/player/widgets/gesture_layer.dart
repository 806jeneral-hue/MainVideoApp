import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/haptics.dart';
import '../../../state/playback_controller.dart';
import '../player_page.dart';
import 'double_tap_seek_ripple.dart';

/// What a touch turned into, decided from the first bit of movement.
enum _Gesture { undecided, seek, volume, brightness, dismiss, zoom }

/// Every touch on the video:
///
/// * tap — show or hide the controls
/// * double tap either side — jump the skip amount
/// * horizontal swipe — seek
/// * vertical swipe on the left third — brightness
/// * vertical swipe on the right third — volume
/// * swipe down from the middle — shrink into the mini player
/// * two fingers — pinch to zoom, and drag the zoomed frame around
///
/// It is all one scale recogniser rather than separate drag ones because
/// Flutter will not let a scale gesture share a detector with both a horizontal
/// and a vertical drag — and a scale gesture already reports everything a drag
/// does. So the single-finger gestures are worked out here from the focal
/// point, and two fingers switch the same gesture over to zooming.
class GestureLayer extends StatefulWidget {
  const GestureLayer({super.key});

  /// Default 2-second seek step for double-tap seek.
  static const Duration doubleTapSeekStep = Duration(seconds: 2);

  /// Wait time after the last tap before triggering the actual seek to the player.
  static const Duration doubleTapSeekDebounce = Duration(milliseconds: 400);

  /// Idle duration before the double-tap seek sequence resets and fades out.
  static const Duration doubleTapSeekReset = Duration(milliseconds: 700);

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> {
  /// A swipe across the full screen width covers this much of the video.
  static const double _seekFraction = 0.9;

  /// How much of the screen height the finger travels to shrink the player
  /// all the way onto the mini player.
  static const double _dismissTravel = 0.6;

  /// Past this much of the way, letting go finishes the shrink.
  static const double _dismissCommit = 0.22;

  /// A quick flick minimises even if it did not travel that far.
  static const double _dismissVelocity = 700;

  /// Where the player already was when a swipe began — non-zero when the
  /// finger caught it while it was gliding back.
  double _dismissBase = 0;

  /// Movement before the gesture commits to an axis, so a slightly crooked
  /// swipe does not get read as the wrong thing.
  static const double _slop = 14;

  _Gesture _gesture = _Gesture.undecided;
  Offset _start = Offset.zero;
  Offset _startGlobal = Offset.zero;
  Offset _travel = Offset.zero;

  Duration _seekStart = Duration.zero;
  double _levelStart = 0;
  double _zoomStart = 1;

  late PlaybackController _player;
  late Size _size;
  bool _gesturesOn = true;
  bool _locked = false;

  // ── Double-Tap Seek State ──────────────────────────────────────────────────
  bool _isDoubleTapSeeking = false;
  bool _seekOnLeft = false;
  int _accumulatedSeconds = 0;
  Duration _doubleTapBasePosition = Duration.zero;
  Timer? _doubleTapDebounceTimer;
  Timer? _doubleTapResetTimer;
  int _lastDoubleTapTapTimeMs = 0;

  @override
  void dispose() {
    _doubleTapDebounceTimer?.cancel();
    _doubleTapResetTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_locked || !_gesturesOn) return;
    if (_player.zoom.value.isZoomed) return;

    // While an active double-tap seek sequence is running, additional taps
    // on the screen immediately accumulate with zero delay.
    if (_isDoubleTapSeeking) {
      final onLeft = event.localPosition.dx < _size.width / 2;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastDoubleTapTapTimeMs > 40) {
        _registerDoubleTapSeek(onLeft);
      }
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_player.zoom.value.isZoomed) {
      Haptics.light();
      _player.resetZoom();
      return;
    }
    if (!_gesturesOn) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDoubleTapTapTimeMs < 100) {
      // Already counted by _onPointerDown
      return;
    }

    final onLeft = details.localPosition.dx < _size.width / 2;
    _registerDoubleTapSeek(onLeft);
  }

  void _registerDoubleTapSeek(bool onLeft) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastDoubleTapTapTimeMs = now;

    if (_isDoubleTapSeeking && _seekOnLeft == onLeft) {
      // Accumulate into the current sequence
      _accumulatedSeconds += GestureLayer.doubleTapSeekStep.inSeconds;
    } else {
      // If switching direction or starting fresh, commit any pending seek
      if (_isDoubleTapSeeking && _doubleTapDebounceTimer != null) {
        _commitDoubleTapSeek();
      }
      _isDoubleTapSeeking = true;
      _seekOnLeft = onLeft;
      _accumulatedSeconds = GestureLayer.doubleTapSeekStep.inSeconds;
      _doubleTapBasePosition = _player.position;
    }

    Haptics.light();

    // Compute clamped target position
    final delta = Duration(seconds: _accumulatedSeconds);
    final target = _seekOnLeft
        ? _doubleTapBasePosition - delta
        : _doubleTapBasePosition + delta;
    final total = _player.duration;
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (total > Duration.zero && clamped > total) clamped = total;

    // Update scrubPosition immediately so the timeline slider and time label
    // reflect the target responsively without decoder churn.
    _player.scrubPosition.value = clamped;

    setState(() {});

    // Reset debounce timer: performs the actual seek after taps stop
    _doubleTapDebounceTimer?.cancel();
    _doubleTapDebounceTimer = Timer(GestureLayer.doubleTapSeekDebounce, () {
      _commitDoubleTapSeek();
    });

    // Reset idle timer: hides ripple overlay after idle period
    _doubleTapResetTimer?.cancel();
    _doubleTapResetTimer = Timer(GestureLayer.doubleTapSeekReset, () {
      if (mounted) {
        setState(() {
          _isDoubleTapSeeking = false;
          _accumulatedSeconds = 0;
        });
      }
    });
  }

  void _commitDoubleTapSeek() {
    _doubleTapDebounceTimer?.cancel();
    _doubleTapDebounceTimer = null;

    final target = _player.scrubPosition.value;
    _player.scrubPosition.value = null;
    if (target != null) {
      _player.seekTo(target);
    }
  }

  void _cancelDoubleTapSeek({bool commit = false}) {
    _doubleTapDebounceTimer?.cancel();
    _doubleTapDebounceTimer = null;
    _doubleTapResetTimer?.cancel();
    _doubleTapResetTimer = null;

    if (commit) {
      final target = _player.scrubPosition.value;
      _player.scrubPosition.value = null;
      if (target != null) {
        _player.seekTo(target);
      }
    } else {
      _player.scrubPosition.value = null;
    }

    if (_isDoubleTapSeeking) {
      setState(() {
        _isDoubleTapSeeking = false;
        _accumulatedSeconds = 0;
      });
    }
  }

  void _onTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Suppress controls toggle if double-tap seek is currently active
    // or just registered a tap within 450ms.
    if (_isDoubleTapSeeking || now - _lastDoubleTapTapTimeMs < 450) {
      return;
    }
    _player.toggleControls();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _cancelDoubleTapSeek(commit: true);
    _gesture = _Gesture.undecided;
    _dismissBase = 0;
    // Catching the player while it glides back picks the swipe up from there.
    final caught = context.read<PlayerMorph>().catchGlide();
    if (caught != null) {
      _gesture = _Gesture.dismiss;
      _dismissBase = caught;
    }
    _start = details.localFocalPoint;
    _startGlobal = details.focalPoint;
    _travel = Offset.zero;
    _seekStart = _player.position;
    _zoomStart = _player.zoom.value.scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_locked) return;

    // Two fingers always mean zoom, whatever the gesture started as.
    if (details.pointerCount >= 2) {
      if (_gesture != _Gesture.zoom) {
        _gesture = _Gesture.zoom;
        _player.hideHud();
        _player.resetDismissDrag();
      }
      _player.setZoom(
        _zoomStart * details.scale,
        panBy: details.focalPointDelta,
      );
      return;
    }

    // A pinch does not turn back into a swipe when a finger lifts.
    if (_gesture == _Gesture.zoom) return;

    // Measured on the screen, not on this layer: the layer itself moves down
    // with the finger while minimising, so in its own coordinates the finger
    // would barely seem to move and the swipe would stall.
    _travel = details.focalPoint - _startGlobal;

    if (_gesture == _Gesture.undecided) {
      if (_travel.distance < _slop) return;
      _gesture = _decide();
      // Seeking, volume and brightness clear the screen down to their readout.
      if (_gesture == _Gesture.seek ||
          _gesture == _Gesture.volume ||
          _gesture == _Gesture.brightness) {
        _player.hideControlsNow();
      }
      if (_gesture == _Gesture.seek) _player.beginSwipeSeek(_seekStart);
      if (_gesture == _Gesture.volume) _levelStart = _player.volume;
      if (_gesture == _Gesture.brightness) _levelStart = _player.brightness;
    }

    switch (_gesture) {
      case _Gesture.seek:
        _updateSeek();
      case _Gesture.volume:
      case _Gesture.brightness:
        _updateLevel();
      case _Gesture.dismiss:
        _updateDismiss();
      case _Gesture.undecided:
      case _Gesture.zoom:
        break;
    }
  }

  /// A zoomed-in video pans with one finger instead of seeking, the way every
  /// photo viewer behaves.
  _Gesture _decide() {
    final horizontal = _travel.dx.abs() > _travel.dy.abs();

    if (horizontal) {
      return _gesturesOn ? _Gesture.seek : _Gesture.undecided;
    }

    final third = _size.width / 3;
    if (_gesturesOn && _start.dx < third) return _Gesture.brightness;
    if (_gesturesOn && _start.dx > third * 2) return _Gesture.volume;
    return _Gesture.dismiss;
  }

  /// The last time the picture was moved during a swipe.
  DateTime _lastPreview = DateTime.fromMillisecondsSinceEpoch(0);

  void _updateSeek() {
    final total = _player.duration;
    if (total == Duration.zero) return;

    // How far a full-width swipe moves is a Playback Settings option: a fixed
    // amount, or in proportion to the length of the video.
    final setting = _player.settings.swipeSeekSeconds;
    final fullSwipeMs = setting > 0
        ? setting * 1000
        : total.inMilliseconds * _seekFraction;
    final deltaMs = (_travel.dx / _size.width) * fullSwipeMs;
    var target = _seekStart + Duration(milliseconds: deltaMs.round());
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;

    Haptics.tick();
    // The frame itself follows the finger — about twenty new frames a second
    // in the player's scrubbing mode — and the time shows in a small pill at
    // the top.
    _player.updateScrub(target, withHud: true);
    final now = DateTime.now();
    if (now.difference(_lastPreview) > const Duration(milliseconds: 45)) {
      _lastPreview = now;
      _player.previewSeek(target);
    }
  }

  void _updateLevel() {
    // Swiping up raises the value, so the travel is inverted.
    final change = -_travel.dy / (_size.height * 0.6);
    final next = (_levelStart + change).clamp(0.0, 1.0);
    Haptics.tick();
    if (_gesture == _Gesture.volume) {
      _player.setVolume(next);
    } else {
      _player.setBrightness(next);
    }
  }

  void _updateDismiss() {
    // Downward travel shrinks the player towards the mini player; moving back
    // up grows it again.
    final progress =
        _dismissBase + _travel.dy / (_size.height * _dismissTravel);
    context.read<PlayerMorph>().dragTo(progress.clamp(0.0, 1.0));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    switch (_gesture) {
      case _Gesture.seek:
        _player.endSwipeSeek();
        _player.hideHud();

      case _Gesture.volume:
      case _Gesture.brightness:
        _player.hideHud();

      case _Gesture.dismiss:
        final velocity = details.velocity.pixelsPerSecond.dy;
        final progress = _player.dismissDrag.value;
        // A flick decides on its own; otherwise it is how far the player got.
        final minimise =
            velocity > _dismissVelocity ||
            (velocity > -_dismissVelocity && progress > _dismissCommit);
        if (minimise) Haptics.light();
        context.read<PlayerMorph>().release(minimise: minimise);

      case _Gesture.zoom:
        // Pinching back down to 1 lets go of the zoom entirely.
        if (!_player.zoom.value.isZoomed) _player.resetZoom();

      case _Gesture.undecided:
        break;
    }
    _gesture = _Gesture.undecided;
    _travel = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    // Only these two flags matter here: watching the whole controller would
    // rebuild this layer on every position tick and every drag event.
    final (gesturesOn, locked) = context
        .select<PlaybackController, (bool, bool)>(
          (p) => (p.settings.gesturesEnabled, p.locked),
        );

    _player = context.read<PlaybackController>();
    _size = MediaQuery.sizeOf(context);
    _gesturesOn = gesturesOn;
    _locked = locked;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            behavior: HitTestBehavior.translucent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,

              // Double tap on left/right for smooth cumulative seeking.
              onDoubleTapDown: locked ? null : _onDoubleTapDown,
              // Without a handler here onDoubleTapDown never fires.
              onDoubleTap: locked ? null : () {},

              // Hold anywhere on the picture to race through at double speed; let
              // go and it drops back to whatever speed was set.
              onLongPressStart: locked
                  ? null
                  : (_) {
                      _cancelDoubleTapSeek(commit: true);
                      Haptics.light();
                      _player.startBoost();
                    },
              onLongPressEnd: locked ? null : (_) => _player.endBoost(),
              onLongPressCancel: locked ? null : _player.endBoost,

              onScaleStart: locked ? null : _onScaleStart,
              onScaleUpdate: locked ? null : _onScaleUpdate,
              onScaleEnd: locked ? null : _onScaleEnd,
            ),
          ),
          DoubleTapSeekRipple(
            visible: _isDoubleTapSeeking,
            isForward: !_seekOnLeft,
            seconds: _accumulatedSeconds,
          ),
        ],
      ),
    );
  }
}
