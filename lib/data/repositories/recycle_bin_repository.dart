import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../local/app_database.dart';
import '../models/trashed_video.dart';
import '../models/video.dart';
import '../services/permission_service.dart';

/// The recycle bin.
///
/// Deleting with the bin switched on moves the file into the app's own private
/// folder rather than erasing it: it disappears from the gallery and from every
/// other app, but it is still on the device until the bin is emptied or the
/// keep-for period runs out.
///
/// Restoring puts the file back at the exact path it came from.
class RecycleBinRepository {
  const RecycleBinRepository();

  static Directory? _dir;

  /// App-private storage, so nothing here is indexed by MediaStore.
  static Future<Directory> _binDirectory() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}recycle_bin');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  List<TrashedVideo> all() {
    final items = AppDatabase.recycleBin.values
        .map(TrashedVideo.fromMap)
        .toList();
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  int get count => AppDatabase.recycleBin.length;

  /// Moves a video into the bin. Returns null on success, or why it failed.
  Future<String?> moveToBin(Video video) async {
    try {
      final source = File(video.path);
      if (!await source.exists()) return 'The file no longer exists';

      if (!await PermissionService.requestManageStorage()) {
        return 'Permission is required to move files on this device.';
      }

      final dir = await _binDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final target =
          '${dir.path}${Platform.pathSeparator}${stamp}_${video.title}';

      await _move(source, target);

      await AppDatabase.recycleBin.put(
        video.id,
        TrashedVideo(
          id: video.id,
          originalPath: video.path,
          binPath: target,
          title: video.title,
          durationMs: video.durationMs,
          sizeBytes: video.sizeBytes,
          deletedAt: DateTime.now(),
        ).toMap(),
      );

      // The gallery still lists the old location until MediaStore is told.
      await _forgetInMediaStore(video);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Puts a video back where it came from. Returns null on success.
  Future<String?> restore(TrashedVideo item) async {
    try {
      final source = File(item.binPath);
      if (!await source.exists()) {
        await AppDatabase.recycleBin.delete(item.id);
        return 'The file is no longer in the bin';
      }

      if (!await PermissionService.requestManageStorage()) {
        return 'Permission is required to move files on this device.';
      }

      final folder = Directory(item.originalFolder);
      if (!await folder.exists()) await folder.create(recursive: true);

      // Something else may have taken the name while it was away.
      final target = await _freePath(item.originalPath);
      await _move(source, target);
      await AppDatabase.recycleBin.delete(item.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Erases one item for good.
  Future<String?> deleteForever(TrashedVideo item) async {
    try {
      final file = File(item.binPath);
      if (await file.exists()) await file.delete();
      await AppDatabase.recycleBin.delete(item.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> empty() async {
    for (final item in all()) {
      await deleteForever(item);
    }
  }

  /// Drops anything that has been in the bin longer than [keepDays].
  Future<int> purgeExpired(int keepDays) async {
    var removed = 0;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    for (final item in all()) {
      if (item.deletedAt.isAfter(cutoff)) continue;
      await deleteForever(item);
      removed++;
    }
    return removed;
  }

  /// `rename` fails across volumes (internal storage to SD card), so fall back
  /// to copying and then removing the original.
  static Future<void> _move(File source, String target) async {
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
  }

  static Future<String> _freePath(String wanted) async {
    if (!await File(wanted).exists()) return wanted;

    final dot = wanted.lastIndexOf('.');
    final stem = dot <= 0 ? wanted : wanted.substring(0, dot);
    final ext = dot <= 0 ? '' : wanted.substring(dot);

    for (var i = 1; i < 1000; i++) {
      final candidate = '$stem ($i)$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return '$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
  }

  /// Best effort: the file is already gone from its old path, this just stops
  /// the gallery showing a dead entry.
  static Future<void> _forgetInMediaStore(Video video) async {
    try {
      await PhotoManager.editor.deleteWithIds([video.assetId]);
    } catch (_) {
      // MediaStore will drop the stale row on its next scan anyway.
    }
  }
}
