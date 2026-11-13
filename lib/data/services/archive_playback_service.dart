import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../state/playback_controller.dart';
import '../../ui/common/glass_snack_bar.dart';
import '../../ui/music/now_playing_page.dart';
import '../../ui/player/player_page.dart';
import '../models/song.dart';
import '../models/video.dart';

/// Unpacks and extracts compressed archives (.zip, .tar, .gz, .tgz, .bz2, .xz)
/// containing videos or songs so they can be played immediately.
class ArchivePlaybackService {
  const ArchivePlaybackService._();

  /// Extracts the archive and launches immediate playback for the media found.
  static Future<void> openArchiveAndPlay(
    BuildContext context,
    String path,
  ) async {
    if (!context.mounted || path.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(
        icon: Icons.folder_zip_rounded,
        content: const Text('جاري فك ضغط وتشغيل محتوى الملف المضغوط...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final media = await extractAndGetMedia(path);
    if (!context.mounted) return;

    if (media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        glassSnackBar(
          icon: Icons.info_outline_rounded,
          content: const Text(
            'لم يتم العثور على ملفات فيديو أو صوت داخل الملف المضغوط',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final first = media.first;
    final title = path.split(Platform.pathSeparator).isNotEmpty
        ? path.split(Platform.pathSeparator).last
        : 'Archive';
    if (first.isAudio) {
      final playback = context.read<PlaybackController>();
      await playback.open(queue: media, startIndex: 0, queueTitle: title);
      if (context.mounted) openNowPlaying(context);
    } else {
      final videos = media
          .map((p) => p is Video ? p : Video.fromSong(p as Song))
          .toList();
      await openPlayer(
        context,
        queue: videos,
        startIndex: 0,
        queueTitle: title,
      );
    }
  }

  static const _videoExtensions = {
    '.mp4',
    '.mkv',
    '.webm',
    '.avi',
    '.mov',
    '.3gp',
    '.flv',
    '.ts',
    '.wmv',
    '.m4v',
  };

  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.aac',
    '.opus',
    '.ogg',
    '.wma',
  };

  static const _archiveExtensions = {
    '.zip',
    '.tar',
    '.gz',
    '.tgz',
    '.bz2',
    '.xz',
    '.rar',
    '.7z',
  };

  /// Whether the file at [path] is an archive file.
  static bool isArchive(String path) {
    final lower = path.toLowerCase();
    return _archiveExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Whether the file is a playable media file (video or audio).
  static bool isMedia(String path) {
    final lower = path.toLowerCase();
    return _videoExtensions.any((ext) => lower.endsWith(ext)) ||
        _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Whether the file has an audio extension.
  static bool isAudio(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Extracts media files from a compressed archive and returns them as a
  /// list of [Playable] items (Videos or Songs).
  static Future<List<Playable>> extractAndGetMedia(
    String archivePath, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final file = File(archivePath);
    if (!file.existsSync()) return [];

    final cacheDir = await getTemporaryDirectory();
    final hash = md5
        .convert(utf8.encode(archivePath))
        .toString()
        .substring(0, 10);
    final baseName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'archive';
    final outDir = Directory(
      '${cacheDir.path}/extracted_archives/${hash}_$baseName',
    );
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final lower = archivePath.toLowerCase();
    final playables = <Playable>[];

    onProgress?.call(0.1, 'جاري فحص محتويات الملف المضغوط...');

    try {
      if (lower.endsWith('.zip')) {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final total = archive.files.length;
        var idx = 0;

        for (final entry in archive.files) {
          idx++;
          if (!entry.isFile) continue;
          final name = entry.name;
          final entryLower = name.toLowerCase();

          final isVid = _videoExtensions.any((ext) => entryLower.endsWith(ext));
          final isAud = _audioExtensions.any((ext) => entryLower.endsWith(ext));

          if (isVid || isAud) {
            onProgress?.call(
              (idx / (total > 0 ? total : 1)).clamp(0.2, 0.95),
              'جاري فك ضغط: ${name.split('/').last}',
            );
            final cleanName = name
                .replaceAll('\\', '_')
                .replaceAll('/', '_');
            final extractedFile = File('${outDir.path}/$cleanName');

            if (!extractedFile.existsSync() ||
                extractedFile.lengthSync() != entry.size) {
              final content = entry.content as List<int>;
              extractedFile.writeAsBytesSync(content);
            }

            if (isVid) {
              playables.add(
                Video.fromPath(extractedFile.path, title: cleanName),
              );
            } else {
              playables.add(
                Song.fromPath(extractedFile.path, title: cleanName),
              );
            }
          }
        }
      } else if (lower.endsWith('.tar') ||
          lower.endsWith('.tar.gz') ||
          lower.endsWith('.tgz')) {
        List<int> bytes = await file.readAsBytes();
        if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
          bytes = GZipDecoder().decodeBytes(bytes);
        }
        final archive = TarDecoder().decodeBytes(bytes);
        for (final entry in archive.files) {
          if (!entry.isFile) continue;
          final name = entry.name;
          final entryLower = name.toLowerCase();
          final isVid = _videoExtensions.any((ext) => entryLower.endsWith(ext));
          final isAud = _audioExtensions.any((ext) => entryLower.endsWith(ext));
          if (isVid || isAud) {
            final cleanName = name
                .replaceAll('\\', '_')
                .replaceAll('/', '_');
            final extractedFile = File('${outDir.path}/$cleanName');
            final content = entry.content as List<int>;
            extractedFile.writeAsBytesSync(content);
            if (isVid) {
              playables.add(
                Video.fromPath(extractedFile.path, title: cleanName),
              );
            } else {
              playables.add(
                Song.fromPath(extractedFile.path, title: cleanName),
              );
            }
          }
        }
      } else if (lower.endsWith('.gz')) {
        final bytes = await file.readAsBytes();
        final decompressed = GZipDecoder().decodeBytes(bytes);
        final outName = baseName.replaceAll(
          RegExp(r'\.gz$', caseSensitive: false),
          '',
        );
        final extractedFile = File('${outDir.path}/$outName');
        extractedFile.writeAsBytesSync(decompressed);
        if (_videoExtensions.any((ext) => outName.toLowerCase().endsWith(ext))) {
          playables.add(Video.fromPath(extractedFile.path, title: outName));
        } else if (_audioExtensions.any(
          (ext) => outName.toLowerCase().endsWith(ext),
        )) {
          playables.add(Song.fromPath(extractedFile.path, title: outName));
        }
      }
    } catch (e) {
      // In case of decoding error, return whatever items were decoded
    }

    onProgress?.call(1.0, 'تم الاستخراج بنجاح');
    return playables;
  }
}
