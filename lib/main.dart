import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'data/services/thumbnail_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thumbnails are small; holding more of them decoded means a long list can
  // be scrolled back through without decoding the same covers again.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 140 << 20;
  await AppDatabase.init();
  // Opens the on-disk thumbnail cache so covers survive restarts instead of
  // being decoded from the video files again on every launch.
  await ThumbnailService.init();
  unawaited(ThumbnailService.trimDisk());
  // Every screen turns with the phone, following the system's own rotation
  // setting.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  runApp(const MainVideoApp());
}
