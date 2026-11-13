import '../../data/local/app_database.dart';

/// Manages persisted recent search queries stored in [AppDatabase.settings].
///
/// Keeps up to 10 queries per category (newest first), with duplicates
/// moved to the front.
class RecentSearchesService {
  const RecentSearchesService._();

  static const int maxRecentCount = 10;

  /// Retrieves recent searches for [key] newest first.
  static List<String> getRecent(String key) {
    try {
      final raw = AppDatabase.settings.get(key);
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  /// Adds [query] to the front of recent searches for [key].
  static Future<void> addRecent(String key, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    try {
      final list = getRecent(key).toList();
      list.removeWhere((item) => item.toLowerCase() == q.toLowerCase());
      list.insert(0, q);
      if (list.length > maxRecentCount) {
        list.removeRange(maxRecentCount, list.length);
      }
      await AppDatabase.settings.put(key, list);
    } catch (_) {}
  }

  /// Removes [query] from recent searches for [key].
  static Future<void> removeRecent(String key, String query) async {
    final q = query.trim().toLowerCase();
    try {
      final list = getRecent(key).toList();
      list.removeWhere((item) => item.toLowerCase() == q);
      await AppDatabase.settings.put(key, list);
    } catch (_) {}
  }

  /// Clears all recent searches for [key].
  static Future<void> clearRecent(String key) async {
    try {
      await AppDatabase.settings.put(key, <String>[]);
    } catch (_) {}
  }
}

