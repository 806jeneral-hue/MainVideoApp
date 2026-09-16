import 'dart:io';

import 'package:flutter/services.dart';

/// Picture-in-Picture (phase 4).
///
/// Flutter has no PiP API, so the Android activity exposes it over a channel:
/// Dart asks to enter PiP, and the activity reports back when the window
/// enters or leaves PiP and when the user is about to leave the app.
class PipService {
  const PipService._();

  static const MethodChannel _channel = MethodChannel('main_video/pip');

  static void Function(bool inPip)? onPipChanged;
  static void Function()? onUserLeaveHint;

  static bool _wired = false;

  /// Must be called once before the callbacks above can fire.
  static void ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipChanged':
          onPipChanged?.call(call.arguments == true);
        case 'userLeaveHint':
          onUserLeaveHint?.call();
      }
      return null;
    });
  }

  static Future<bool> isSupported() => _invoke('isPipSupported');

  static Future<bool> enterPip() => _invoke('enterPip');

  static Future<bool> _invoke(String method) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
