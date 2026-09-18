import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/play_plan.dart';
import '../../data/models/playable.dart';
import '../../data/models/song.dart';
import '../../data/models/video.dart';
import '../../data/repositories/play_plan_repository.dart';
import '../music/widgets/album_art.dart';
import 'app_icon.dart';
import 'glass.dart';
import 'video_thumbnail.dart';

/// Lays out a custom session for one list: which of its videos or songs to
/// play, in what order, and how many times each.
///
/// Opens on the list's last session, ready to run again or to change.
class PlayPlanPage extends StatefulWidget {
  const PlayPlanPage({
    super.key,
    required this.planKey,
    required this.items,
    required this.title,
    required this.countLabel,
    required this.onStart,
  });

  /// Which list's session this is — every folder, playlist and album keeps
  /// its own.
  final String planKey;
  final List<Playable> items;
  final String title;

  /// "5 videos" / "5 songs".
  final String Function(int count) countLabel;

  /// Starts playing the session: the chosen items in order, and how many
  /// times each plays, by id.
  final void Function(List<Playable> queue, Map<String, int> plays) onStart;

  static const PlayPlanRepository _repo = PlayPlanRepository();

  /// "Last session: 3 · 6 plays", or null when there is none for [planKey].
  static PlayPlan lastPlan(String planKey) => _repo.load(planKey);

  @override
  State<PlayPlanPage> createState() => _PlayPlanPageState();
}

class _PlayPlanPageState extends State<PlayPlanPage> {
  late final Map<String, Playable> _byId = {
    for (final item in widget.items) item.id: item,
  };

  /// The session so far, in playing order.
  late List<PlanEntry> _chosen;

  @override
  void initState() {
    super.initState();
    // The last session, minus anything no longer in the list.
    _chosen = PlayPlanPage.lastPlan(
      widget.planKey,
    ).entries.where((e) => _byId.containsKey(e.id)).toList();
  }

  int get _totalPlays => _chosen.fold(0, (sum, e) => sum + e.times);

  void _add(Playable item) =>
      setState(() => _chosen = [..._chosen, PlanEntry(id: item.id)]);

  void _remove(int index) =>
      setState(() => _chosen = [..._chosen]..removeAt(index));

  void _setTimes(int index, int times) => setState(() {
    _chosen = [..._chosen];
    _chosen[index] = _chosen[index].withTimes(times);
  });

  void _reorder(int oldIndex, int newIndex) => setState(() {
    final list = [..._chosen];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    _chosen = list;
  });

  Future<void> _start() async {
    final plan = PlayPlan(_chosen);
    await PlayPlanPage._repo.save(widget.planKey, plan);
    if (!mounted) return;
    final queue = [for (final e in _chosen) _byId[e.id]!];
    final plays = {for (final e in _chosen) e.id: e.times};
    Navigator.pop(context);
    widget.onStart(queue, plays);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final chosenIds = {for (final e in _chosen) e.id};
    final rest = [
      for (final item in widget.items)
        if (!chosenIds.contains(item.id)) item,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.planTitle),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
            ),
          ],
        ),
        actions: [
          if (_chosen.isNotEmpty)
            HeaderAction(
              tooltip: s.planClear,
              icon: const AppIcon(AppIcons.close_rounded),
              onPressed: () => setState(() => _chosen = []),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Label(_chosen.isEmpty ? s.planEmpty : s.planOrderHint),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverReorderableList(
              itemCount: _chosen.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) {
                final entry = _chosen[index];
                return Padding(
                  key: ValueKey(entry.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChosenRow(
                    index: index,
                    item: _byId[entry.id]!,
                    times: entry.times,
                    onTimes: (value) => _setTimes(index, value),
                    onRemove: () => _remove(index),
                  ),
                );
              },
            ),
          ),
          if (rest.isNotEmpty) SliverToBoxAdapter(child: _Label(s.planRest)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
            sliver: SliverList.builder(
              itemCount: rest.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RestRow(
                  item: rest[index],
                  onAdd: () => _add(rest[index]),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _chosen.isEmpty ? null : _start,
            icon: const AppIcon(AppIcons.play_arrow_rounded, size: 20),
            label: Text(
              _chosen.isEmpty
                  ? s.planStartEmpty
                  : s.planStart(widget.countLabel(_chosen.length), _totalPlays),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A small picture of the item: its thumbnail or its cover.
class _Picture extends StatelessWidget {
  const _Picture(this.item);

  final Playable item;

  @override
  Widget build(BuildContext context) => switch (item) {
    Video video => VideoThumbnail(
      video: video,
      width: 64,
      height: 38,
      showDuration: false,
      borderRadius: BorderRadius.circular(9),
    ),
    Song song => AlbumArt(song: song, size: 40),
    _ => const SizedBox(width: 40, height: 40),
  };
}

/// One chosen item: drag to move it, its place in the order, and how many
/// times it plays.
class _ChosenRow extends StatelessWidget {
  const _ChosenRow({
    required this.index,
    required this.item,
    required this.times,
    required this.onTimes,
    required this.onRemove,
  });

  final int index;
  final Playable item;
  final int times;
  final ValueChanged<int> onTimes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return GlassSurface(
      radius: BorderRadius.circular(16),
      selected: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  AppIcons.drag_indicator_rounded,
                  color: context.muted,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Picture(item),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _Counter(times: times, onChanged: onTimes),
            IconButton(
              tooltip: context.s.planRemove,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: AppIcon(
                AppIcons.close_rounded,
                size: 17,
                color: context.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// − ×2 + : how many times in a row an item plays.
class _Counter extends StatelessWidget {
  const _Counter({required this.times, required this.onChanged});

  final int times;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, int to, bool enabled) => InkResponse(
      onTap: enabled ? () => onChanged(to) : null,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AppIcon(
          icon,
          size: 15,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: AppTheme.pillRadius,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            step(AppIcons.remove_rounded, times - 1, times > 1),
            SizedBox(
              width: 30,
              child: Text(
                '×$times',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.accent,
                ),
              ),
            ),
            step(AppIcons.add_rounded, times + 1, times < PlayPlan.maxTimes),
          ],
        ),
      ),
    );
  }
}

/// One item not in the session yet: tap to add it at the end.
class _RestRow extends StatelessWidget {
  const _RestRow({required this.item, required this.onAdd});

  final Playable item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);

    return GlassSurface(
      radius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                _Picture(item),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                AppIcon(AppIcons.add_rounded, size: 20, color: context.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
