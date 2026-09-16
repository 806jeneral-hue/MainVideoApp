/// A manually created playlist. Phase 3 treats folders and playlists as the
/// same concept, so a playlist is simply a set of video paths the user picked
/// from anywhere on the device, plus the styling that makes it recognisable at
/// a glance.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.videoIds,
    required this.createdAt,
    this.colorValue,
    this.iconKey,
    this.pinned = false,
  });

  final String id;
  final String name;
  final List<String> videoIds;
  final DateTime createdAt;

  /// ARGB value chosen by the user; null falls back to the app accent.
  final int? colorValue;

  /// Key into [PlaylistIcons]; null falls back to the default playlist icon.
  final String? iconKey;

  /// Pinned playlists sit at the top of the Folders screen.
  final bool pinned;

  int get count => videoIds.length;

  Playlist copyWith({
    String? name,
    List<String>? videoIds,
    int? colorValue,
    String? iconKey,
    bool? pinned,
    bool clearColor = false,
    bool clearIcon = false,
  }) => Playlist(
    id: id,
    name: name ?? this.name,
    videoIds: videoIds ?? this.videoIds,
    createdAt: createdAt,
    colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
    pinned: pinned ?? this.pinned,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'videoIds': videoIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'colorValue': colorValue,
    'iconKey': iconKey,
    'pinned': pinned,
  };

  factory Playlist.fromMap(Map<dynamic, dynamic> map) => Playlist(
    id: map['id'] as String,
    name: map['name'] as String? ?? 'Playlist',
    videoIds: (map['videoIds'] as List?)?.cast<String>() ?? const [],
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['createdAt'] as int? ?? 0,
    ),
    colorValue: map['colorValue'] as int?,
    iconKey: map['iconKey'] as String?,
    pinned: map['pinned'] as bool? ?? false,
  );
}
