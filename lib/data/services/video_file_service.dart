import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../models/video.dart';
import 'permission_service.dart';

enum FileOpStatus { success, denied, notFound, failed }

class FileOpResult {
  const FileOpResult(this.status, {this.newPath, this.message});

  final FileOpStatus status;
  final String? newPath;
  final String? message;

  bool get ok => status == FileOpStatus.success;

  static const denied = FileOpResult(
    FileOpStatus.denied,
    message: 'Permission is required to change files on this device.',
  );
}

/// Delete and rename on disk (phase 6).
///
/// Deleting goes through MediaStore so Android shows its own confirmation
/// dialog on modern versions. Renaming touches the file directly, which needs
/// "All files access".
class VideoFileService {
  const VideoFileService._();

  static Future<FileOpResult> delete(Video video) async {
    try {
      final removed = await PhotoManager.editor.deleteWithIds([video.assetId]);
      if (removed.isNotEmpty) return const FileOpResult(FileOpStatus.success);

      // MediaStore refused (or the id was stale) — try the file directly.
      if (!await PermissionService.requestManageStorage()) {
        return FileOpResult.denied;
      }
      final file = File(video.path);
      if (!await file.exists()) {
        return const FileOpResult(FileOpStatus.notFound);
      }
      await file.delete();
      return const FileOpResult(FileOpStatus.success);
    } catch (e) {
      return FileOpResult(FileOpStatus.failed, message: e.toString());
    }
  }

  static Future<FileOpResult> rename(Video video, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const FileOpResult(
        FileOpStatus.failed,
        message: 'The name cannot be empty.',
      );
    }
    if (trimmed.contains(Platform.pathSeparator) || trimmed.contains('/')) {
      return const FileOpResult(
        FileOpStatus.failed,
        message: 'The name cannot contain a slash.',
      );
    }

    if (!await PermissionService.requestManageStorage()) {
      return FileOpResult.denied;
    }

    try {
      final file = File(video.path);
      if (!await file.exists()) {
        return const FileOpResult(FileOpStatus.notFound);
      }

      // Keep the original extension unless the user typed a real one — a name
      // like "Trip 2.0" must not be mistaken for a file extension.
      final extension = _extensionOf(video.title);
      final typed = _extensionOf(trimmed);
      final typedIsExtension =
          typed.isNotEmpty && RegExp(r'^\.[A-Za-z0-9]{2,5}$').hasMatch(typed);
      final finalName = typedIsExtension ? trimmed : '$trimmed$extension';
      final target = '${video.folderPath}${Platform.pathSeparator}$finalName';

      if (target == video.path) {
        return FileOpResult(FileOpStatus.success, newPath: target);
      }
      if (await File(target).exists()) {
        return const FileOpResult(
          FileOpStatus.failed,
          message: 'A file with that name already exists.',
        );
      }

      await file.rename(target);
      await PhotoManager.clearFileCache();
      return FileOpResult(FileOpStatus.success, newPath: target);
    } catch (e) {
      return FileOpResult(FileOpStatus.failed, message: e.toString());
    }
  }

  /// Moves the file into [targetFolder], keeping its name.
  ///
  /// This is a real move on disk, not a copy: the source stops existing, which
  /// is what "move to folder" is expected to mean.
  static Future<FileOpResult> move(Video video, String targetFolder) async {
    if (video.folderPath == targetFolder) {
      return FileOpResult(FileOpStatus.success, newPath: video.path);
    }
    if (!await PermissionService.requestManageStorage()) {
      return FileOpResult.denied;
    }

    try {
      final file = File(video.path);
      if (!await file.exists()) {
        return const FileOpResult(FileOpStatus.notFound);
      }

      final directory = Directory(targetFolder);
      if (!await directory.exists()) {
        return const FileOpResult(
          FileOpStatus.failed,
          message: 'That folder no longer exists.',
        );
      }

      final target = _uniquePath(targetFolder, video.title);
      if (await File(target).exists()) {
        return const FileOpResult(
          FileOpStatus.failed,
          message: 'A file with that name is already there.',
        );
      }

      try {
        await file.rename(target);
      } on FileSystemException {
        // Different volumes (internal storage to SD card) cannot be renamed
        // across, so fall back to copy-then-delete.
        await file.copy(target);
        await file.delete();
      }

      await PhotoManager.clearFileCache();
      return FileOpResult(FileOpStatus.success, newPath: target);
    } catch (e) {
      return FileOpResult(FileOpStatus.failed, message: e.toString());
    }
  }

  /// `clip.mp4` -> `clip (2).mp4` when something is already in the way.
  static String _uniquePath(String folder, String fileName) {
    final sep = Platform.pathSeparator;
    final base = '$folder$sep$fileName';
    if (!File(base).existsSync()) return base;

    final extension = _extensionOf(fileName);
    final stem = extension.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - extension.length);

    for (var n = 2; n < 1000; n++) {
      final candidate = '$folder$sep$stem ($n)$extension';
      if (!File(candidate).existsSync()) return candidate;
    }
    return base;
  }

  static String _extensionOf(String name) {
    final i = name.lastIndexOf('.');
    if (i <= 0 || i == name.length - 1) return '';
    return name.substring(i);
  }
}
