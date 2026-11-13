import 'dart:io';

import 'package:flutter/services.dart';

import '../models/video.dart';

/// Keeps Android's media index in step with files the app changed directly.
class MediaIndex {
  const MediaIndex._();

  static const MethodChannel _channel = MethodChannel('main_video/media_index');

  /// When each video was added to the device, keyed by MediaStore id. Empty
  /// if it cannot be read, so callers keep their own dates.
  static Future<Map<String, DateTime>> videoDatesAdded() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'videoDatesAdded',
      );
      if (raw == null) return const {};
      return {
        for (final entry in raw.entries)
          if (entry.value is num && (entry.value as num) > 0)
            entry.key: DateTime.fromMillisecondsSinceEpoch(
              (entry.value as num).toInt() * 1000,
            ),
      };
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  /// Scans the device for compressed archive files (.zip, .rar, .7z, .tar, .gz)
  /// so they are visible directly inside the video library.
  static Future<List<Video>> scanArchives() async {
    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'scanArchives',
      );
      if (raw == null) return const [];
      final archives = <Video>[];
      for (final map in raw) {
        final path = map['path'] as String?;
        if (path == null || path.isEmpty) continue;
        final title =
            (map['title'] as String?) ??
            path.split(Platform.pathSeparator).last;
        final size = (map['size'] as num?)?.toInt() ?? 0;
        final added = (map['dateAdded'] as num?)?.toInt() ?? 0;
        final mod = (map['dateModified'] as num?)?.toInt() ?? 0;
        final dateAdded = added > 0
            ? DateTime.fromMillisecondsSinceEpoch(added * 1000)
            : DateTime.now();
        final dateModified = mod > 0
            ? DateTime.fromMillisecondsSinceEpoch(mod * 1000)
            : dateAdded;

        archives.add(
          Video(
            id: path,
            assetId: 'archive_$path',
            title: title,
            durationMs: 0,
            sizeBytes: size,
            dateAdded: dateAdded,
            dateModified: dateModified,
            width: 0,
            height: 0,
          ),
        );
      }
      return archives;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> refresh(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('scan', paths);
    } on PlatformException {
      // The index catches up on its own next scan.
    } on MissingPluginException {
      // Running without the native side (tests).
    }
  }
}
