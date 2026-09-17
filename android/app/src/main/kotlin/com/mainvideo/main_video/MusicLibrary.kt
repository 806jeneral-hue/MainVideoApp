package com.mainvideo.main_video

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Reads the device's music straight from MediaStore: every song with its
 * title, artist, album and duration, and each album's cover.
 *
 * photo_manager only knows a title and a duration for audio, which is not
 * enough to build albums and artists — hence this small native reader. All
 * work runs off the main thread and nothing leaves the device.
 */
class MusicLibrary(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "main_video/music")
    private val workers = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "songs" -> workers.execute {
                    val songs = try {
                        querySongs()
                    } catch (e: Exception) {
                        null
                    }
                    main.post {
                        if (songs == null) {
                            result.error("query_failed", "Could not read music", null)
                        } else {
                            result.success(songs)
                        }
                    }
                }

                "albumArt" -> {
                    val albumId = call.argument<Number>("albumId")?.toLong() ?: -1L
                    val path = call.argument<String>("path")
                    val size = call.argument<Number>("size")?.toInt() ?: 300
                    workers.execute {
                        val bytes = try {
                            albumArt(albumId, path, size)
                        } catch (e: Exception) {
                            null
                        }
                        main.post { result.success(bytes) }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        workers.shutdown()
    }

    @Suppress("DEPRECATION")
    private fun querySongs(): List<Map<String, Any?>> {
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
        )
        // Music only: ringtones, notification sounds and voice notes are left
        // out, and so is anything too short to be a song.
        val selection =
            "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= 10000"

        val songs = ArrayList<Map<String, Any?>>()
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        )?.use { cursor ->
            val id = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val title = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artist = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val album = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumId = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val duration = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val data = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val size = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val added = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val track = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val year = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)

            while (cursor.moveToNext()) {
                val path = cursor.getString(data) ?: continue
                songs.add(
                    mapOf(
                        "mediaId" to cursor.getLong(id),
                        "path" to path,
                        "title" to (cursor.getString(title) ?: ""),
                        "artist" to (cursor.getString(artist) ?: ""),
                        "album" to (cursor.getString(album) ?: ""),
                        "albumId" to cursor.getLong(albumId),
                        "durationMs" to cursor.getLong(duration),
                        "sizeBytes" to cursor.getLong(size),
                        "dateAddedSec" to cursor.getLong(added),
                        "track" to cursor.getInt(track),
                        "year" to cursor.getInt(year),
                    )
                )
            }
        }
        return songs
    }

    /**
     * The album's cover as JPEG bytes, or null when it has none. MediaStore's
     * own cached thumbnail first; failing that, the picture embedded in the
     * file itself.
     */
    private fun albumArt(albumId: Long, path: String?, size: Int): ByteArray? {
        var bitmap: Bitmap? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && albumId >= 0) {
            bitmap = try {
                context.contentResolver.loadThumbnail(
                    ContentUris.withAppendedId(
                        MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                        albumId
                    ),
                    Size(size, size),
                    null
                )
            } catch (e: Exception) {
                null
            }
        }

        if (bitmap == null && path != null) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(path)
                val embedded = retriever.embeddedPicture
                if (embedded != null) bitmap = decodeScaled(embedded, size)
            } catch (e: Exception) {
                bitmap = null
            } finally {
                try {
                    retriever.release()
                } catch (e: Exception) {
                    // Nothing to release.
                }
            }
        }

        val result = bitmap ?: return null
        val out = ByteArrayOutputStream()
        result.compress(Bitmap.CompressFormat.JPEG, 85, out)
        result.recycle()
        return out.toByteArray()
    }

    /** Decodes [data] no larger than needed for a [size] square. */
    private fun decodeScaled(data: ByteArray, size: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeByteArray(data, 0, data.size, options)
    }
}
