import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

enum MediaAccess { granted, limited, denied, permanentlyDenied }

/// Storage / media permissions (phase 1).
///
/// Reading the library goes through photo_manager, which asks for the right
/// permission per Android version by itself. Renaming and deleting a file on
/// disk needs the broader "All files access", so that one is only requested
/// at the moment the user actually tries it.
class PermissionService {
  const PermissionService._();

  static Future<MediaAccess> requestMediaAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    if (state == PermissionState.authorized) return MediaAccess.granted;
    if (state == PermissionState.limited) return MediaAccess.limited;

    // Fall back to permission_handler in case the plugin could not decide.
    if (Platform.isAndroid) {
      if (await Permission.videos.request().isGranted) {
        return MediaAccess.granted;
      }
      final storage = await Permission.storage.request();
      if (storage.isGranted) return MediaAccess.granted;
      if (storage.isPermanentlyDenied) return MediaAccess.permanentlyDenied;
    }

    return state == PermissionState.restricted
        ? MediaAccess.permanentlyDenied
        : MediaAccess.denied;
  }

  static Future<MediaAccess> currentMediaAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
    return switch (state) {
      PermissionState.authorized => MediaAccess.granted,
      PermissionState.limited => MediaAccess.limited,
      PermissionState.restricted => MediaAccess.permanentlyDenied,
      _ => MediaAccess.denied,
    };
  }

  /// "All files access" — required to rename a file in place on Android 11+.
  static Future<bool> hasManageStorage() async {
    if (!Platform.isAndroid) return true;
    return Permission.manageExternalStorage.isGranted;
  }

  static Future<bool> requestManageStorage() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}
