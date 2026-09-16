package com.mainvideo.main_video

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-Picture support for the player screen (phase 4).
 *
 * Flutter has no built-in API for PiP, so the activity exposes `isPipSupported`
 * and `enterPip`, and pushes `pipChanged` back to Dart whenever the window
 * enters or leaves PiP mode.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "main_video/pip"
    private var channel: MethodChannel? = null

    private val playbackChannelName = "main_video/playback"
    private var playbackChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> result.success(isPipSupported())
                    "enterPip" -> result.success(enterPip())
                    else -> result.notImplemented()
                }
            }
        }

        playbackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            playbackChannelName
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        sendToService(PlaybackService.ACTION_START, call)
                        result.success(true)
                    }

                    "update" -> {
                        sendToService(PlaybackService.ACTION_UPDATE, call)
                        result.success(true)
                    }

                    "stop" -> {
                        startService(
                            Intent(this, PlaybackService::class.java)
                                .setAction(PlaybackService.ACTION_STOP)
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // The notification buttons and audio-focus changes happen natively;
        // playback itself lives in Dart, so they are forwarded there.
        PlaybackService.onAction = { action ->
            runOnUiThread { playbackChannel?.invokeMethod("playbackAction", action) }
        }
    }

    private fun sendToService(action: String, call: io.flutter.plugin.common.MethodCall) {
        val intent = Intent(this, PlaybackService::class.java)
            .setAction(action)
            .putExtra(PlaybackService.EXTRA_TITLE, call.argument<String>("title") ?: "")
            .putExtra(PlaybackService.EXTRA_SUBTITLE, call.argument<String>("subtitle") ?: "")
            .putExtra(PlaybackService.EXTRA_PLAYING, call.argument<Boolean>("playing") ?: false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun isPipSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(): Boolean {
        if (!isPipSupported()) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    /**
     * Leaving the app while a video is playing drops straight into PiP instead
     * of stopping, which is what the user expects from a video player.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        channel?.invokeMethod("userLeaveHint", null)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        channel = null
        playbackChannel?.setMethodCallHandler(null)
        playbackChannel = null
        PlaybackService.onAction = null
        super.onDestroy()
    }
}
