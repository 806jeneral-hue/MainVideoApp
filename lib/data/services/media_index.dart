import 'package:flutter/services.dart';

/// Keeps Android's media index in step with files the app changed directly.
class MediaIndex {
  const MediaIndex._();

  static const MethodChannel _channel = MethodChannel('main_video/media_index');

  /// Re-reads [paths]: entries for files that are gone are dropped, and new
  /// or moved files are picked up. Silent — no dialog, nothing to wait for.
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
