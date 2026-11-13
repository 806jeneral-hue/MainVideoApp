import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Listens for media paths delivered to the app from external Android intents
/// (such as "Open with" / "تشغيل باستخدام" or file share).
class ExternalMediaService {
  const ExternalMediaService._();

  static const MethodChannel _channel =
      MethodChannel('main_video/external_media');

  static void Function(String path)? onExternalMediaReceived;
  static bool _wired = false;

  /// Starts listening for incoming media intents pushed while the app is alive.
  static void ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenMedia') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          onExternalMediaReceived?.call(path);
        }
      }
      return null;
    });
  }

  /// Retrieves the media path that launched the app from a cold start (if any).
  static Future<String?> getInitialMedia() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialMedia');
    } catch (_) {
      return null;
    }
  }
}
