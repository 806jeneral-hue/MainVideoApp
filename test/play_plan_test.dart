import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/data/models/play_plan.dart';

void main() {
  test('A custom session survives being stored and read back', () {
    const plan = PlayPlan([
      PlanEntry(id: '/a.mp4', times: 3),
      PlanEntry(id: '/b.mp4'),
    ]);
    final back = PlayPlan.fromMap(plan.toMap());
    expect(back.entries.map((e) => e.id), ['/a.mp4', '/b.mp4']);
    expect(back.entries.first.times, 3);
    expect(back.totalPlays, 4);
  });

  test('Counts stay between one and the maximum', () {
    const entry = PlanEntry(id: 'x');
    expect(entry.withTimes(0).times, 1);
    expect(entry.withTimes(500).times, PlayPlan.maxTimes);
    expect(PlanEntry.fromMap({'id': 'x', 'times': -4})!.times, 1);
  });

  test('A damaged record reads as an empty session', () {
    expect(PlayPlan.fromMap(null).isEmpty, isTrue);
    expect(PlayPlan.fromMap({'entries': 'nope'}).isEmpty, isTrue);
    expect(PlayPlan.fromMap({'entries': [5, {'times': 2}]}).isEmpty, isTrue);
  });
}
