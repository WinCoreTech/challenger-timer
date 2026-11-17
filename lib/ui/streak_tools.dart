import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/extras.dart';
import '../core/tools.dart';
import 'theme.dart';

/// Feature 32: this month with every showed-up day crossed off.
class ChainCalendar extends StatelessWidget {
  const ChainCalendar(this.v, {super.key});
  final DayView v;
  @override
  Widget build(BuildContext context) {
    final t = dateOfDay(v.today);
    final first = dayOfDate(t.year, t.month, 1);
    final count = DateTime.utc(t.year, t.month + 1, 0).day;
    final lead = weekdayOf(first) - 1;
    return GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
      for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: H(d, size: 11)),
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var i = 0; i < count; i++)
        Builder(builder: (_) {
          final day = first + i;
          final done = v.showedUpDays.contains(day), frozen = v.master.frozenDays.contains(day);
          return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: done ? cyan : panel,
                  border: Border.all(color: day == v.today ? Colors.white : line),
                  borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.center,
              child: Text(done ? '✕' : frozen ? '❄' : '${i + 1}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: done ? ink : dim)));
        }),
    ]);
  }
}

/// Feature 48: pick weekdays that never count against a streak.
class RestDays extends ConsumerWidget {
  const RestDays({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final cur = v.restWeekdays;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var d = 1; d <= 7; d++)
        FilterChip(
            key: Key('rest-$d'),
            label: Text(names[d - 1]),
            selected: cur.contains(d),
            onSelected: (on) {
              final next = {...cur};
              on ? next.add(d) : next.remove(d);
              if (next.length > 3) return toast(context, 'Three rest days at most, so the habit stays a habit.');
              ref.read(appProvider.notifier).setSetting('restDays', (next.toList()..sort()).join());
            }),
    ]);
  }
}

/// Feature 47: bet XP on a 7-day run.
class WagerTool extends ConsumerWidget {
  const WagerTool({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final all = wagers(v);
    final open = all.any((w) => w.state == 'open');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!open)
        Wrap(spacing: 8, children: [
          for (final a in [50, 100, 200])
            OutlinedButton(
                key: Key('wager-$a'),
                onPressed: v.xpTotal < a ? null : () => ref.read(appProvider.notifier).log(Ev.tool, {'n': 47, 'amount': a}),
                child: Text('BET $a XP')),
        ])
      else
        const Text('One wager at a time. This one is still running.', style: TextStyle(color: cyan, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      for (final w in all.reversed)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${w.amount} XP from ${dayLabel(w.day)}'),
            trailing: H(w.state, color: w.state == 'won' ? cyan : w.state == 'lost' ? gold : dim)),
    ]);
  }
}

/// Feature 58: restore yesterday by doing double the minimum today.
class RepairTool extends ConsumerWidget {
  const RepairTool({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final ok = canRepair(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          ok
              ? 'Yesterday is empty and today already has ${v.minutesToday} minutes. That is enough to restore it.'
              : 'Available when yesterday was missed and today has at least 4 minutes of sessions (today: ${v.minutesToday}).',
          style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      FilledButton(
          key: const Key('repair'),
          onPressed: ok ? () => ref.read(appProvider.notifier).log(Ev.tool, {'n': 58, 'repairDay': v.today - 1}) : null,
          child: const Text('RESTORE YESTERDAY')),
    ]);
  }
}

/// Features 59 and 60: an on/off mode stored as events.
class ModeTool extends ConsumerStatefulWidget {
  const ModeTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<ModeTool> createState() => _ModeState();
}

class _ModeState extends ConsumerState<ModeTool> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final on = widget.n == 59 ? pauseOn(v) : examOn(v);
    final days = widget.n == 59 ? pausedDays(v) : examDays(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!on && widget.n == 59)
        TextField(key: const Key('modeReason'), controller: reason, decoration: const InputDecoration(hintText: 'Reason: fever, travelling, family...')),
      const SizedBox(height: 12),
      FilledButton(
          key: const Key('modeToggle'),
          onPressed: () => ref.read(appProvider.notifier).log(Ev.tool, {'n': widget.n, 'on': !on, if (!on) 'reason': reason.text.trim()}),
          child: Text(on ? 'SWITCH OFF: I AM BACK' : 'SWITCH ON')),
      const SizedBox(height: 12),
      Text(on ? 'On. Nothing counts as a miss until you switch it off.' : 'Off.', style: TextStyle(color: on ? gold : dim, fontWeight: FontWeight.w800)),
      Text('${days.length} days covered so far.', style: const TextStyle(color: dim)),
    ]);
  }
}

/// Feature 74: archived habits stay as history and can come back.
class ArchiveTool extends ConsumerWidget {
  const ArchiveTool({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final old = v.of(Kind.habit).where((h) => h.flag('archived')).toList();
    if (old.isEmpty) return const Text('Nothing archived. When you archive a habit it lands here with its history.', style: TextStyle(color: dim));
    return Column(children: [
      for (final h in old)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(h.str('name')),
            subtitle: Text('Longest streak ${v.habitStreak(h.id).longest} · ${v.habitDays(h.id).length} days done', style: const TextStyle(color: dim)),
            trailing: TextButton(onPressed: () => ref.read(appProvider.notifier).putRec(h.copy({'archived': false})), child: const Text('RESTORE'))),
    ]);
  }
}

/// Feature 70, local honour version: log one gifted freeze a month.
class GiftTool extends ConsumerWidget {
  const GiftTool({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final thisMonth = v.toolEvents(70).any((e) => monthKey(e.day) == monthKey(v.today));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Not connected to a server, so the app cannot check with your buddy. Until then this works on trust: if your buddy really gave you one of their freezes, log it here. One a month at most.',
          style: TextStyle(color: dim)),
      const SizedBox(height: 16),
      FilledButton(
          key: const Key('gift'),
          onPressed: thisMonth ? null : () => ref.read(appProvider.notifier).log(Ev.tool, {'n': 70}),
          child: Text(thisMonth ? 'ONE GIFT LOGGED THIS MONTH' : 'MY BUDDY GAVE ME A FREEZE')),
    ]);
  }
}
