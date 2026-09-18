import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/enums.dart';
import '../../data/models/playable.dart';
import '../../data/models/song.dart';
import '../../state/music_controller.dart';
import '../../state/playback_controller.dart';
import '../../state/settings_controller.dart';
import '../common/glass.dart';
import '../player/widgets/playback_sheets.dart';
import 'widgets/album_art.dart';
import '../../core/theme/app_icons.dart';
import '../common/app_icon.dart';
import 'music_actions.dart';

/// Opens the music player over whatever is on screen. Music keeps playing
/// when it closes; the mini player takes over.
Future<void> openNowPlaying(BuildContext context) {
  final playback = context.read<PlaybackController>();
  if (!playback.hasSession || playback.isFullscreen) return Future.value();
  playback.enterFullscreen();
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(NowPlayingRoute(playback: playback));
}

/// Slides up from the bottom and can be dragged back down.
///
/// Opaque while it simply sits there, so the library underneath is not drawn
/// for nothing; see-through while it is being dragged, so the library shows
/// as it moves away.
class NowPlayingRoute extends PageRoute<void> {
  NowPlayingRoute({required this.playback});

  final PlaybackController playback;

  /// Set when a drag has already carried the page off screen, so closing
  /// needs no animation of its own.
  bool draggedAway = false;

  bool _seeThrough = false;

