package com.mainvideo.main_video

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
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

    private var externalMediaChannel: MethodChannel? = null
    private var pendingMediaPath: String? = null

    private var musicLibrary: MusicLibrary? = null
    private var mediaIndexChannel: MethodChannel? = null
    private var videoScrubbing: VideoScrubbing? = null

    private var isNoisyReceiverRegistered = false
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                playbackChannel?.invokeMethod("playbackAction", "pause")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingMediaPath = resolveIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = resolveIntent(intent)
        if (path != null) {
            pendingMediaPath = path
            externalMediaChannel?.invokeMethod("onOpenMedia", path)
        }
    }

    private fun resolveIntent(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
            }
            else -> intent.data
        } ?: return null

        return resolveUriToPath(uri)
    }

    private fun resolveUriToPath(uri: Uri?): String? {
        if (uri == null) return null
        if (uri.scheme == "file") {
            return uri.path
        }
        if (uri.scheme == "content") {
            var displayName: String? = null
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && cursor.moveToFirst()) {
                        displayName = cursor.getString(nameIndex)
                    }
                }
            } catch (e: Exception) {
            }

            if (displayName.isNullOrEmpty()) {
                val lastSeg = uri.lastPathSegment
                displayName = if (!lastSeg.isNullOrEmpty() && (lastSeg.contains(".") || lastSeg.length < 50)) {
                    lastSeg.substringAfterLast("/")
                } else {
                    "media_${System.currentTimeMillis()}.mp4"
                }
            }

            try {
                val extDir = File(cacheDir, "external_media")
                if (!extDir.exists()) extDir.mkdirs()
                val targetFile = File(extDir, displayName!!)
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output)
                    }
                }
                if (targetFile.exists() && targetFile.length() > 0) {
                    return targetFile.absolutePath
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return uri.path ?: uri.toString()
    }

    /**
     * Asks for the display's highest refresh rate.
     *
     * Some phones keep an app at 60 Hz unless it says it can go faster, which
     * makes scrolling look choppier than the rest of the system. The window
     * only states a preference: Android still honours the user's own refresh
     * rate setting and drops back when the battery is low.
     */
    private fun requestHighRefreshRate() {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
        val best = display?.supportedModes
            ?.filter { it.physicalWidth == display.mode.physicalWidth && it.physicalHeight == display.mode.physicalHeight }
            ?.maxByOrNull { it.refreshRate } ?: return

        window.attributes = window.attributes.apply {
            preferredRefreshRate = best.refreshRate
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) preferredDisplayModeId = best.modeId
        }
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        musicLibrary = MusicLibrary(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        videoScrubbing = VideoScrubbing(flutterEngine)

        // Landscape that follows the phone's sensor both ways, even with the
        // system's rotation lock on: turning the phone over flips the video
        // with it. Flutter's own landscape setting obeys the lock and would
        // stay stuck on whichever side it started.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "main_video/orientation"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sensorLandscape" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Refreshes Android's media index for files changed or removed directly,
        // so the gallery and other apps stop showing them — silently, with no
        // confirmation dialog.
        mediaIndexChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "main_video/media_index"
        ).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> {
                        val paths = call.arguments<List<String>>() ?: emptyList()
                        if (paths.isNotEmpty()) {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                paths.toTypedArray(),
                                null,
                                null
                            )
                        }
                        result.success(null)
                    }

                    // When each video was added to the device, by MediaStore id.
                    // This is the real "added" date: a video unzipped or copied
                    // today counts as new even if it was filmed years ago.
                    "videoDatesAdded" -> Thread {
                        val dates = HashMap<String, Long>()
                        try {
                            applicationContext.contentResolver.query(
                                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                                arrayOf(
                                    MediaStore.Video.Media._ID,
                                    MediaStore.Video.Media.DATE_ADDED
                                ),
                                null,
                                null,
                                null
                            )?.use { cursor ->
                                val id = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                                val added = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
                                while (cursor.moveToNext()) {
                                    dates[cursor.getLong(id).toString()] = cursor.getLong(added)
                                }
                            }
                        } catch (e: Exception) {
                            // An empty map leaves the scanner on its own dates.
                        }
                        runOnUiThread { result.success(dates) }
                    }.start()

                    "scanArchives" -> Thread {
                        val archives = ArrayList<Map<String, Any?>>()
                        val scannedPaths = HashSet<String>()
                        val archiveExts = setOf("zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "iso")

                        fun addArchiveItem(file: File) {
                            try {
                                if (file.exists() && file.isFile && file.length() > 0) {
                                    val canonical = file.canonicalPath
                                    if (scannedPaths.add(canonical)) {
                                        val item = HashMap<String, Any?>()
                                        item["path"] = canonical
                                        item["title"] = file.name
                                        item["size"] = file.length()
                                        item["dateAdded"] = file.lastModified() / 1000
                                        item["dateModified"] = file.lastModified() / 1000
                                        archives.add(item)
                                    }
                                }
                            } catch (e: Exception) {
                            }
                        }

                        // 1. Query MediaStore.Files with DISPLAY_NAME & MIME_TYPE
                        try {
                            val projection = arrayOf(
                                MediaStore.Files.FileColumns._ID,
                                MediaStore.Files.FileColumns.DATA,
                                MediaStore.Files.FileColumns.DISPLAY_NAME,
                                MediaStore.Files.FileColumns.SIZE,
                                MediaStore.Files.FileColumns.DATE_ADDED,
                                MediaStore.Files.FileColumns.DATE_MODIFIED
                            )
                            val whereClauses = archiveExts.map { "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE '%.$it'" } +
                                    listOf(
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/zip'",
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/x-zip-compressed'",
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/x-rar-compressed'",
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/x-7z-compressed'",
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/x-tar'",
                                        "${MediaStore.Files.FileColumns.MIME_TYPE} = 'application/gzip'"
                                    )
                            val selection = whereClauses.joinToString(" OR ")

                            applicationContext.contentResolver.query(
                                MediaStore.Files.getContentUri("external"),
                                projection,
                                selection,
                                null,
                                "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"
                            )?.use { cursor ->
                                val dataCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATA)
                                val nameCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
                                val sizeCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
                                val addedCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_ADDED)
                                val modCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_MODIFIED)

                                while (cursor.moveToNext()) {
                                    val path = if (dataCol != -1) cursor.getString(dataCol) else null
                                    val title = if (nameCol != -1) cursor.getString(nameCol) else null
                                    if (!path.isNullOrEmpty()) {
                                        val f = File(path)
                                        if (f.exists()) {
                                            addArchiveItem(f)
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {
                        }

                        // 2. Query MediaStore.Downloads (Android 10+)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            try {
                                val proj = arrayOf(
                                    MediaStore.Downloads._ID,
                                    MediaStore.Downloads.DATA,
                                    MediaStore.Downloads.DISPLAY_NAME,
                                    MediaStore.Downloads.SIZE,
                                    MediaStore.Downloads.DATE_ADDED,
                                    MediaStore.Downloads.DATE_MODIFIED
                                )
                                applicationContext.contentResolver.query(
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    proj,
                                    null,
                                    null,
                                    "${MediaStore.Downloads.DATE_ADDED} DESC"
                                )?.use { cursor ->
                                    val dataCol = cursor.getColumnIndex(MediaStore.Downloads.DATA)
                                    val nameCol = cursor.getColumnIndex(MediaStore.Downloads.DISPLAY_NAME)
                                    while (cursor.moveToNext()) {
                                        val name = if (nameCol != -1) cursor.getString(nameCol) ?: "" else ""
                                        val path = if (dataCol != -1) cursor.getString(dataCol) else null
                                        val ext = name.substringAfterLast(".", "").lowercase()
                                        if (archiveExts.contains(ext)) {
                                            if (!path.isNullOrEmpty()) {
                                                val f = File(path)
                                                if (f.exists()) {
                                                    addArchiveItem(f)
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                            }
                        }

                        // 3. Deep Recursive Filesystem Walk across External Storage
                        try {
                            fun walkDir(dir: File, depth: Int) {
                                if (depth > 6) return
                                val files = dir.listFiles() ?: return
                                for (file in files) {
                                    try {
                                        if (file.isDirectory) {
                                            val name = file.name
                                            if (name.startsWith(".") || name.equals("Android", ignoreCase = true)) {
                                                continue
                                            }
                                            walkDir(file, depth + 1)
                                        } else if (file.isFile) {
                                            val ext = file.name.substringAfterLast(".", "").lowercase()
                                            if (archiveExts.contains(ext)) {
                                                addArchiveItem(file)
                                            }
                                        }
                                    } catch (e: Exception) {
                                    }
                                }
                            }

                            val storageRoot = Environment.getExternalStorageDirectory()
                            if (storageRoot != null && storageRoot.exists()) {
                                walkDir(storageRoot, 0)
                            }
                        } catch (e: Exception) {
                        }

                        runOnUiThread { result.success(archives) }
                    }.start()

                    else -> result.notImplemented()
                }
            }
        }

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

        externalMediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "main_video/external_media"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialMedia" -> {
                        val path = pendingMediaPath
                        pendingMediaPath = null
                        result.success(path)
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

        val noisyFilter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (!isNoisyReceiverRegistered) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(noisyReceiver, noisyFilter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(noisyReceiver, noisyFilter)
            }
            isNoisyReceiverRegistered = true
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
        externalMediaChannel?.setMethodCallHandler(null)
        externalMediaChannel = null
        PlaybackService.onAction = null
        musicLibrary?.dispose()
        mediaIndexChannel?.setMethodCallHandler(null)
        videoScrubbing?.dispose()
        videoScrubbing = null
        mediaIndexChannel = null
        musicLibrary = null
        if (isNoisyReceiverRegistered) {
            try {
                unregisterReceiver(noisyReceiver)
            } catch (e: Exception) {
            }
            isNoisyReceiverRegistered = false
        }
        super.onDestroy()
    }
}
