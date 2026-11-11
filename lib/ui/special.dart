import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/extras.dart';
import 'theme.dart';

/// Feature 4: 5-4-3-2-1, then the timer starts on its own.
Future<bool> fiveSecondLaunch(BuildContext context) async =>
    await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const _Launch()) ?? false;

class _Launch extends StatefulWidget {
  const _Launch();
  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  int n = 5;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (n <= 1) {
        t?.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => n--);
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
      backgroundColor: ink,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Big('$n', size: 200, color: cyan, key: const Key('launchCount')),
        const SizedBox(height: 24),
        const Text('No time to argue with yourself.', style: TextStyle(color: dim, fontSize: 16)),
        const SizedBox(height: 24),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
      ]));
}

/// Feature 9: the same short sequence every time: sound, one breath, tap.
class RitualScreen extends ConsumerStatefulWidget {
  const RitualScreen({super.key});
  @override
  ConsumerState<RitualScreen> createState() => _RitualState();
}

class _RitualState extends ConsumerState<RitualScreen> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  bool ready = false;
  @override
  void initState() {
    super.initState();
    ref.read(nativeProvider).tone();
    a.forward().whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    return Scaffold(
        appBar: AppBar(title: const Text('START RITUAL')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Same three steps every time: the sound, one slow breath, one tap. After a few weeks the sequence itself says "work now".',
                  style: TextStyle(color: dim)),
              const Spacer(),
              Center(
                  child: AnimatedBuilder(
                      animation: a,
                      builder: (_, _) {
                        final t = a.value < 0.5 ? a.value * 2 : (1 - a.value) * 2; // in, then out
                        return Container(
                            width: 120 + 120 * t,
                            height: 120 + 120 * t,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan, width: 6)),
                            alignment: Alignment.center,
                            child: H(ready ? 'Ready' : a.value < 0.5 ? 'Breathe in' : 'Breathe out', color: Colors.white));
                      })),
              const Spacer(),
              FilledButton(
                  key: const Key('ritualStart'),
                  onPressed: ready
                      ? () async {
                          await app.startSession();
                          if (context.mounted) context.go('/timer');
                        }
                      : null,
                  child: Text(ready ? 'TAP TO START ${v.doorMinutes} MIN' : 'ONE BREATH FIRST')),
              SwitchListTile(
                  key: const Key('ritualToggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use this before every start from Home'),
                  subtitle: const Text('Off keeps Home at a single tap.', style: TextStyle(color: dim, fontSize: 12)),
                  value: v.kv['ritual'] == '1',
                  onChanged: (x) => app.setSetting('ritual', x ? '1' : '0')),
            ])));
  }
}

/// Feature 14: cannot choose, so the dice chooses.
class DiceTool extends ConsumerStatefulWidget {
  const DiceTool({super.key, this.random});
  final Random? random;
  @override
  ConsumerState<DiceTool> createState() => _DiceState();
}

class _DiceState extends ConsumerState<DiceTool> {
  String? pick;
  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final options = diceOptions(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final o in options)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(border: o == pick ? cyan : null, child: Text(o, style: const TextStyle(fontSize: 16)))),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          key: const Key('diceRoll'),
          onPressed: () => setState(() => pick = rollDice(options, widget.random ?? Random())),
          icon: const Icon(Icons.casino),
          label: Text(pick == null ? 'ROLL' : 'ROLL AGAIN')),
      if (pick != null) ...[
        const SizedBox(height: 12),
        FilledButton(
            key: const Key('diceStart'),
            onPressed: () async {
              await app.startSession(title: pick);
              if (context.mounted) context.go('/timer');
            },
            child: Text('START ${v.doorMinutes} MIN ON IT')),
      ],
    ]);
  }
}

/// Screens for tools of kind "special", by feature number.
Widget specialTool(int n, DayView v) => switch (n) {
      14 => const DiceTool(),
      32 => ChainCalendar(v),
      47 => const WagerTool(),
      48 => const RestDays(),
      _ => const Text('Not available.'),
    };

/// Edit one habit: name plus the optional parts from features 28, 29, 49, 50, 74.
class HabitScreen extends ConsumerStatefulWidget {
  const HabitScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<HabitScreen> createState() => _HabitState();
}

class _HabitState extends ConsumerState<HabitScreen> {
  final name = TextEditingController(), tiny = TextEditingController();
  bool loaded = false;
  @override
  void dispose() {
    name.dispose();
    tiny.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final h = v.rec(widget.id);
    if (h == null) return const Scaffold(body: Center(child: Text('This habit is gone.')));
    if (!loaded) {
      name.text = h.str('name');
      tiny.text = h.str('tiny');
      loaded = true;
    }
    Future<void> pickTime(String key) async {
      final cur = h.integer(key, key == 'from' ? 6 * 60 : 9 * 60);
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      if (t != null) await app.putRec(h.copy({key: t.hour * 60 + t.minute}));
    }

    return Scaffold(
        appBar: AppBar(title: const Text('HABIT')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const H('Name'),
          const SizedBox(height: 6),
          TextField(key: const Key('habitName'), controller: name),
          if (v.on(28)) ...[
            const SizedBox(height: 16),
            const H('Tiny version (keeps the streak on a bad day)'),
            const SizedBox(height: 6),
            TextField(key: const Key('habitTiny'), controller: tiny, decoration: const InputDecoration(hintText: 'Read one line')),
          ],
          const SizedBox(height: 12),
          FilledButton(
              key: const Key('habitSave'),
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await app.putRec(h.copy({'name': name.text.trim(), 'tiny': tiny.text.trim()}));
                if (context.mounted) toast(context, 'Saved.');
              },
              child: const Text('SAVE')),
          if (v.on(29)) ...[
            const SizedBox(height: 20),
            const H('How often'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final n in [0, 2, 3, 4, 5, 6])
                ChoiceChip(
                    key: Key('weekly-$n'),
                    label: Text(n == 0 ? 'Every day' : '$n of 7 days'),
                    selected: h.integer('weekly') == n,
                    onSelected: (_) => app.putRec(h.copy({'weekly': n}))),
            ]),
          ],
          if (v.on(49)) ...[
            const SizedBox(height: 20),
            const H('Time window (it only counts inside)'),
            Row(children: [
              TextButton(key: const Key('winFrom'), onPressed: () => pickTime('from'), child: Text('FROM ${hhmm(h.integer('from'))}')),
              TextButton(key: const Key('winTo'), onPressed: () => pickTime('to'), child: Text('TO ${hhmm(h.integer('to'))}')),
              if (h.data['from'] != null || h.data['to'] != null)
                TextButton(onPressed: () => app.putRec(h.copy({'from': null, 'to': null})), child: const Text('CLEAR')),
            ]),
          ],
          const SizedBox(height: 20),
          if (v.on(50))
            OutlinedButton(
                key: const Key('graduate'),
                onPressed: () => app.putRec(h.copy({'maintained': !h.flag('maintained')})),
                child: Text(h.flag('maintained') ? 'BRING BACK TO ACTIVE' : 'GRADUATE: IT RUNS ON ITS OWN NOW')),
          const SizedBox(height: 12),
          TextButton(
              key: const Key('archiveHabit'),
              onPressed: () async {
                await app.putRec(h.copy({'archived': true}));
                if (context.mounted) context.pop();
              },
              child: const Text('ARCHIVE (HISTORY IS KEPT)')),
        ]));
  }
}

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
