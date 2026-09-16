import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the system media card shows for the current video.
class NowPlaying {
  const NowPlaying({
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
    required this.favorite,
    required this.color,
    this.artwork,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool favorite;

  /// The app's accent, used where Android lets an app colour its card.
  final Color color;

  /// The thumbnail. Null leaves the picture already shown; empty clears it.
  final Uint8List? artwork;

  Map<String, Object?> toArguments() => {
    'title': title,
    'subtitle': subtitle,
    'playing': playing,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'speed': speed,
    'favorite': favorite,
    'color': color.toARGB32(),
    'artwork': ?artwork,
  };
}

/// Talks to the Android foreground service that keeps audio alive when the
/// screen is off or the app is in the background, and that publishes the
/// media card in the notification shade and on the lock screen.
///
/// Without it, "background playback" is only a promise: the player itself keeps
/// going, but Android is free to kill the process at any moment.
class BackgroundAudioService {
  const BackgroundAudioService._();

  static const MethodChannel _channel = MethodChannel('main_video/playback');

  /// Called when a media button is pressed — in the notification, on the lock
  /// screen or on a headset: 'toggle', 'play', 'pause', 'next', 'previous',
  /// 'favorite', 'stop', or `seek:<milliseconds>`.
  static void Function(String action)? onAction;

  static bool _wired = false;
  static bool _running = false;

  static bool get isRunning => _running;

  static void ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'playbackAction') {
        final action = call.arguments as String? ?? '';
        // The card was closed from the shade: the service is gone.
        if (action == 'stop') _running = false;
        onAction?.call(action);
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

  /// Starts the service, or updates it if it is already running.
  static Future<void> show(NowPlaying nowPlaying) async {
    if (!Platform.isAndroid) return;
    ensureWired();
    try {
      await _channel.invokeMethod<void>(
        _running ? 'update' : 'start',
        nowPlaying.toArguments(),
      );
      _running = true;
    } on PlatformException {
      _running = false;
    } on MissingPluginException {
      // Running without the native side (tests).
      _running = false;
    }
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
}
