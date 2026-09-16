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
                    // One path for both: a running service is updated in
                    // place, otherwise it is started with this state.
                    "start", "update" -> {
                        showNowPlaying(call)
                        result.success(true)
                    }

                    "stop" -> {
                        PlaybackService.instance?.shutdown()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // The notification, lock-screen and headset buttons are pressed
        // natively; playback itself lives in Dart, so they are forwarded there.
        PlaybackService.onAction = { action ->
            runOnUiThread { playbackChannel?.invokeMethod("playbackAction", action) }
        }
    }

    private fun showNowPlaying(call: io.flutter.plugin.common.MethodCall) {
        val state = PlaybackService.NowPlaying(
            title = call.argument<String>("title") ?: "",
            subtitle = call.argument<String>("subtitle") ?: "",
            playing = call.argument<Boolean>("playing") ?: false,
            positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L,
            durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L,
            speed = call.argument<Number>("speed")?.toFloat() ?: 1f,
            favorite = call.argument<Boolean>("favorite") ?: false,
            color = call.argument<Number>("color")?.toInt() ?: 0xFF2E7A6C.toInt(),
        )
        // Absent means the picture has not changed since the last call.
        val artwork = call.argument<ByteArray>("artwork")

        // Updating the running service directly, rather than through another
        // start intent, is what keeps the play/pause icon in step even while
        // the app is in the background.
        val running = PlaybackService.instance
        if (running != null) {
            running.apply(state, artwork)
            return
        }

        PlaybackService.pendingState = state
        PlaybackService.pendingArtwork = artwork
        val intent = Intent(this, PlaybackService::class.java)
            .setAction(PlaybackService.ACTION_START)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: RuntimeException) {
            // Android refused to start it from the background; the next update
            // made while the app is open starts it.
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
