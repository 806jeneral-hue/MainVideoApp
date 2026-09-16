package com.mainvideo.main_video

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder

/**
 * Keeps audio playing when the screen is off or the app is in the background.
 *
 * ExoPlayer inside video_player does not stop on its own when the activity is
 * paused — the real risk is Android reclaiming the process. A foreground
 * service with an ongoing notification is what prevents that, so the
 * "background playback" setting does something rather than merely existing.
 *
 * The service does not own the player. It keeps the process alive, shows the
 * controls, and forwards taps and audio-focus changes back to Dart, which is
 * where playback actually lives.
 */
class PlaybackService : Service() {

    companion object {
        const val ACTION_START = "com.mainvideo.main_video.START"
        const val ACTION_UPDATE = "com.mainvideo.main_video.UPDATE"
        const val ACTION_STOP = "com.mainvideo.main_video.STOP"

        const val ACTION_TOGGLE = "com.mainvideo.main_video.TOGGLE"
        const val ACTION_NEXT = "com.mainvideo.main_video.NEXT"
        const val ACTION_PREVIOUS = "com.mainvideo.main_video.PREVIOUS"
        const val ACTION_CLOSE = "com.mainvideo.main_video.CLOSE"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_PLAYING = "playing"

        private const val CHANNEL_ID = "main_video_playback"
        private const val NOTIFICATION_ID = 0x4D56

        /** Set by MainActivity so notification taps can reach Dart. */
        @Volatile
        var onAction: ((String) -> Unit)? = null
    }

    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null

    private var title: String = ""
    private var subtitle: String = ""
    private var playing: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> {
                title = intent.getStringExtra(EXTRA_TITLE) ?: title
                subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: subtitle
                playing = intent.getBooleanExtra(EXTRA_PLAYING, playing)

                if (intent.action == ACTION_START) requestAudioFocus()
                startForegroundCompat()
            }

            ACTION_TOGGLE -> onAction?.invoke("toggle")
            ACTION_NEXT -> onAction?.invoke("next")
            ACTION_PREVIOUS -> onAction?.invoke("previous")

            ACTION_CLOSE -> {
                onAction?.invoke("stop")
                shutdown()
            }

            ACTION_STOP -> shutdown()
        }
        // Do not resurrect with a null intent: playback state lives in Dart.
        return START_NOT_STICKY
    }

    private fun shutdown() {
        abandonAudioFocus()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        abandonAudioFocus()
        super.onDestroy()
    }

    // ------------------------------------------------------------ audio focus
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                onAction?.invoke("pause")

            AudioManager.AUDIOFOCUS_GAIN -> onAction?.invoke("focusGained")
        }
    }

    private fun requestAudioFocus() {
        if (focusRequest != null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focusRequest = request
            audioManager?.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(focusListener)
        }
        focusRequest = null
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

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            },
            PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(title.ifEmpty { "Main Video" })
            .setContentText(subtitle)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(openApp)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        builder.addAction(
            action(
                android.R.drawable.ic_media_previous,
                "Previous",
                ACTION_PREVIOUS
            )
        )
        builder.addAction(
            action(
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
                if (playing) "Pause" else "Play",
                ACTION_TOGGLE
            )
        )
        builder.addAction(
            action(android.R.drawable.ic_media_next, "Next", ACTION_NEXT)
        )
        builder.addAction(
            action(android.R.drawable.ic_menu_close_clear_cancel, "Close", ACTION_CLOSE)
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.style = Notification.MediaStyle()
                .setShowActionsInCompactView(1, 2)
        }

        return builder.build()
    }

    @Suppress("DEPRECATION")
    private fun action(
        icon: Int,
        label: String,
        intentAction: String
    ): Notification.Action {
        val intent = Intent(this, PlaybackService::class.java).setAction(intentAction)
        val pending = PendingIntent.getService(
            this,
            intentAction.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Action(icon, label, pending)
    }
}
