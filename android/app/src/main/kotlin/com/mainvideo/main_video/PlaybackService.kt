package com.mainvideo.main_video

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.media.ThumbnailUtils
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import android.widget.RemoteViews

/**
 * Keeps audio playing when the screen is off or the app is in the background,
 * and publishes it to the system as a media session.
 *
 * The session drives the media controls in quick settings and on the lock
 * screen -- thumbnail, live seek bar, previous / play-pause / next, favourite
 * and close -- and lets headset and Bluetooth buttons control playback. The
 * notification itself is the app's own card, styled like its mini player.
 *
 * The service does not own the player. Playback lives in Dart; this shows what
 * Dart reports and forwards every button press back to it.
 *
 * It deliberately does not take audio focus. ExoPlayer already holds focus for
 * the video; a second request from here made the two steal it from each other,
 * so a newly opened video was silently paused and the first press of play was
 * undone.
 */
class PlaybackService : Service() {

    /** Everything the notification shows, as last reported by Dart. */
    data class NowPlaying(
        val title: String = "",
        val subtitle: String = "",
        val playing: Boolean = false,
        val positionMs: Long = 0,
        val durationMs: Long = 0,
        val speed: Float = 1f,
        val favorite: Boolean = false,
        val color: Int = 0xFF2E7A6C.toInt(),
    )

    companion object {
        const val ACTION_START = "com.mainvideo.main_video.START"
        const val ACTION_STOP = "com.mainvideo.main_video.STOP"

        const val ACTION_TOGGLE = "com.mainvideo.main_video.TOGGLE"
        const val ACTION_NEXT = "com.mainvideo.main_video.NEXT"
        const val ACTION_PREVIOUS = "com.mainvideo.main_video.PREVIOUS"
        const val ACTION_FAVORITE = "com.mainvideo.main_video.FAVORITE"
        const val ACTION_CLOSE = "com.mainvideo.main_video.CLOSE"

        private const val CUSTOM_FAVORITE = "favorite"
        private const val CUSTOM_CLOSE = "close"

        private const val CHANNEL_ID = "main_video_playback"
        private const val NOTIFICATION_ID = 0x4D56

        /** Set by MainActivity so button presses can reach Dart. */
        @Volatile
        var onAction: ((String) -> Unit)? = null

        /** The running service, so updates are applied directly. */
        @Volatile
        var instance: PlaybackService? = null

        /** State handed to a service that is still starting. */
        @Volatile
        var pendingState: NowPlaying = NowPlaying()

        @Volatile
        var pendingArtwork: ByteArray? = null
    }

    private lateinit var session: MediaSession
    private var nowPlaying = NowPlaying()
    private var artwork: Bitmap? = null
    private var coverSmall: Bitmap? = null
    private var coverLarge: Bitmap? = null
    private var metadataKey: String? = null
    private var inForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()

