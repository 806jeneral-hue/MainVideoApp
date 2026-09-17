import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../../state/playback_controller.dart';
import '../common/tab_scroll.dart';
import 'mini_player.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/player_controls.dart';
import 'widgets/player_hud.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';

/// Starts playing a queue and opens the full-screen player.
///
/// There is one playback session for the whole app, so this always replaces
/// whatever was playing before rather than starting a second player.
Future<void> openPlayer(
  BuildContext context, {
  required List<Video> queue,
  required int startIndex,
  String queueTitle = '',

  /// Overrides the default shuffle setting for this queue only — used by
  /// Play All, which offers both orders.
  bool? shuffle,
}) async {
  if (queue.isEmpty) return;

  final playback = context.read<PlaybackController>();
  final navigator = Navigator.of(context, rootNavigator: true);
  final alreadyFullscreen = playback.isFullscreen;

  // Claim the full screen *before* anything starts loading.
  //
  // The mini player shows whenever a session exists and the full screen is not
  // on top of it. Opening a file takes as long as it takes, so without this the
  // session would exist while the route was still being pushed and the mini
  // player would flash along the bottom of the list first. Tapping a video goes
  // straight to full screen.
  playback.enterFullscreen();

  // `open` runs far enough synchronously to register the queue, so the player
  // screen never builds against an empty session and close itself again.
  final opening = playback.open(
    queue: queue,
    startIndex: startIndex,
    queueTitle: queueTitle,
    shuffle: shuffle,
  );

  // Tapping a video from inside the player just swaps what is playing.
  if (!alreadyFullscreen) {
    unawaited(
      navigator.push(
        PlayerRoute(
          playback: playback,
          aboveNavigation: TabScroll.isTab(context),
        ),
      ),
    );
  }
  await opening;
}

/// Leaves the full-screen player, exactly once.
///
/// [stopPlayback] is the difference between the two ways out: the system back
/// button is done with the video, while the minimise button and the swipe keep
/// it running in the mini player.
///
/// Everything goes through here because more than one thing can ask to close
/// at the same moment — and popping twice would take the home screen with it,
/// leaving a black window.
void closePlayer(BuildContext context, {required bool stopPlayback}) {
  final playback = context.read<PlaybackController>();
  if (!playback.beginClose()) return;

  Navigator.of(context).pop();
  if (stopPlayback) playback.stop();
}

/// Brings the currently playing session back to full screen from the mini
/// player: the video grows out of the mini player's thumbnail.
Future<void> openPlayerFullscreen(
  BuildContext context, {
  required bool aboveNavigation,
}) {
  final playback = context.read<PlaybackController>();
  if (!playback.hasSession || playback.isFullscreen) return Future.value();

  // Starts shrunk onto the mini player, and claims full screen before the
  // route builds, so the first frame already agrees with both.
  playback.morph.value = 1;
  playback.enterFullscreen();
  return Navigator.of(context, rootNavigator: true).push(
    PlayerRoute(
      playback: playback,
      fromMiniPlayer: true,
      aboveNavigation: aboveNavigation,
    ),
  );
}

/// The full-screen player's route.
///
/// It is opaque, so the library underneath is not drawn behind a playing
/// video — except while the player is shrinking into the mini player or
/// growing out of it, when the library has to show through around it.
class PlayerRoute extends PageRoute<void> {
  PlayerRoute({
    required this.playback,
    required this.aboveNavigation,
    this.fromMiniPlayer = false,
  });

  final PlaybackController playback;

  /// Where the mini player is on the page underneath — above the main
  /// navigation bar, or at the bottom of a page opened on top of it. The
  /// player shrinks to exactly there.
  final bool aboveNavigation;

  /// Opened from the mini player: the page grows out of it by itself instead
  /// of fading in.
  final bool fromMiniPlayer;

  /// Set once a swipe or the minimise button has shrunk the player onto the
  /// mini player. The page is already sitting there, so leaving takes no
  /// animation of its own.
  bool minimised = false;

  bool _seeThrough = false;

  set seeThrough(bool value) {
    if (_seeThrough == value) return;
    _seeThrough = value;
    // While a transition runs the route is see-through anyway, and it puts
    // this value back when the transition completes.
    if (animation?.isCompleted ?? false) {
      if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = opaque;
    }
  }

