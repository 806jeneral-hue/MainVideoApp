import '../local/app_database.dart';
import '../models/watch_record.dart';

/// Watch history and resume positions (phases 1, 6 and 7).
class HistoryRepository {
  const HistoryRepository();

  WatchRecord? record(String videoId) {
    final map = AppDatabase.history.get(videoId);
    return map == null ? null : WatchRecord.fromMap(map);
  }

  /// Position to start from, honouring "finished" videos by restarting them.
  int resumePositionMs(String videoId) {
    final r = record(videoId);
    if (r == null || r.isFinished) return 0;
    return r.positionMs;
  }

  Future<void> save({
    required String videoId,
    required int positionMs,
    required int durationMs,
  }) async {
    final record = WatchRecord(
      videoId: videoId,
      positionMs: positionMs,
      durationMs: durationMs,
      lastPlayed: DateTime.now(),
    );
    await AppDatabase.history.put(videoId, record.toMap());
  }

  /// All records, most recently played first.
  List<WatchRecord> recentlyPlayed({int? limit}) {
    final records =
        AppDatabase.history.values
            .map(WatchRecord.fromMap)
            .where((r) => r.videoId.isNotEmpty)
            .toList()
          ..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    if (limit != null && records.length > limit) {
      return records.sublist(0, limit);
    }
    return records;
  }

  Map<String, WatchRecord> asMap() {
    final out = <String, WatchRecord>{};
    for (final key in AppDatabase.history.keys) {
      final map = AppDatabase.history.get(key);
      if (map != null) out[key as String] = WatchRecord.fromMap(map);
    }
    return out;
  }

  Future<void> rekey(String oldId, String newId) async {
    final existing = AppDatabase.history.get(oldId);
    if (existing == null) return;
    await AppDatabase.history.delete(oldId);
    final updated = Map<dynamic, dynamic>.from(existing)..['videoId'] = newId;
    await AppDatabase.history.put(newId, updated);
  }

  Future<void> remove(String videoId) => AppDatabase.history.delete(videoId);

  Future<void> clear() => AppDatabase.history.clear();
}