  set seeThrough(bool value) {
    if (_seeThrough == value) return;
    _seeThrough = value;
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
  Duration get transitionDuration => const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  bool didPop(void result) {
    if (draggedAway) controller?.reverseDuration = Duration.zero;
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ChangeNotifierProvider.value(
    value: playback,
    child: const NowPlayingPage(),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: child,
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _playback;

  /// How far the page has been dragged down, in pixels.
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);
  late final AnimationController _glide = AnimationController(vsync: this);
  double _glideFrom = 0;
  double _glideTo = 0;

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlaybackController>();
    _glide.addListener(() {
      final t = Curves.easeOutCubic.transform(_glide.value);
      _drag.value = lerpDouble(_glideFrom, _glideTo, t)!;
    });
    _drag.addListener(() {
      final route = ModalRoute.of(context);
      if (route is NowPlayingRoute) route.seeThrough = _drag.value > 0;
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _drag.dispose();
    // Music keeps playing; the mini player picks it up.
    _playback.exitFullscreen();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _glide.stop();
    _drag.value = (_drag.value + details.delta.dy).clamp(
      0.0,
      MediaQuery.sizeOf(context).height,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final close =
        velocity > 800 || (velocity > -800 && _drag.value > height * 0.2);

    _glideFrom = _drag.value;
    _glideTo = close ? height : 0;
    final distance = (_glideTo - _glideFrom).abs() / height;
    _glide.duration = Duration(milliseconds: (120 + 240 * distance).round());
    _glide.forward(from: 0).then((_) {
      if (!close || !mounted) return;
      final route = ModalRoute.of(context);
      if (route is NowPlayingRoute) route.draggedAway = true;
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final (item, hasSession) = context
        .select<PlaybackController, (Playable?, bool)>(
          (p) => (p.currentOrNull, p.hasSession),
        );

    // The session ended under us — closed from the notification, or its
    // files went away.
    if (!hasSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    final song = item is Song ? item : null;

    // Light text and dark glass over the cover, in either app theme.
    return Theme(
      data: AppTheme.dark(settings.accent),
      child: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ValueListenableBuilder<double>(
          valueListenable: _drag,
          builder: (context, drag, child) =>
              Transform.translate(offset: Offset(0, drag), child: child),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _Backdrop(song: song),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space24,
                    ),
                    child: song == null
                        ? const SizedBox.shrink()
                        : _Body(song: song),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cover, blurred far enough to read as colour and light, behind
/// everything. It cross-fades when the song changes.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: song == null
                ? const SizedBox.expand()
                : ImageFiltered(
                    key: ValueKey(song.albumKey),
                    imageFilter: ImageFilter.blur(
                      sigmaX: 48,
                      sigmaY: 48,
                      tileMode: TileMode.mirror,
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: AlbumArt(
                        song: song,
                        size: 320,
                        radius: BorderRadius.zero,
                      ),
                    ),
                  ),
          ),
        ),
        // Keeps white text readable on the brightest cover.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x33000000), Color(0xB3000000)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    final playback = context.read<PlaybackController>();
    final queueTitle = context.select<PlaybackController, String>(
      (p) => p.queueTitle,
    );
    final isFavorite = context.select<MusicController, bool>(
      (m) => m.isFavorite(song.id),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Everything under and above the cover takes about this much height;
        // the cover gets what is left, so short screens never overflow.
        const chrome = 390.0;
        final coverSize = constraints.maxWidth.clamp(
          0.0,
          (constraints.maxHeight - chrome).clamp(120.0, double.infinity),
        );

        final page = Column(
          children: [
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                GlassCircleButton(
                  icon: AppIcons.keyboard_arrow_down_rounded,
                  size: 46,
                  iconSize: 28,
                  tooltip: s.minimise,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        s.nowPlaying,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (queueTitle.isNotEmpty)
                        Text(
                          queueTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                GlassCircleButton(
                  icon: AppIcons.queue_music_rounded,
                  size: 46,
                  iconSize: 24,
                  tooltip: s.playingQueue,
                  onTap: () => showQueueSheet(context),
                ),
                const SizedBox(width: AppTheme.space8),
                GlassCircleButton(
                  icon: AppIcons.more_vert_rounded,
                  size: 46,
                  iconSize: 22,
                  tooltip: s.more,
                  onTap: () => showNowPlayingOptions(context, song),
                ),
              ],
            ),
            const Spacer(),
            _Cover(song: song, size: coverSize),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          song.title,
                          key: ValueKey(song.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist.isEmpty ? s.unknownArtist : song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PressScale(
                  child: IconButton(
                    tooltip: isFavorite
                        ? s.removeFromFavorites
                        : s.addToFavorites,
                    onPressed: () {
                      Haptics.light();
                      playback.toggleCurrentFavorite();
                    },
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isFavorite
                            ? AppIcons.favorite_rounded
                            : AppIcons.favorite_border_rounded,
                        key: ValueKey(isFavorite),
                        color: isFavorite
                            ? theme.colorScheme.primary
                            : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            const _SeekBar(),
            const SizedBox(height: AppTheme.space12),
            const _Transport(),
            const SizedBox(height: AppTheme.space20),
            const _BottomActions(),
            const SizedBox(height: AppTheme.space16),
          ],
        );
        // Turned on its side the phone is shorter than the page: it scrolls
        // instead of squeezing the cover away.
        const tallest = chrome + 120;
        if (constraints.maxHeight >= tallest) return page;
        return SingleChildScrollView(
          child: SizedBox(height: tallest, child: page),
        );
      },
    );
  }
}

/// The cover, large, easing back a little while paused.
class _Cover extends StatelessWidget {
  const _Cover({required this.song, required this.size});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);
    final radius = BorderRadius.circular(28);

    Widget cover(bool playing) => AnimatedScale(
      scale: playing ? 1 : 0.9,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: AlbumArt(
            key: ValueKey(song.albumKey),
            song: song,
            size: size,
            radius: radius,
            decodeSize: 640,
          ),
        ),
      ),
    );

    if (controller == null) return cover(true);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          cover(value.isPlaying || value.isBuffering),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);
    if (controller == null) return const SizedBox(height: 56);

    const timeStyle = TextStyle(
      color: Colors.white70,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => ValueListenableBuilder<Duration?>(
        valueListenable: playback.scrubPosition,
        builder: (context, scrub, _) {
          final total = value.duration;
          final position = scrub ?? value.position;
          final maxMs = total.inMilliseconds <= 0
              ? 1.0
              : total.inMilliseconds.toDouble();
          final valueMs = position.inMilliseconds
              .clamp(0, maxMs.round())
              .toDouble();
          final remaining = total - position;

          // Time runs left to right in every language.
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: scrub != null ? 6 : 4,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: scrub != null ? 8 : 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: valueMs,
                    max: maxMs,
                    onChangeStart: (v) =>
                        playback.beginScrub(Duration(milliseconds: v.round())),
                    onChanged: (v) =>
                        playback.updateScrub(Duration(milliseconds: v.round())),
                    onChangeEnd: (_) => playback.endScrub(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Text(Fmt.duration(position), style: timeStyle),
                      const Spacer(),
                      Text(
                        '-${Fmt.duration(remaining.isNegative ? Duration.zero : remaining)}',
                        style: timeStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final playback = context.read<PlaybackController>();
    final (shuffle, loopMode, hasNext, controller) = context
        .select<
          PlaybackController,
          (bool, LoopMode, bool, VideoPlayerController?)
        >((p) => (p.shuffle, p.loopMode, p.hasNext, p.player));

    Widget toggle({
      required IconData icon,
      required bool active,
      required String tooltip,
      required VoidCallback onTap,
    }) => IconButton(
      tooltip: tooltip,
      onPressed: () {
        Haptics.light();
        onTap();
      },
      iconSize: 24,
      icon: Icon(
        icon,
        color: active ? theme.colorScheme.primary : Colors.white70,
      ),
    );

    // Transport keeps its conventional order in Arabic too.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          toggle(
            icon: AppIcons.shuffle_rounded,
            active: shuffle,
            tooltip: s.shuffle,
            onTap: playback.toggleShuffle,
          ),
          IconButton(
            tooltip: s.previous,
            onPressed: playback.previous,
            iconSize: 42,
            color: Colors.white,
            icon: const AppIcon(AppIcons.skip_previous_rounded),
          ),
          PressScale(
            child: controller == null
                ? const _PlayButton(playing: false, onTap: null)
                : ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => _PlayButton(
                      playing: value.isPlaying,
                      onTap: playback.togglePlay,
                    ),
                  ),
          ),
          IconButton(
            tooltip: s.next,
            onPressed: hasNext ? playback.next : null,
            iconSize: 42,
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const AppIcon(AppIcons.skip_next_rounded),
          ),
          toggle(
            icon: loopMode == LoopMode.one
                ? AppIcons.repeat_one_rounded
                : AppIcons.repeat_rounded,
            active: loopMode != LoopMode.off,
            tooltip: switch (loopMode) {
              LoopMode.off => s.repeat,
              LoopMode.all => s.repeatAll,
              LoopMode.one => s.repeatOne,
            },
            onTap: playback.cycleLoopMode,
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 76,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: AppIcon(
              playing ? AppIcons.pause_rounded : AppIcons.play_arrow_rounded,
              key: ValueKey(playing),
              size: 42,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleep timer and speed, quietly at the bottom.
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final (speed, sleepRemaining) = context
        .select<PlaybackController, (double, Duration?)>(
          (p) => (p.speed, p.sleepRemaining),
        );

    Widget chip({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) => PressScale(
      child: GlassPanel(
        radius: AppTheme.pillRadius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTheme.pillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? theme.colorScheme.primary : Colors.white,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active ? theme.colorScheme.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(
          icon: AppIcons.bedtime_outlined,
          label: sleepRemaining == null
              ? s.sleep
              : Fmt.duration(sleepRemaining),
          active: sleepRemaining != null,
          onTap: () => showSleepTimerSheet(context),
        ),
        const SizedBox(width: AppTheme.space12),
        chip(
          icon: AppIcons.speed_rounded,
          label: Fmt.speed(speed),
          active: speed != 1.0,
          onTap: () => showSpeedSheet(context),
        ),
      ],
    );
  }
}
