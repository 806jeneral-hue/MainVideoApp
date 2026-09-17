import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../models/video.dart';
import 'media_index.dart';

/// Reads every video on the device through MediaStore (phase 1).
///
/// The whole library is read from the single "all" album and then grouped by
/// the real directory each file lives in, so no folder is missed the way it
/// would be if only the first album were read.
class MediaScanner {
  const MediaScanner._();

  /// How many file handles are resolved at once. Keeps the platform channel
  /// busy without flooding it on devices with thousands of videos.
  static const int _batchSize = 48;

  /// Scans the device, handing each finished batch to [onBatch] as it lands so
  /// the UI can show videos while the rest are still being read.
  static Future<List<Video>> scan({
    void Function(int done, int total)? onProgress,
    void Function(List<Video> batch)? onBatch,
  }) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(needTitle: true),
        createTimeCond: DateTimeCond.def().copyWith(ignore: true),
        updateTimeCond: DateTimeCond.def().copyWith(ignore: true),
      ),
    );
    if (albums.isEmpty) return const [];

    final all = albums.first;
    final total = await all.assetCountAsync;
    if (total == 0) return const [];

    final added = await MediaIndex.videoDatesAdded();
    final videos = <Video>[];
    var done = 0;

    for (var start = 0; start < total; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, total);
      final assets = await all.getAssetListRange(start: start, end: end);
      final resolved = await Future.wait(
        assets.map((asset) => _toVideo(asset, added)),
      );

      final batch = <Video>[];
      for (final v in resolved) {
        if (v != null) batch.add(v);
      }
      videos.addAll(batch);
      done += assets.length;
      onBatch?.call(batch);
      onProgress?.call(done, total);
    }

    return videos;
  }

  /// [added] holds when each file arrived on the device; the asset's own
  /// creation date is when it was filmed, which is wrong for anything copied,
  /// downloaded or unzipped later.
  static Future<Video?> _toVideo(
    AssetEntity asset,
    Map<String, DateTime> added,
  ) async {
    try {
      final file = await asset.originFile ?? await asset.file;
      if (file == null) return null;

      final path = file.path;
      final name = path.split(Platform.pathSeparator).last;
      var size = 0;
      try {
        size = await file.length();
      } catch (_) {
        // A file that vanished between the MediaStore query and now.
        return null;
      }

      return Video(
        id: path,
        assetId: asset.id,
        title: asset.title?.isNotEmpty == true ? asset.title! : name,
        durationMs: asset.duration * 1000,
        sizeBytes: size,
        dateAdded: added[asset.id] ?? asset.createDateTime,
        dateModified: asset.modifiedDateTime,
        width: asset.width,
        height: asset.height,
      );
    } catch (_) {
      return null;
    }
  }

  /// How many videos MediaStore currently knows about — one cheap query used
  /// to notice that something was added or removed behind the app's back.
  static Future<int> countVideos() async {
    final album = await _allAlbum();
    if (album == null) return 0;
    return album.assetCountAsync;
  }

  /// Only the videos created after [since].
  ///
  /// This is the incremental path: recording a clip or downloading one is
  /// picked up without re-reading the whole device.
  static Future<List<Video>> scanSince(DateTime since) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(needTitle: true),
        createTimeCond: DateTimeCond(min: since, max: DateTime.now()),
        updateTimeCond: DateTimeCond.def().copyWith(ignore: true),
      ),
    );
    if (albums.isEmpty) return const [];

    final album = albums.first;
    final total = await album.assetCountAsync;
    if (total == 0) return const [];

    final added = await MediaIndex.videoDatesAdded();
    final videos = <Video>[];
    for (var start = 0; start < total; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, total);
      final assets = await album.getAssetListRange(start: start, end: end);
      final resolved = await Future.wait(
        assets.map((asset) => _toVideo(asset, added)),
      );
      for (final v in resolved) {
        if (v != null) videos.add(v);
      }
    }
    return videos;
  }

  static Future<AssetPathEntity?> _allAlbum() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(needTitle: true),
        createTimeCond: DateTimeCond.def().copyWith(ignore: true),
        updateTimeCond: DateTimeCond.def().copyWith(ignore: true),
      ),
    );
    return albums.isEmpty ? null : albums.first;
  }

  /// Clears photo_manager's internal caches so a rescan sees new files.
  static Future<void> invalidateCache() => PhotoManager.clearFileCache();
}