  @override
  bool get opaque => !_seeThrough;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  bool didPop(void result) {
    if (minimised) controller?.reverseDuration = Duration.zero;
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ChangeNotifierProvider.value(value: playback, child: const PlayerPage());

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Growing out of the mini player, or already shrunk onto it, the page
    // animates itself. The same two transitions stay in the tree either way —
    // swapping them out would rebuild the player mid-animation.
    final morphing =
        minimised ||
        (fromMiniPlayer && animation.status != AnimationStatus.reverse);
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: morphing ? kAlwaysCompleteAnimation : curved,
      child: SlideTransition(
        position: morphing
            ? const AlwaysStoppedAnimation(Offset.zero)
            : curved.drive(
                Tween(begin: const Offset(0, 0.12), end: Offset.zero),
              ),
        child: child,
      ),
    );
  }
}

/// What the gesture layer and the minimise button use to shrink the player.
abstract interface class PlayerMorph {
  /// Follows a finger: [progress] 0 is full screen, 1 is the mini player.
  void dragTo(double progress);

  /// Finishes a swipe: glides on into the mini player, or back to full screen.
  void release({required bool minimise});

  /// If the player is gliding after a swipe, stops it where it is and returns
  /// that progress, so a new touch can pick the swipe up; otherwise null.
  double? catchGlide();
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin
    implements PlayerMorph {
  late final PlaybackController _playback;

  late final AnimationController _glide = AnimationController(vsync: this);
  double _glideFrom = 0;
  double _glideTo = 0;

  PlayerRoute? _route;
  Animation<double>? _routeAnimation;
  bool? _immersive;

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlaybackController>();
    _playback.enterFullscreen();
    _playback.dismissDrag.addListener(_updateMorph);
    _glide.addListener(_onGlideTick);

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playback.initSystemLevels();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;

    _routeAnimation?.removeListener(_updateMorph);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _route = route is PlayerRoute ? route : null;
    _routeAnimation = route?.animation;
    _routeAnimation?.addListener(_updateMorph);
    _routeAnimation?.addStatusListener(_onRouteStatus);
    _updateMorph();
  }

  @override
  void dispose() {
    _playback.dismissDrag.removeListener(_updateMorph);
    _routeAnimation?.removeListener(_updateMorph);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _glide.dispose();

    // Playback keeps going: the session moves down into the mini player.
    _playback.exitFullscreen();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) => _updateMorph();

  /// Combines the swipe and the route's own opening into one value, and
  /// keeps everything that depends on it in step.
  void _updateMorph() {
    final route = _route;
    final animation = _routeAnimation;

    // Growing out of the mini player: 1 at the start, 0 when it fills the
    // screen.
    var opening = 0.0;
    if (route != null &&
        route.fromMiniPlayer &&
        animation != null &&
        animation.status == AnimationStatus.forward) {
      opening = 1 - Curves.easeOutCubic.transform(animation.value);
    }
    final held = (route?.minimised ?? false) ? 1.0 : 0.0;
    final value = math.max(
      _playback.dismissDrag.value,
      math.max(opening, held),
    );

    _playback.morph.value = value;
    route?.seeThrough = value > 0;

    // The status and navigation bars come back while the player is small,
    // so the library behind it is laid out exactly as it will be once the
    // player has gone.
    final settled = animation == null || animation.isCompleted;
    _setImmersive(value == 0 && settled);
  }

