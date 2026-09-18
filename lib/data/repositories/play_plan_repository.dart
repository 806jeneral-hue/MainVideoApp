import '../local/app_database.dart';
import '../models/play_plan.dart';

/// Remembers the last custom session made for each list, so it opens ready to
/// run again or to change.
class PlayPlanRepository {
  const PlayPlanRepository();

  PlayPlan load(String list) =>
      PlayPlan.fromMap(AppDatabase.playPlans.get(list));

  Future<void> save(String list, PlayPlan plan) =>
      AppDatabase.playPlans.put(list, plan.toMap());
}
