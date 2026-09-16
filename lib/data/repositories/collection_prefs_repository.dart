import '../local/app_database.dart';
import '../models/collection_prefs.dart';

/// Per-list sort order and hand-made ordering. Each folder, playlist, the home
/// screen and favourites keep their own, so changing one never disturbs
/// another.
class CollectionPrefsRepository {
  const CollectionPrefsRepository();

  CollectionPrefs? read(CollectionKey key) {
    final map = AppDatabase.collectionPrefs.get(key.value);
    return map == null ? null : CollectionPrefs.fromMap(map);
  }

  Future<void> write(CollectionKey key, CollectionPrefs prefs) =>
      AppDatabase.collectionPrefs.put(key.value, prefs.toMap());

  Future<void> remove(CollectionKey key) =>
      AppDatabase.collectionPrefs.delete(key.value);

  Map<String, CollectionPrefs> all() {
    final out = <String, CollectionPrefs>{};
    for (final key in AppDatabase.collectionPrefs.keys) {
      final map = AppDatabase.collectionPrefs.get(key);
      if (map != null) out[key as String] = CollectionPrefs.fromMap(map);
    }
    return out;
  }

  /// Rewrites every stored manual order after a file is renamed, so the video
  /// keeps its hand-picked position.
  Future<void> rekey(String oldId, String newId) async {
    for (final entry in all().entries) {
      final index = entry.value.manualOrder.indexOf(oldId);
      if (index < 0) continue;
      final order = List<String>.from(entry.value.manualOrder);
      order[index] = newId;
      await AppDatabase.collectionPrefs.put(
        entry.key,
        entry.value.copyWith(manualOrder: order).toMap(),
      );
    }
  }

  /// Drops a deleted video from every stored manual order.
  Future<void> purgeVideo(String videoId) async {
    for (final entry in all().entries) {
      if (!entry.value.manualOrder.contains(videoId)) continue;
      final order = List<String>.from(entry.value.manualOrder)..remove(videoId);
      await AppDatabase.collectionPrefs.put(
        entry.key,
        entry.value.copyWith(manualOrder: order).toMap(),
      );
    }
  }
}
