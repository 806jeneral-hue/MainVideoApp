import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song.dart';
import 'permission_service.dart';
import 'video_file_service.dart' show FileOpResult, VideoFileService;

/// Reads the device's songs through the native MediaStore reader.
class MusicService {
  const MusicService._();

  static const MethodChannel _channel = MethodChannel('main_video/music');

  /// Every song on the device, or null if MediaStore could not be read.
  static Future<List<Song>?> querySongs() async {
    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'songs',
      );
      if (raw == null) return const [];
      return raw.map(Song.fromMap).toList(growable: false);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return const [];
    }
  }

  /// The album cover as JPEG bytes at about [size] pixels, or null.
  static Future<Uint8List?> albumArt(Song song, {int size = 300}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('albumArt', {
        'albumId': song.albumId,
        'path': song.path,
        'size': size,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // ------------------------------------------------------------ permission
  /// "Music and audio" on Android 13+; storage covers audio before that.
  static Permission get _permission => Permission.audio;

  static Future<MediaAccess> currentAccess() async {
    if (!Platform.isAndroid) return MediaAccess.granted;
    if (await _permission.isGranted) return MediaAccess.granted;
    // Below Android 13 the audio permission does not exist; storage covers it.
    if (await Permission.storage.isGranted) return MediaAccess.granted;
    if (await _permission.isPermanentlyDenied) {
      return MediaAccess.permanentlyDenied;
    }
    return MediaAccess.denied;
  }

  static Future<MediaAccess> requestAccess() async {
    if (!Platform.isAndroid) return MediaAccess.granted;
    final audio = await _permission.request();
    if (audio.isGranted) return MediaAccess.granted;
    final storage = await Permission.storage.request();
    if (storage.isGranted) return MediaAccess.granted;
    if (audio.isPermanentlyDenied || storage.isPermanentlyDenied) {
      return MediaAccess.permanentlyDenied;
    }
    return MediaAccess.denied;
  }
}

/// Deleting songs from the device.
class MusicFileService {
  const MusicFileService._();

  /// Deletes [song] the same way videos are deleted: silently once "All files
  /// access" has been granted.
  static Future<FileOpResult> delete(Song song) =>
      VideoFileService.deleteMediaFile(
        path: song.path,
        mediaId: '${song.mediaId}',
      );
}
