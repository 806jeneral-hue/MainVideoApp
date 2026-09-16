import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../../state/playback_controller.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/player_controls.dart';
import 'widgets/player_hud.dart';

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
    unawaited(_pushFullscreen(navigator, playback));
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

/// Brings the currently playing session back to full screen — used by the
/// mini player.
Future<void> openPlayerFullscreen(BuildContext context) {
  final playback = context.read<PlaybackController>();
  if (!playback.hasSession || playback.isFullscreen) return Future.value();
  return _pushFullscreen(Navigator.of(context, rootNavigator: true), playback);
}

Future<void> _pushFullscreen(
  NavigatorState navigator,
  PlaybackController playback,
) {
  return navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
        value: playback,
        child: const PlayerPage(),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlaybackController _playback;

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlaybackController>();
    _playback.enterFullscreen();

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playback.initSystemLevels();
    });
  }

  @override
  void dispose() {
    // Playback keeps going: the session moves down into the mini player.
    _playback.exitFullscreen();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
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
            SnackBar(
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
      child: _DismissTransition(
        child: Scaffold(
          // Every control now sits on its own glass panel and takes its
          // colours from the theme, so the area around the video can be the
          // app's own page colour rather than a forced black.
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _VideoSurface(),
              if (!isPip) ...[
                const GestureLayer(),
                const PlayerHud(),
                const PlayerControls(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shrinks and slides the player down as the minimise swipe progresses, so the
/// gesture visibly heads towards the mini player instead of jumping.
class _DismissTransition extends StatelessWidget {
  const _DismissTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final size = MediaQuery.sizeOf(context);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ValueListenableBuilder<double>(
        valueListenable: playback.dismissDrag,
        // The child is built once and only transformed, so a drag costs a
        // repaint rather than a rebuild of the player.
        child: child,
        builder: (context, drag, child) {
          if (drag == 0) return child!;
          return Transform.translate(
            offset: Offset(0, drag * size.height * 0.16),
            child: Transform.scale(scale: 1 - drag * 0.12, child: child),
          );
        },
      ),
    );
  }
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
              Icon(Icons.error_outline_rounded, color: context.muted, size: 40),
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
    final video = switch (fit) {
      // Whole frame visible; bars where the shapes differ.
      VideoFit.fit => Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
      // Covers the screen; whatever does not fit is cropped.
      VideoFit.fill => FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width == 0 ? 16 : size.width,
          height: size.height == 0 ? 9 : size.height,
          child: VideoPlayer(controller),
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
