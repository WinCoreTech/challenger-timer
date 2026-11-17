import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/state.dart';
import '../core/day.dart';
import 'theme.dart';

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
          if (v.on(137))
            SwitchListTile(
                key: const Key('proofRequired'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Needs proof to count'),
                subtitle: const Text('A tick asks for one line of what you did.', style: TextStyle(color: dim, fontSize: 12)),
                value: h.flag('proofRequired'),
                onChanged: (x) => app.putRec(h.copy({'proofRequired': x}))),
          if (v.on(60))
            SwitchListTile(
                key: const Key('examSet'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Part of my exam set'),
                subtitle: const Text('Shown in exam mode. Habits outside the set are paused then.', style: TextStyle(color: dim, fontSize: 12)),
                value: h.flag('exam'),
                onChanged: (x) => app.putRec(h.copy({'exam': x}))),
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
