import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/song.dart';
import '../../data/models/video.dart';
import '../../state/bookmark_controller.dart';
import '../../state/library_controller.dart';
import '../../state/music_controller.dart';
import '../music/music_actions.dart';
import '../player/player_page.dart';
import 'play_plan_page.dart';
import 'quick_menu.dart';

/// The quick menus that open from a long press: ways to start a list playing
/// — from its mark, as a custom session, shuffled or in order — and, on the
/// Home button, picking up the last video watched.

/// Opens the custom session editor for a list of videos.
void openVideoPlan(
  BuildContext context, {
  required CollectionKey collection,
  required List<Video> videos,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayPlanPage(
        planKey: collection.value,
        items: videos,
        title: title,
        countLabel: context.s.videoCount,
        onStart: (queue, plays) => openPlayer(
          context,
          queue: queue.cast<Video>(),
          startIndex: 0,
          queueTitle: title,
          shuffle: false,
          collection: collection,
          plays: plays,
        ),
      ),
    ),
  );
}

/// Opens the custom session editor for a list of songs.
void openSongPlan(
  BuildContext context, {
  required String planKey,
  required List<Song> songs,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayPlanPage(
        planKey: planKey,
        items: songs,
        title: title,
        countLabel: context.s.songCount,
        onStart: (queue, plays) => playSongs(
          context,
          queue.cast<Song>(),
          shuffle: false,
          title: title,
          plays: plays,
        ),
      ),
    ),
  );
}

/// "Last time: 3 videos · 6 plays", when the list has a saved session.
String? _lastPlanLine(
  BuildContext context,
  String planKey,
  String Function(int) countLabel,
) {
  final plan = PlayPlanPage.lastPlan(planKey);
  if (plan.isEmpty) return null;
  return context.s.planLast(countLabel(plan.entries.length), plan.totalPlays);
}

/// A folder's, playlist's or the home list's play choices.
List<QuickMenuAction> videoPlayActions(
  BuildContext context, {
  required CollectionKey collection,
  required List<Video> videos,
  required String title,
  bool includeInOrder = true,
}) {
  final s = context.s;
  final marker = context.read<BookmarkController>().markerFor(collection);
  final markedIndex = marker == null
      ? -1
      : videos.indexWhere((v) => v.id == marker.videoId);

  return [
    if (markedIndex >= 0)
      QuickMenuAction(
        icon: AppIcons.bookmark_rounded,
        label: s.continueFromMark,
        subtitle:
            '${videos[markedIndex].displayName} · ${Fmt.duration(marker!.position)}',
        highlighted: true,
        onTap: () => openPlayer(
          context,
          queue: videos,
          startIndex: markedIndex,
          queueTitle: title,
          collection: collection,
          startAt: marker.position,
        ),
      ),
    QuickMenuAction(
      icon: AppIcons.checklist_rounded,
      label: s.planTitle,
      subtitle: _lastPlanLine(context, collection.value, s.videoCount),
      onTap: () => openVideoPlan(
        context,
        collection: collection,
        videos: videos,
        title: title,
      ),
    ),
    QuickMenuAction(
      icon: AppIcons.shuffle_rounded,
      label: s.playShuffled,
      onTap: () => openPlayer(
        context,
        queue: videos,
        startIndex: 0,
        queueTitle: title,
        shuffle: true,
        collection: collection,
      ),
    ),
    if (includeInOrder)
      QuickMenuAction(
        icon: AppIcons.play_arrow_rounded,
        label: s.playInOrder,
        onTap: () => openPlayer(
          context,
          queue: videos,
          startIndex: 0,
          queueTitle: title,
          shuffle: false,
          collection: collection,
        ),
      ),
  ];
}

/// Holding the Home button: the home list's mark, the last video watched,
/// and the home list played as a custom session or shuffled.
void showHomeQuickMenu(BuildContext context, Rect anchor) {
  final library = context.read<LibraryController>();
  final s = context.s;
  final videos = library.homeVideos;
  if (videos.isEmpty) return;

  final recent = library.recentlyPlayed;
  final last = recent.isEmpty ? null : recent.first;
  final lastIndex = last == null
      ? -1
      : videos.indexWhere((v) => v.id == last.id);
  final resumeMs = last == null ? 0 : library.resumePositionMs(last.id);

  final play = videoPlayActions(
    context,
    collection: CollectionKey.home,
    videos: videos,
    title: s.allVideos,
    includeInOrder: false,
  );

  showQuickMenu(
    context,
    anchor: anchor,
    actions: [
      // The mark first, when there is one.
      ...play.where((a) => a.highlighted),
      if (last != null)
        QuickMenuAction(
          icon: AppIcons.history_rounded,
          label: s.continueLastVideo,
          subtitle:
              '${last.displayName} · ${Fmt.duration(Duration(milliseconds: resumeMs))}',
          onTap: () => openPlayer(
            context,
            queue: lastIndex >= 0 ? videos : [last],
            startIndex: lastIndex >= 0 ? lastIndex : 0,
            queueTitle: s.allVideos,
            collection: CollectionKey.home,
          ),
        ),
      ...play.where((a) => !a.highlighted),
    ],
  );
}

/// A list of songs' play choices: a custom session, shuffled, in order.
List<QuickMenuAction> songPlayActions(
  BuildContext context, {
  required String planKey,
  required List<Song> songs,
  required String title,
}) {
  final s = context.s;
  return [
    QuickMenuAction(
      icon: AppIcons.checklist_rounded,
      label: s.planTitle,
      subtitle: _lastPlanLine(context, planKey, s.songCount),
      onTap: () =>
          openSongPlan(context, planKey: planKey, songs: songs, title: title),
    ),
    QuickMenuAction(
      icon: AppIcons.shuffle_rounded,
      label: s.playShuffled,
      onTap: () => playSongs(context, songs, shuffle: true, title: title),
    ),
    QuickMenuAction(
      icon: AppIcons.play_arrow_rounded,
      label: s.playInOrder,
      onTap: () => playSongs(context, songs, shuffle: false, title: title),
    ),
  ];
}

/// Holding the Music button: the last song, and every song as a custom
/// session or shuffled.
void showMusicQuickMenu(BuildContext context, Rect anchor) {
  final music = context.read<MusicController>();
  final s = context.s;
  final songs = music.songs;
  if (songs.isEmpty) return;
  final recent = music.recentlyPlayed;

  showQuickMenu(
    context,
    anchor: anchor,
    actions: [
      if (recent.isNotEmpty)
        QuickMenuAction(
          icon: AppIcons.history_rounded,
          label: s.continueLastSong,
          subtitle: recent.first.title,
          highlighted: true,
          onTap: () => playSongs(
            context,
            recent,
            shuffle: false,
            title: s.recentlyPlayedSongs,
          ),
        ),
      ...songPlayActions(
        context,
        planKey: 'music:all',
        songs: songs,
        title: s.songs,
      ).where((a) => a.label != s.playInOrder),
    ],
  );
}
