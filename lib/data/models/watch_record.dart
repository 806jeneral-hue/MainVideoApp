/// One entry of the watch history: where the user stopped in a video and when.
class WatchRecord {
  const WatchRecord({
    required this.videoId,
    required this.positionMs,
    required this.durationMs,
    required this.lastPlayed,
  });

  final String videoId;
  final int positionMs;
  final int durationMs;
  final DateTime lastPlayed;

  /// 0..1 — how far into the video the user got.
  double get progress {
    if (durationMs <= 0) return 0;
    final p = positionMs / durationMs;
    return p.clamp(0.0, 1.0);
  }

  /// Treated as watched-to-the-end, so playback restarts from zero.
  bool get isFinished => durationMs > 0 && positionMs >= durationMs - 5000;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'lastPlayed': lastPlayed.millisecondsSinceEpoch,
  };

  factory WatchRecord.fromMap(Map<dynamic, dynamic> map) => WatchRecord(
    videoId: map['videoId'] as String? ?? '',
    positionMs: map['positionMs'] as int? ?? 0,
    durationMs: map['durationMs'] as int? ?? 0,
    lastPlayed: DateTime.fromMillisecondsSinceEpoch(
      map['lastPlayed'] as int? ?? 0,
    ),
  );
}
