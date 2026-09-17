/// Anything the one playback session can play: a video or a song.
///
/// The player, the mini player and the media notification only need these
/// few things, which is what lets music and video share a single session —
/// starting a song stops a video and the other way round.
abstract interface class Playable {
  /// The absolute path; stable across rescans.
  String get id;
  String get path;

  /// What lists and the player show as the name.
  String get displayName;

  /// The second line: the folder for a video, the artist for a song.
  String get subtitle;

  int get durationMs;

  /// Songs get the music player and album art; videos get the video player.
  bool get isAudio;
}
