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
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock

/**
 * Keeps audio playing when the screen is off or the app is in the background,
 * and publishes it to the system as a media session.
 *
 * The session is what gives the full media card in the notification shade and
 * on the lock screen: the video's thumbnail, a live seek bar, and large
 * previous / play-pause / next buttons, plus favourite and close. It also lets
 * headset and Bluetooth buttons control playback.
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
            // The app's accent where the system lets an app colour its card;
            // newer Android versions take the colours from the thumbnail.
            .setColor(nowPlaying.color)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) builder.setColorized(true)

        // Newer Android versions build the buttons from the session; these
        // are what older versions show.
        builder.addAction(action(R.drawable.ic_notif_previous, "Previous", ACTION_PREVIOUS))
        builder.addAction(
            action(
                if (nowPlaying.playing) R.drawable.ic_notif_pause
                else R.drawable.ic_notif_play,
                if (nowPlaying.playing) "Pause" else "Play",
                ACTION_TOGGLE
            )
        )
        builder.addAction(action(R.drawable.ic_notif_next, "Next", ACTION_NEXT))
        builder.addAction(
            action(
                if (nowPlaying.favorite) R.drawable.ic_notif_favorite
                else R.drawable.ic_notif_favorite_border,
                "Favorite",
                ACTION_FAVORITE
            )
        )
        builder.addAction(action(R.drawable.ic_notif_close, "Close", ACTION_CLOSE))

        builder.style = Notification.MediaStyle()
            .setMediaSession(session.sessionToken)
            .setShowActionsInCompactView(0, 1, 2)

        return builder.build()
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

    @Suppress("DEPRECATION")
    private fun action(icon: Int, label: String, intentAction: String): Notification.Action =
        Notification.Action(icon, label, serviceIntent(intentAction))
}
