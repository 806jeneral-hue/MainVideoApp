package com.mainvideo.main_video

import android.util.LongSparseArray
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.videoplayer.VideoPlayer
import io.flutter.plugins.videoplayer.VideoPlayerPlugin

/**
 * Makes seeking by swipe look like fast-forwarding instead of jumping.
 *
 * video_player decodes every seek exactly from the keyframe before it, which
 * cannot keep up with a moving finger, so the picture lags and then jumps.
 * While a swipe is seeking, the player is switched into Media3's scrubbing
 * mode, built for exactly this: frequent seeks land on the nearest frame
 * quickly and the picture keeps moving with the finger. Normal exact seeking
 * comes back when the finger lifts.
 *
 * The plugin does not expose its players, so the ExoPlayer is reached through
 * the plugin's own fields; if that ever fails, seeking simply works as before.
 */
class VideoScrubbing(private val engine: FlutterEngine) {

    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "main_video/scrub"
    )

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "setScrubbing") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val playerId = call.argument<Number>("playerId")?.toLong()
            val enabled = call.argument<Boolean>("enabled") ?: false
            val player = playerId?.let { exoPlayerFor(it) }
            if (player != null) {
                try {
                    player.setScrubbingModeEnabled(enabled)
                } catch (e: Throwable) {
                    // Older player without scrubbing mode: nearest keyframe is
                    // the next best thing for a moving finger.
                    player.setSeekParameters(
                        if (enabled) SeekParameters.CLOSEST_SYNC else SeekParameters.EXACT
                    )
                }
            }
            result.success(player != null)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun exoPlayerFor(playerId: Long): ExoPlayer? = try {
        val plugin = engine.plugins.get(VideoPlayerPlugin::class.java) as? VideoPlayerPlugin
        val playersField = VideoPlayerPlugin::class.java.getDeclaredField("videoPlayers")
        playersField.isAccessible = true
        val players = playersField.get(plugin) as? LongSparseArray<*>
        val player = players?.get(playerId) as? VideoPlayer
        val exoField = VideoPlayer::class.java.getDeclaredField("exoPlayer")
        exoField.isAccessible = true
        exoField.get(player) as? ExoPlayer
    } catch (e: Throwable) {
        null
    }
}
