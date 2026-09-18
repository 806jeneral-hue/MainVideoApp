/// Where the user stopped in one list: which video, and how far into it.
///
/// Each list — the home screen, every folder, every playlist — keeps its own,
/// so marking a place in one series never moves the mark in another.
class StopMarker {
  const StopMarker({
    required this.videoId,
    required this.positionMs,
    required this.markedAt,
  });

  final String videoId;
  final int positionMs;
  final DateTime markedAt;

  Duration get position => Duration(milliseconds: positionMs);

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'positionMs': positionMs,
    'markedAt': markedAt.millisecondsSinceEpoch,
  };

  static StopMarker? fromMap(Map<dynamic, dynamic>? map) {
    final id = map?['videoId'];
    if (id is! String) return null;
    return StopMarker(
      videoId: id,
      positionMs: (map!['positionMs'] as num?)?.toInt() ?? 0,
      markedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['markedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  StopMarker withVideo(String id) =>
      StopMarker(videoId: id, positionMs: positionMs, markedAt: markedAt);
}

/// One saved moment inside a video: where it is, and what the user wrote
/// about it, if anything.
class Moment {
  const Moment({required this.ms, this.note = ''});

  final int ms;
  final String note;

  Duration get position => Duration(milliseconds: ms);

  Map<String, dynamic> toMap() => {'ms': ms, if (note.isNotEmpty) 'note': note};

  /// Reads both the plain numbers the first version stored and the maps with
  /// a note that came after.
  static Moment? fromStored(Object? raw) {
    if (raw is num) return Moment(ms: raw.toInt());
    if (raw is Map) {
      final ms = raw['ms'];
      if (ms is! num) return null;
      final note = raw['note'];
      return Moment(ms: ms.toInt(), note: note is String ? note : '');
    }
    return null;
  }

  Moment withNote(String value) => Moment(ms: ms, note: value.trim());
}
