import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/data/models/bookmark.dart';
import 'package:main_video/data/models/collection_prefs.dart';

void main() {
  test('A stop marker survives being stored and read back', () {
    final marker = StopMarker(
      videoId: '/videos/ep02.mp4',
      positionMs: 760000,
      markedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    final back = StopMarker.fromMap(marker.toMap())!;
    expect(back.videoId, marker.videoId);
    expect(back.position, const Duration(minutes: 12, seconds: 40));
    expect(back.markedAt, marker.markedAt);
  });

  test('A damaged record reads as no marker', () {
    expect(StopMarker.fromMap(null), isNull);
    expect(StopMarker.fromMap({'positionMs': 5}), isNull);
  });

  test('Home, each folder and each playlist are separate lists', () {
    final keys = {
      CollectionKey.home,
      CollectionKey.folder('/a'),
      CollectionKey.folder('/b'),
      CollectionKey.playlist('1'),
    };
    expect(keys.length, 4);
  });

  test('Moments read both the old plain numbers and notes', () {
    expect(Moment.fromStored(65000)!.ms, 65000);
    expect(Moment.fromStored(65000)!.note, '');
    final withNote = Moment.fromStored({'ms': 5000, 'note': 'بداية المشهد'})!;
    expect(withNote.position, const Duration(seconds: 5));
    expect(withNote.note, 'بداية المشهد');
    expect(Moment.fromStored('x'), isNull);
    final back = Moment.fromStored(withNote.toMap())!;
    expect(back.note, withNote.note);
  });
}
