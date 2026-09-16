import 'enums.dart';

/// Identifies one list of videos so it can keep its own sort order.
///
/// Every screen that shows videos has a key: the home screen, favourites, each
/// real device folder, and each playlist.
class CollectionKey {
  const CollectionKey._(this.value);

  final String value;

  static const CollectionKey home = CollectionKey._('home');
  static const CollectionKey favorites = CollectionKey._('favorites');

  factory CollectionKey.folder(String path) => CollectionKey._('folder:$path');

  factory CollectionKey.playlist(String id) => CollectionKey._('playlist:$id');

  @override
  bool operator ==(Object other) =>
      other is CollectionKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// How one particular list is ordered, including the hand-made order the user
/// built by dragging rows around.
class CollectionPrefs {
  const CollectionPrefs({
    this.sortField = SortField.dateAdded,
    this.descending = true,
    this.manualOrder = const [],
  });

  final SortField sortField;
  final bool descending;

  /// Video ids in the order the user arranged them. Ids that are no longer in
  /// the collection are ignored, and members missing from it are appended, so
  /// the order survives videos being added or deleted.
  final List<String> manualOrder;

  bool get isManual => sortField == SortField.manual;

  CollectionPrefs copyWith({
    SortField? sortField,
    bool? descending,
    List<String>? manualOrder,
  }) => CollectionPrefs(
    sortField: sortField ?? this.sortField,
    descending: descending ?? this.descending,
    manualOrder: manualOrder ?? this.manualOrder,
  );

  Map<String, dynamic> toMap() => {
    'sortField': sortField.name,
    'descending': descending,
    'manualOrder': manualOrder,
  };

  factory CollectionPrefs.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['sortField'] as String?;
    return CollectionPrefs(
      sortField: SortField.values.firstWhere(
        (f) => f.name == raw,
        orElse: () => SortField.dateAdded,
      ),
      descending: map['descending'] as bool? ?? true,
      manualOrder: (map['manualOrder'] as List?)?.cast<String>() ?? const [],
    );
  }
}
