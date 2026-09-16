import '../../data/models/enums.dart';
import 'strings.dart';

/// Translated names for the enums the UI shows. Kept next to the strings so a
/// new language only has to be added in one place.
extension SortFieldLabel on SortField {
  String label(Strings s) => switch (this) {
    SortField.dateAdded => s.sortDateAdded,
    SortField.duration => s.sortLength,
    SortField.name => s.sortName,
    SortField.size => s.sortSize,
    SortField.lastWatched => s.sortWatchHistory,
    SortField.manual => s.sortCustom,
  };
}

extension LoopModeLabel on LoopMode {
  String label(Strings s) => switch (this) {
    LoopMode.off => s.repeatOff,
    LoopMode.all => s.repeatAll,
    LoopMode.one => s.repeatOne,
  };
}

extension SortFieldDirection on SortField {
  /// Ascending/descending is meaningless for a hand-made order.
  bool get hasDirection => this != SortField.manual;
}

extension VideoFitLabel on VideoFit {
  String label(Strings s) => switch (this) {
    VideoFit.fit => s.displayFit,
    VideoFit.fill => s.displayFill,
    VideoFit.stretch => s.displayStretch,
    VideoFit.ratio16x9 => '16:9',
    VideoFit.ratio4x3 => '4:3',
    VideoFit.original => s.displayOriginal,
  };
}
