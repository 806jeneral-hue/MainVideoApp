import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks the picture used behind the app and keeps a private copy of it.
///
/// The copy lives in the app's own storage, so the background survives the
/// original being moved or deleted from the gallery. The system photo picker
/// needs no storage permission, and nothing leaves the device.
class BackgroundImageService {
  const BackgroundImageService._();

  static Future<Directory> _folder() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/background');
  }

  /// Returns the stored copy's path, or null if nothing was picked.
  static Future<String?> pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // A background is always blurred and never needs more than the screen.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final folder = await _folder();
    if (await folder.exists()) await folder.delete(recursive: true);
    await folder.create(recursive: true);

    // A new name every time, so the image cache never serves the old picture.
    final extension = picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.jpg';
    final target =
        '${folder.path}/bg_${DateTime.now().millisecondsSinceEpoch}$extension';
    await File(picked.path).copy(target);
    return target;
  }

  static Future<void> clear() async {
    final folder = await _folder();
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
