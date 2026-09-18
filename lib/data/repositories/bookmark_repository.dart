import '../local/app_database.dart';
import '../models/bookmark.dart';

/// Stop markers (one per list) and each video's index of saved moments.
class BookmarkRepository {
  const BookmarkRepository();

  Map<String, StopMarker> allMarkers() {
    final out = <String, StopMarker>{};
    for (final key in AppDatabase.stopMarkers.keys) {
      final marker = StopMarker.fromMap(AppDatabase.stopMarkers.get(key));
      if (marker != null) out[key as String] = marker;
    }
    return out;
  }

  Future<void> putMarker(String list, StopMarker marker) =>
      AppDatabase.stopMarkers.put(list, marker.toMap());

  Future<void> removeMarker(String list) =>
      AppDatabase.stopMarkers.delete(list);

  Map<String, List<Moment>> allMoments() {
    final out = <String, List<Moment>>{};
    for (final key in AppDatabase.moments.keys) {
      final raw = AppDatabase.moments.get(key) ?? const [];
      final list = raw.map(Moment.fromStored).whereType<Moment>().toList()
        ..sort((a, b) => a.ms.compareTo(b.ms));
      if (list.isNotEmpty) out[key as String] = list;
    }
    return out;
  }

  Future<void> putMoments(String videoId, List<Moment> moments) =>
      moments.isEmpty
      ? AppDatabase.moments.delete(videoId)
      : AppDatabase.moments.put(videoId, [for (final m in moments) m.toMap()]);
}
