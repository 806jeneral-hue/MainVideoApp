import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'data/services/thumbnail_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  // Opens the on-disk thumbnail cache so covers survive restarts instead of
  // being decoded from the video files again on every launch.
  await ThumbnailService.init();
  unawaited(ThumbnailService.trimDisk());
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MainVideoApp());
}