        session = MediaSession(this, "MainVideo").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    send("play")
                }

                override fun onPause() {
                    send("pause")
                }

                override fun onSkipToNext() {
                    send("next")
                }

                override fun onSkipToPrevious() {
                    send("previous")
                }

                override fun onStop() {
                    send("stop")
                    shutdown()
                }

                override fun onSeekTo(pos: Long) {
                    // Moves the card's bar at once instead of waiting for Dart.
                    nowPlaying = nowPlaying.copy(positionMs = pos)
                    publishState()
                    send("seek:$pos")
                }

                override fun onCustomAction(action: String, extras: Bundle?) {
                    when (action) {
                        CUSTOM_FAVORITE -> send("favorite")
                        CUSTOM_CLOSE -> {
                            send("stop")
                            shutdown()
                        }
                    }
                }
            })
            setSessionActivity(openAppIntent())
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> apply(pendingState, pendingArtwork)

            ACTION_TOGGLE -> send("toggle")
            ACTION_NEXT -> send("next")
            ACTION_PREVIOUS -> send("previous")
            ACTION_FAVORITE -> send("favorite")

            ACTION_CLOSE -> {
                send("stop")
                shutdown()
            }

            ACTION_STOP -> shutdown()
        }
        // Do not resurrect with a null intent: playback state lives in Dart.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        session.isActive = false
        session.release()
        if (instance === this) instance = null
        super.onDestroy()
    }

    /**
     * Shows [state]. [artworkBytes] is null when the picture has not changed,
     * and empty when there is no picture for this video.
     */
    fun apply(state: NowPlaying, artworkBytes: ByteArray?) {
        nowPlaying = state
        if (artworkBytes != null) {
            artwork = if (artworkBytes.isEmpty()) {
                null
            } else {
                BitmapFactory.decodeByteArray(artworkBytes, 0, artworkBytes.size)
            }
            // Rounded once per picture, at the two sizes the card shows.
            val density = resources.displayMetrics.density
            coverSmall = artwork?.let { rounded(it, (44 * density).toInt(), 12 * density) }
            coverLarge = artwork?.let { rounded(it, (72 * density).toInt(), 16 * density) }
            metadataKey = null
        }
        publishMetadata()
        publishState()
        showNotification()
    }

    fun shutdown() {
        session.isActive = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        inForeground = false
        stopSelf()
    }

    private fun send(action: String) {
        onAction?.invoke(action)
    }

    // --------------------------------------------------------------- session
    private fun publishMetadata() {
        // Metadata is only resent when it changes: re-sending the same picture
        // on every play/pause makes some launchers redraw the whole card.
        val key = "${nowPlaying.title}|${nowPlaying.subtitle}|${nowPlaying.durationMs}"
        if (key == metadataKey) return
        metadataKey = key

        val builder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, nowPlaying.title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, nowPlaying.subtitle)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, nowPlaying.durationMs)
        artwork?.let { builder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it) }
        session.setMetadata(builder.build())
    }

    private fun publishState() {
        val state = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                    PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_SEEK_TO or
                    PlaybackState.ACTION_STOP
            )
            // Position plus speed and a timestamp: the system moves the seek
            // bar on its own between updates.
            .setState(
                if (nowPlaying.playing) PlaybackState.STATE_PLAYING
                else PlaybackState.STATE_PAUSED,
                nowPlaying.positionMs,
                if (nowPlaying.playing) nowPlaying.speed else 0f,
                SystemClock.elapsedRealtime()
            )
            .addCustomAction(
                PlaybackState.CustomAction.Builder(
                    CUSTOM_FAVORITE,
                    "Favorite",
                    if (nowPlaying.favorite) R.drawable.ic_notif_favorite
                    else R.drawable.ic_notif_favorite_border
                ).build()
            )
            .addCustomAction(
                PlaybackState.CustomAction.Builder(
                    CUSTOM_CLOSE,
                    "Close",
                    R.drawable.ic_notif_close
                ).build()
            )
            .build()
        session.setPlaybackState(state)
    }

    // ----------------------------------------------------------- notification
    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Controls for the video playing in the background"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun showNotification() {
        val notification = buildNotification()
        if (!inForeground) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                inForeground = true
                return
            } catch (e: RuntimeException) {
                // Not allowed to go foreground right now; still show controls.
            }
        }
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        },
        PendingIntent.FLAG_IMMUTABLE
    )

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(nowPlaying.title.ifEmpty { "Main Video" })
            .setContentText(nowPlaying.subtitle)
            .setSmallIcon(R.drawable.ic_notif_small)
            .setLargeIcon(artwork)
            .setContentIntent(openAppIntent())
            // Swiping away a paused card ends the background session.
            .setDeleteIntent(serviceIntent(ACTION_STOP))
            .setOngoing(nowPlaying.playing)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(nowPlaying.color)
            // The app's own card, styled like its mini player, in place of the
            // standard media template. The session still drives the lock screen,
            // headset buttons and the media controls in quick settings.
            .setCustomContentView(playerCard(expanded = false))
            .setCustomBigContentView(playerCard(expanded = true))

        builder.style = Notification.DecoratedMediaCustomViewStyle()
            .setMediaSession(session.sessionToken)

        return builder.build()
    }

    /** Fills one of the two card layouts with what is playing. */
    private fun playerCard(expanded: Boolean): RemoteViews {
        val views = RemoteViews(
            packageName,
            if (expanded) R.layout.notification_player_expanded
            else R.layout.notification_player
        )

        views.setTextViewText(R.id.title, nowPlaying.title.ifEmpty { "Main Video" })
        views.setTextViewText(R.id.subtitle, nowPlaying.subtitle)

        val cover = if (expanded) coverLarge else coverSmall
        if (cover != null) {
            views.setImageViewBitmap(R.id.cover, cover)
        } else {
            views.setImageViewResource(R.id.cover, R.drawable.notif_cover_placeholder)
        }

        // The play button is the app's accent, with a white glyph on it.
        views.setImageViewResource(
            R.id.toggle_icon,
            if (nowPlaying.playing) R.drawable.ic_notif_pause else R.drawable.ic_notif_play
        )
        views.setInt(R.id.toggle_background, "setColorFilter", nowPlaying.color)
        views.setInt(R.id.toggle_icon, "setColorFilter", Color.WHITE)

        views.setOnClickPendingIntent(R.id.previous, serviceIntent(ACTION_PREVIOUS))
        views.setOnClickPendingIntent(R.id.toggle, serviceIntent(ACTION_TOGGLE))
        views.setOnClickPendingIntent(R.id.next, serviceIntent(ACTION_NEXT))

        if (expanded) {
            views.setImageViewResource(
                R.id.favorite_icon,
                if (nowPlaying.favorite) R.drawable.ic_notif_favorite
                else R.drawable.ic_notif_favorite_border
            )
            if (nowPlaying.favorite) {
                views.setInt(R.id.favorite_icon, "setColorFilter", nowPlaying.color)
            }
            views.setOnClickPendingIntent(R.id.favorite, serviceIntent(ACTION_FAVORITE))
            views.setOnClickPendingIntent(R.id.close, serviceIntent(ACTION_CLOSE))
        }
        return views
    }

    /** [source] cropped to a square of [size] pixels with rounded corners. */
    private fun rounded(source: Bitmap, size: Int, radius: Float): Bitmap {
        val square = ThumbnailUtils.extractThumbnail(source, size, size)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(square, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        Canvas(output).drawRoundRect(
            RectF(0f, 0f, size.toFloat(), size.toFloat()),
            radius,
            radius,
            paint
        )
        return output
    }

    private fun serviceIntent(intentAction: String): PendingIntent {
        val intent = Intent(this, PlaybackService::class.java).setAction(intentAction)
        return PendingIntent.getService(
            this,
            intentAction.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
