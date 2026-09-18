/// How the home / folder lists are laid out (phase 2).
enum ViewMode { list, compact, grid }

/// The look of the whole app: see-through frosted glass (the original), or
/// solid cards on a warm backdrop with a bold accent.
enum AppStyle { glass, solid }

/// Sort options required by phase 2, plus the custom drag-and-drop order that
/// each folder and playlist can keep for itself.
enum SortField { dateAdded, duration, name, size, lastWatched, manual }

enum SortDirection { ascending, descending }

/// Repeat behaviour of the player queue (phase 4).
enum LoopMode { off, all, one }

/// How the video is sized inside the player.
enum VideoFit {
  /// The whole frame is visible; bars appear if the shapes differ.
  fit,

  /// The frame covers the screen; the edges that do not fit are cropped.
  fill,

  /// The frame is pulled to the screen's shape: nothing cropped, nothing
  /// hidden, but the picture is distorted if the shapes differ.
  stretch,

  /// Forced 16:9, whatever the file reports.
  ratio16x9,

  /// Forced 4:3.
  ratio4x3,

  /// The video's own pixel size, centred — smaller videos stay small.
  original,
}
