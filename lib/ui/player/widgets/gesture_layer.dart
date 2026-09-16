import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/haptics.dart';
import '../../../state/playback_controller.dart';
import '../player_page.dart';

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

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> {
  /// A swipe across the full screen width covers this much of the video.
  static const double _seekFraction = 0.9;

  /// How far down the middle-swipe has to travel to minimise on release.
  static const double _dismissDistance = 110;

  /// A quick flick minimises even if it did not travel that far.
  static const double _dismissVelocity = 700;

  /// Movement before the gesture commits to an axis, so a slightly crooked
  /// swipe does not get read as the wrong thing.
  static const double _slop = 14;

  _Gesture _gesture = _Gesture.undecided;
  Offset _start = Offset.zero;
  Offset _travel = Offset.zero;

  Duration _seekStart = Duration.zero;
  double _levelStart = 0;
  double _zoomStart = 1;

  late PlaybackController _player;
  late Size _size;
  bool _gesturesOn = true;
  bool _locked = false;

  void _onScaleStart(ScaleStartDetails details) {
    _gesture = _Gesture.undecided;
    _start = details.localFocalPoint;
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

    _travel += details.focalPointDelta;

    if (_gesture == _Gesture.undecided) {
      if (_travel.distance < _slop) return;
      _gesture = _decide();
      if (_gesture == _Gesture.seek) _player.beginScrub(_seekStart);
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

  void _updateSeek() {
    final total = _player.duration;
    if (total == Duration.zero) return;

    final deltaMs =
        (_travel.dx / _size.width) * total.inMilliseconds * _seekFraction;
    var target = _seekStart + Duration(milliseconds: deltaMs.round());
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;

    Haptics.tick();
    _player.updateScrub(target, withHud: true);
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
    // Only downward travel minimises; upward is ignored.
    final down = _travel.dy.clamp(0.0, _size.height);
    _player.setDismissDrag(down / (_dismissDistance * 2));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    switch (_gesture) {
      case _Gesture.seek:
        _player.endScrub();
        _player.hideHud();

      case _Gesture.volume:
      case _Gesture.brightness:
        _player.hideHud();

      case _Gesture.dismiss:
        final flicked = details.velocity.pixelsPerSecond.dy > _dismissVelocity;
        _player.resetDismissDrag();
        if (_travel.dy > _dismissDistance || flicked) {
          Haptics.light();
          closePlayer(context, stopPlayback: false);
        }

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _player.toggleControls,

        // Zoom out again without pinching.
        onDoubleTapDown: locked
            ? null
            : (details) {
                if (_player.zoom.value.isZoomed) {
                  Haptics.light();
                  _player.resetZoom();
                  return;
                }
                if (!gesturesOn) return;

                // How far a skip moves is a Playback Settings option.
                final jump = _player.settings.seekStep;
                final onLeft = details.localPosition.dx < _size.width / 2;
                final step = onLeft ? -jump : jump;
                Haptics.light();
                _player.seekBy(step);
                _player.showSeekHud(_player.position + step, step);
              },
        // Without a handler here onDoubleTapDown never fires.
        onDoubleTap: locked ? null : () {},

        onScaleStart: locked ? null : _onScaleStart,
        onScaleUpdate: locked ? null : _onScaleUpdate,
        onScaleEnd: locked ? null : _onScaleEnd,
      ),
    );
  }
}