  void _setImmersive(bool value) {
    if (_immersive == value) return;
    _immersive = value;
    SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  // ------------------------------------------------------------ PlayerMorph
  @override
  void dragTo(double progress) {
    _glide.stop();
    _playback.setDismissDrag(progress);
  }

  @override
  double? catchGlide() {
    if (!_glide.isAnimating || _glideTo == 1) return null;
    _glide.stop();
    return _playback.dismissDrag.value;
  }

  @override
  void release({required bool minimise}) {
    _glideFrom = _playback.dismissDrag.value;
    _glideTo = minimise ? 1 : 0;
    final distance = (_glideTo - _glideFrom).abs();
    _glide.duration = Duration(milliseconds: (140 + 220 * distance).round());
    _glide.forward(from: 0).then((_) {
      if (!mounted || _glideTo != 1) return;
      _route?.minimised = true;
      closePlayer(context, stopPlayback: false);
    });
  }

  void _onGlideTick() {
    final t = Curves.easeOutCubic.transform(_glide.value);
    _playback.setDismissDrag(lerpDouble(_glideFrom, _glideTo, t)!);
  }

  @override
  Widget build(BuildContext context) {
    // Watching the whole controller here would rebuild the entire player tree
    // on every position tick; only these flags change the layout.
    final (locked, isPip, hasSession) = context
        .select<PlaybackController, (bool, bool, bool)>(
          (p) => (p.locked, p.isPip, p.hasSession),
        );

    // The session ended under us — the file was deleted, or the back button
    // already stopped it. Either way the player has nothing left to show.
    if (!hasSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) closePlayer(context, stopPlayback: false);
      });
    }

    // The two ways out of the player mean different things, so the system back
    // button is handled here rather than just popping:
    //   back        — done with this video: stop it and close the session
    //   ⌄ / swipe   — keep watching later: shrink into the mini player
    // Those two pop directly, which does not come through here.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (locked) {
          ScaffoldMessenger.of(context).showSnackBar(
            glassSnackBar(
              content: Text(context.s.screenLocked),
              duration: const Duration(milliseconds: 1400),
            ),
          );
          return;
        }

        // Closes first and stops after, so the screen never sits on a torn
        // down player waiting for the teardown to finish.
        closePlayer(context, stopPlayback: true);
      },
      child: Provider<PlayerMorph>.value(
        value: this,
        child: Scaffold(
          // The black around the video lives in the stage below, where it
          // can fade away as the player shrinks.
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _MorphStage(),
              if (!isPip) ...[
                const GestureLayer(),
                const _FadeWhileMorphing(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [PlayerHud(), PlayerControls()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The controls leave quickly once the player starts to shrink, and ignore
/// touches until it is back.
class _FadeWhileMorphing extends StatelessWidget {
  const _FadeWhileMorphing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    return ValueListenableBuilder<double>(
      valueListenable: playback.morph,
      child: child,
      builder: (context, morph, child) => IgnorePointer(
        ignoring: morph > 0,
        child: Opacity(opacity: (1 - morph * 4).clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

/// The whole player turning into the mini player, following the morph value.
///
/// Three layers move together:
/// * the black page shrinks and reshapes into the mini player's card — its
///   rounded corners, its glass, its lift;
/// * the card's title, buttons and progress track appear inside it as it
///   gets close;
/// * the video travels into the card's thumbnail spot, trimmed to its shape.
///
/// At 1 this is pixel for pixel the real mini player, which takes over when the
/// player closes. Every layer is always in the tree — at rest they do nothing —
/// so nothing is rebuilt when a swipe starts.
class _MorphStage extends StatelessWidget {
  const _MorphStage();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final direction = Directionality.of(context);
    final route = ModalRoute.of(context);
    final aboveNavigation = route is PlayerRoute && route.aboveNavigation;
    // The page underneath lays its bars out with the same inset once the
    // system bars are back, which happens as soon as the player shrinks.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Lands on the mini player's own glass.
    final cardDecoration = AppTheme.frostedBar(
      Theme.of(context),
      AppTheme.cardRadius,
    ).copyWith(boxShadow: context.floatingShadow);
    const fullScreenDecoration = BoxDecoration(color: Colors.black);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final screen = Offset.zero & size;
        final card = MiniPlayer.cardRect(
          size,
          bottomInset: bottomInset,
          aboveNavigation: aboveNavigation,
        );
        final thumbnail = MiniPlayer.thumbnailRect(card, direction);

        return ValueListenableBuilder<double>(
          valueListenable: playback.morph,
          child: const _VideoSurface(),
          builder: (context, morph, video) {
            final t = morph.clamp(0.0, 1.0);

            // The page becoming the card.
            final page = Rect.lerp(screen, card, t)!;
            final decoration = BoxDecoration.lerp(
              fullScreenDecoration,
              cardDecoration,
              t,
            )!;

            // The card's own content only shows up once the shape is close
            // to the card, so it never appears stretched.
            final contentOpacity = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

            // The video travelling into the thumbnail spot.
            final start = _landingRect(playback, screen, thumbnail.size);
            final scale = lerpDouble(1, thumbnail.width / start.width, t)!;
            final center = Offset.lerp(start.center, thumbnail.center, t)!;
            final clip = Rect.lerp(screen, start, t)!;
            final radius =
                lerpDouble(0, MiniPlayer.thumbnailRadius, t)! / scale;
            final transform = Matrix4.identity()
              ..translateByDouble(center.dx, center.dy, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1)
              ..translateByDouble(-start.center.dx, -start.center.dy, 0, 1);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: page,
                  child: DecoratedBox(decoration: decoration),
                ),
                Positioned.fromRect(
                  rect: card,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: contentOpacity,
                      child: const MiniPlayerContent(showThumbnail: false),
                    ),
                  ),
                ),
                Transform(
                  transform: transform,
                  child: ClipRRect(
                    clipper: _RRectClipper(
                      RRect.fromRectAndRadius(clip, Radius.circular(radius)),
                    ),
                    clipBehavior: t == 0 ? Clip.none : Clip.antiAlias,
                    child: video,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The part of the full-screen frame that ends up as the thumbnail: the
  /// picture as it is shown, trimmed to the thumbnail's shape around its
  /// centre.
  static Rect _landingRect(
    PlaybackController playback,
    Rect screen,
    Size thumbnail,
  ) {
    final value = playback.player?.value;
    final videoAspect = (value != null && value.isInitialized)
        ? value.aspectRatio
        : 16 / 9;

    final pictureAspect = switch (playback.videoFit) {
      // These fill the screen, so the whole screen is the picture.
      VideoFit.fill || VideoFit.stretch => screen.width / screen.height,
      VideoFit.ratio16x9 => 16 / 9,
      VideoFit.ratio4x3 => 4 / 3,
      VideoFit.fit || VideoFit.original => videoAspect,
    };

    final picture = _fitInside(screen, pictureAspect);
    return _fitInside(picture, thumbnail.width / thumbnail.height);
  }

  /// The largest rectangle of [aspect] centred inside [outer].
  static Rect _fitInside(Rect outer, double aspect) {
    var width = outer.width;
    var height = width / aspect;
    if (height > outer.height) {
      height = outer.height;
      width = height * aspect;
    }
    return Rect.fromCenter(center: outer.center, width: width, height: height);
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  const _RRectClipper(this.rrect);

  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_RRectClipper oldClipper) => oldClipper.rrect != rrect;
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface();

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the video itself changes — not on every position
    // tick, and not on every frame of a seek gesture.
    final (controller, error) = context
        .select<PlaybackController, (VideoPlayerController?, String?)>(
          (p) => (p.player, p.error),
        );

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.error_outline_rounded,
                color: context.muted,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.muted),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => closePlayer(context, stopPlayback: true),
                child: Text(context.s.goBack),
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(color: context.accent),
        ),
      );
    }

    return const _VideoFrame();
  }
}

/// Sizes the video for the current display mode and applies the pinch zoom.
///
/// The zoom comes from its own notifier, so pinching repaints the frame
/// without rebuilding the controls on top of it.
class _VideoFrame extends StatelessWidget {
  const _VideoFrame();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final (controller, fit) = context
        .select<PlaybackController, (VideoPlayerController?, VideoFit)>(
          (p) => (p.player, p.videoFit),
        );
    if (controller == null) return const SizedBox.shrink();

    final size = controller.value.size;
    final width = size.width == 0 ? 16.0 : size.width;
    final height = size.height == 0 ? 9.0 : size.height;

    Widget ratio(double aspectRatio) => Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(controller),
      ),
    );

    final video = switch (fit) {
      // Whole frame visible; bars where the shapes differ.
      VideoFit.fit => ratio(controller.value.aspectRatio),
      // Covers the screen; whatever does not fit is cropped.
      VideoFit.fill => FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: VideoPlayer(controller),
        ),
      ),
      // Pulled to the screen's shape; nothing cropped.
      VideoFit.stretch => SizedBox.expand(child: VideoPlayer(controller)),
      VideoFit.ratio16x9 => ratio(16 / 9),
      VideoFit.ratio4x3 => ratio(4 / 3),
      // The file's own pixel size, scaled down only if it would not fit.
      // Pixels are divided by the screen density so 1 video pixel is 1
      // physical pixel.
      VideoFit.original => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width / MediaQuery.devicePixelRatioOf(context),
            height: height / MediaQuery.devicePixelRatioOf(context),
            child: VideoPlayer(controller),
          ),
        ),
      ),
    };

    return ClipRect(
      child: ValueListenableBuilder<ZoomState>(
        valueListenable: playback.zoom,
        child: video,
        builder: (context, state, child) {
          if (!state.isZoomed) return child!;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(state.offset.dx, state.offset.dy, 0, 1)
              ..scaleByDouble(state.scale, state.scale, 1, 1),
            child: child,
          );
        },
      ),
    );
  }
}
