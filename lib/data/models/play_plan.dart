/// One line of a custom session: which item, and how many times in a row.
class PlanEntry {
  const PlanEntry({required this.id, this.times = 1});

  final String id;
  final int times;

  PlanEntry withTimes(int value) =>
      PlanEntry(id: id, times: value.clamp(1, PlayPlan.maxTimes));

  Map<String, dynamic> toMap() => {'id': id, 'times': times};

  static PlanEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String) return null;
    final times = raw['times'];
    return PlanEntry(
      id: id,
      times: (times is num ? times.toInt() : 1).clamp(1, PlayPlan.maxTimes),
    );
  }
}

/// A custom session: a chosen set of videos or songs, in a chosen order, each
/// played a chosen number of times. Every list remembers its last one.
class PlayPlan {
  const PlayPlan(this.entries);

  static const int maxTimes = 99;

  final List<PlanEntry> entries;

  bool get isEmpty => entries.isEmpty;
  int get totalPlays => entries.fold(0, (sum, e) => sum + e.times);

  Map<String, dynamic> toMap() => {
    'entries': [for (final e in entries) e.toMap()],
  };

  static PlayPlan fromMap(Map<dynamic, dynamic>? map) {
    final raw = map?['entries'];
    if (raw is! List) return const PlayPlan([]);
    return PlayPlan(raw.map(PlanEntry.fromMap).whereType<PlanEntry>().toList());
  }
}
