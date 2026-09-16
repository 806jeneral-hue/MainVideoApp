import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Talks to the Android foreground service that keeps audio alive when the
/// screen is off or the app is in the background.
///
/// Without it, "background playback" is only a promise: the player itself keeps
/// going, but Android is free to kill the process at any moment. The service
/// also puts real controls in the notification shade and gives up playback when
/// something else takes audio focus.
class BackgroundAudioService {
  const BackgroundAudioService._();

  static const MethodChannel _channel = MethodChannel('main_video/playback');

  /// Called when the notification buttons are tapped, or when audio focus is
  /// lost to another app: 'toggle', 'next', 'previous', 'pause', 'stop',
  /// 'focusGained'.
  static void Function(String action)? onAction;

  static bool _wired = false;
  static bool _running = false;

  static bool get isRunning => _running;

  static void ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'playbackAction') {
        onAction?.call(call.arguments as String? ?? '');
      }
      return null;
    });
  }

  /// Android 13+ will not show the notification without this, and a foreground
  /// service with no visible notification is a poor citizen.
  static Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    return (await Permission.notification.request()).isGranted;
  }

  static Future<void> start({
    required String title,
    required String subtitle,
    required bool playing,
  }) async {
    if (!Platform.isAndroid) return;
    ensureWired();
    await _invoke('start', title: title, subtitle: subtitle, playing: playing);
    _running = true;
  }

  static Future<void> update({
    required String title,
    required String subtitle,
    required bool playing,
  }) async {
    if (!Platform.isAndroid || !_running) return;
    await _invoke('update', title: title, subtitle: subtitle, playing: playing);
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    _running = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Nothing to do: the service is gone either way.
    } on MissingPluginException {
      // Running without the native side (tests).
    }
  }

  static Future<void> _invoke(
    String method, {
    required String title,
    required String subtitle,
    required bool playing,
  }) async {
    try {
      await _channel.invokeMethod<void>(method, {
        'title': title,
        'subtitle': subtitle,
        'playing': playing,
      });
    } on PlatformException {
      _running = false;
    } on MissingPluginException {
      _running = false;
    }
  }
}
