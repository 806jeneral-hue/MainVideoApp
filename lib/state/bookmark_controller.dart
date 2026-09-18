import 'package:flutter/foundation.dart';

import '../data/models/bookmark.dart';
import '../data/models/collection_prefs.dart';
import '../data/repositories/bookmark_repository.dart';

/// The user's own marks: where they stopped in each list, and the moments
/// they saved inside each video.
///
/// Kept apart from watch history, which records itself: these change only
/// when the user says so.
class BookmarkController extends ChangeNotifier {
  BookmarkController([this._repo = const BookmarkRepository()]) {
    _markers = _repo.allMarkers();
    _moments = _repo.allMoments();
  }

  final BookmarkRepository _repo;
  late Map<String, StopMarker> _markers;
  late Map<String, List<Moment>> _moments;

  /// Two moments closer than this are the same moment.
  static const int _sameMomentMs = 1500;

  // ------------------------------------------------------------ stop markers
  StopMarker? markerFor(CollectionKey list) => _markers[list.value];

  Future<void> setMarker(
    CollectionKey list, {
    required String videoId,
    required int positionMs,
  }) async {
    final marker = StopMarker(
      videoId: videoId,
      positionMs: positionMs < 0 ? 0 : positionMs,
      markedAt: DateTime.now(),
    );
    _markers[list.value] = marker;
    notifyListeners();
    await _repo.putMarker(list.value, marker);
  }

  Future<void> clearMarker(CollectionKey list) async {
    if (_markers.remove(list.value) == null) return;
    notifyListeners();
    await _repo.removeMarker(list.value);
  }

  // ----------------------------------------------------------------- moments
  List<Moment> momentsFor(String videoId) => _moments[videoId] ?? const [];

  /// Adds a moment with an optional note, unless one is already saved within
  /// a second and a half of it. Returns whether anything was added.
  Future<bool> addMoment(String videoId, int ms, {String note = ''}) async {
    final list = List<Moment>.from(momentsFor(videoId));
    if (list.any((m) => (m.ms - ms).abs() < _sameMomentMs)) return false;
    list
      ..add(Moment(ms: ms < 0 ? 0 : ms, note: note.trim()))
      ..sort((a, b) => a.ms.compareTo(b.ms));
    _moments[videoId] = list;
    notifyListeners();
    await _repo.putMoments(videoId, list);
    return true;
  }

  /// Rewrites the note on one saved moment.
  Future<void> setMomentNote(String videoId, int ms, String note) async {
    final list = [
      for (final m in momentsFor(videoId)) m.ms == ms ? m.withNote(note) : m,
    ];
    _moments[videoId] = list;
    notifyListeners();
    await _repo.putMoments(videoId, list);
  }

  Future<void> removeMoment(String videoId, int ms) async {
    final list = List<Moment>.from(momentsFor(videoId))
      ..removeWhere((m) => m.ms == ms);
    if (list.isEmpty) {
      _moments.remove(videoId);
    } else {
      _moments[videoId] = list;
    }
    notifyListeners();
    await _repo.putMoments(videoId, list);
  }

  // ------------------------------------------------------ renames, deletions
  /// Keeps marks pointing at the right file after a rename, and drops them
  /// when the file is gone.
  Future<void> onVideoChanged(String oldId, String? newId) async {
    var changed = false;
    for (final entry in _markers.entries.toList()) {
      if (entry.value.videoId != oldId) continue;
      changed = true;
      if (newId == null) {
        _markers.remove(entry.key);
        await _repo.removeMarker(entry.key);
      } else {
        final moved = entry.value.withVideo(newId);
        _markers[entry.key] = moved;
        await _repo.putMarker(entry.key, moved);
      }
    }
    final moments = _moments.remove(oldId);
    if (moments != null) {
      changed = true;
      await _repo.putMoments(oldId, const []);
      if (newId != null) {
        _moments[newId] = moments;
        await _repo.putMoments(newId, moments);
      }
    }
    if (changed) notifyListeners();
  }
}
