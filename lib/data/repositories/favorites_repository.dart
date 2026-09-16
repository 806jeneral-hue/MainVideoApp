import '../local/app_database.dart';

/// Favourites are independent of folders (phase 6): a flat set of video paths.
class FavoritesRepository {
  const FavoritesRepository();

  bool isFavorite(String videoId) =>
      AppDatabase.favorites.get(videoId) ?? false;

  Set<String> all() => AppDatabase.favorites.keys.cast<String>().toSet();

  int get count => AppDatabase.favorites.length;

  Future<bool> toggle(String videoId) async {
    if (isFavorite(videoId)) {
      await AppDatabase.favorites.delete(videoId);
      return false;
    }
    await AppDatabase.favorites.put(videoId, true);
    return true;
  }

  Future<void> set(String videoId, bool value) => value
      ? AppDatabase.favorites.put(videoId, true)
      : AppDatabase.favorites.delete(videoId);

  /// Keeps favourites pointing at the right file after a rename.
  Future<void> rekey(String oldId, String newId) async {
    if (!isFavorite(oldId)) return;
    await AppDatabase.favorites.delete(oldId);
    await AppDatabase.favorites.put(newId, true);
  }

  Future<void> remove(String videoId) => AppDatabase.favorites.delete(videoId);

  Future<void> clear() => AppDatabase.favorites.clear();
}
