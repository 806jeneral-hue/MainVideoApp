# VideoScrubbing.kt reaches the ExoPlayer behind video_player by field name,
# so those names must survive shrinking in release builds.
-keepclassmembers class io.flutter.plugins.videoplayer.VideoPlayerPlugin {
    private android.util.LongSparseArray videoPlayers;
}
-keepclassmembers class io.flutter.plugins.videoplayer.VideoPlayer {
    protected androidx.media3.exoplayer.ExoPlayer exoPlayer;
}
