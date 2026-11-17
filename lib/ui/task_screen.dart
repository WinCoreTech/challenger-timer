import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/deadlines.dart';
import '../core/events.dart';
import '../core/projects.dart';
import '../core/tools.dart';
import 'share.dart';
import 'theme.dart';

/// One task with its deadline maths (features 101 to 125).
class TaskScreen extends ConsumerWidget {
  const TaskScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final t = v.rec(id);
    if (t == null) return const Scaffold(body: Center(child: Text('This task is gone.')));
    final m = TaskMath(v, t);
    Widget fact(int feature, String label, String value) => !v.on(feature)
        ? const SizedBox()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(label, style: const TextStyle(color: dim))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ]));
    Future<void> pickDue() async {
      final base = dateOfDay(m.hasDue ? m.due : v.today + 7);
      final d = await showDatePicker(
          context: context, initialDate: DateTime(base.year, base.month, base.day), firstDate: DateTime(2020), lastDate: DateTime(2100));
      if (d != null) await app.putRec(t.copy({'due': dayOfDate(d.year, d.month, d.day)}));
    }

    Future<void> postpone() async {
      if (v.on(121) && m.postponed >= 2) {
        final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(backgroundColor: panel, title: const Text('Third postpone'), children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('This one has been pushed twice already. That usually means it is too big or does not matter. Pick one.')),
                  SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'split'), child: const Text('SPLIT IT IN TWO SMALLER TASKS')),
                  SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('DELETE IT')),
                  SimpleDialogOption(onPressed: () => Navigator.pop(ctx), child: const Text('KEEP THE DATE')),
                ]));
        if (choice == 'split') {
          await app.putRec(t.copy({'title': '${t.str('title')} (part 1)', 'est': m.est ~/ 2, 'postponed': 0}));
          await app.addRec(Kind.task, {...t.data, 'title': '${t.str('title')} (part 2)', 'est': m.est - m.est ~/ 2, 'postponed': 0, 'due': m.due + 2});
        } else if (choice == 'delete') {
          await app.deleteRec(t.id);
          if (context.mounted) context.pop();
        }
        return;
      }
      final cost = v.on(109) ? v.single(const ToolDef(n: 109, kind: 'single', title: '', prompts: [''])).first : '';
      final reason = await askText(context, 'Why push it?',
          hint: cost.isEmpty ? 'One honest line' : 'Last time it cost: $cost', ok: 'PUSH 2 DAYS');
      if (reason == null || (v.on(120) && reason.trim().length < 3)) {
        if (context.mounted && reason != null) toast(context, 'A reason is needed to move it. That is the whole price.');
        return;
      }
      await app.postponeTask(t, 2, reason.trim());
    }

    return Scaffold(
        appBar: AppBar(title: const Text('TASK')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(t.str('title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (v.on(122) && m.postponed > 0) Text('Pushed ${m.postponed} times.', key: const Key('delayCount'), style: const TextStyle(color: gold)),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(key: const Key('taskDue'), onPressed: pickDue, icon: const Icon(Icons.event), label: Text(m.hasDue ? 'DUE ${dayLabel(m.due).toUpperCase()}' : 'SET DUE DATE')),
          ]),
          const SizedBox(height: 12),
          const H('How much work is it?'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const [25, 50, 100, 200, 400, 800])
              ChoiceChip(
                  key: Key('est-$e'),
                  label: Text(e < 60 ? '$e MIN' : '${(e / 60).toStringAsFixed(e % 60 == 0 ? 0 : 1)} H'),
                  selected: m.est == e,
                  onSelected: (_) => app.putRec(t.copy({'est': e}))),
          ]),
          if (v.on(157) && m.est > 0 && estimateRatio(v) != 1)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('At your usual ratio that is about ${correctedEstimate(v, m.est)} minutes.', style: const TextStyle(color: dim))),
          if (v.on(158) && m.est > 0) Text('Logged so far: ${m.done} of ${m.est} minutes.', style: const TextStyle(color: dim)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (f, key, label) in const [
              (162, 'frog', 'DO FIRST'), (159, 'urgent', 'URGENT'), (159, 'important', 'IMPORTANT'), (169, 'milestone', 'MILESTONE'),
            ])
              if (v.on(f))
                FilterChip(key: Key('flag-$key'), label: Text(label), selected: t.flag(key), onSelected: (x) => app.putRec(t.copy({key: x}))),
            if (v.on(174))
              for (final e in const [1, 7])
                FilterChip(
                    key: Key('every-$e'),
                    label: Text(e == 1 ? 'REPEATS DAILY' : 'REPEATS WEEKLY'),
                    selected: t.integer('every') == e,
                    onSelected: (x) => app.putRec(t.copy({'every': x ? e : 0}))),
          ]),
          if (v.on(166)) ...[
            const SizedBox(height: 8),
            const H('Dread (4 or 5 pays bonus XP when done)'),
            Wrap(spacing: 6, children: [
              for (var d = 1; d <= 5; d++)
                ChoiceChip(key: Key('dread-$d'), label: Text('$d'), selected: t.integer('dread') == d, onSelected: (_) => app.putRec(t.copy({'dread': d}))),
            ]),
          ],
          if (v.on(173)) ...[
            const SizedBox(height: 8),
            const H('Must wait for'),
            Wrap(spacing: 6, children: [
              for (final o in v.tasksOf(t.str('projectId')))
                if (o.id != t.id && !o.flag('done'))
                  ChoiceChip(
                      label: Text(o.str('title')),
                      selected: t.str('after') == o.id,
                      onSelected: (x) => app.putRec(t.copy({'after': x ? o.id : ''}))),
            ]),
          ],
          if (v.on(284)) ...[
            const SizedBox(height: 8),
            TextButton(
                onPressed: () async {
                  final g = await askText(context, 'Good enough looks like', initial: t.str('enough'), hint: 'Two pages, diagrams rough');
                  if (g != null) await app.putRec(t.copy({'enough': g.trim()}));
                },
                child: Text(t.str('enough').isEmpty ? 'DEFINE "GOOD ENOUGH"' : 'GOOD ENOUGH: ${t.str('enough')}')),
          ],
          const SizedBox(height: 16),
          FilledButton(
              key: const Key('taskStart'),
              onPressed: () async {
                await app.startSession(
                    minutes: v.on(104) && m.firstTouchOpen ? 5 : null, projectId: t.str('projectId'), title: t.str('title'), taskId: t.id, source: 'task');
                if (context.mounted) context.go('/timer');
              },
              child: Text(v.on(104) && m.firstTouchOpen ? 'FIRST TOUCH: START 5 MIN' : 'START ${v.doorMinutes} MIN ON THIS')),
          if (m.hasDue && m.est > 0) ...[
            const SizedBox(height: 20),
            Panel(
                key: const Key('taskMath'),
                border: v.on(108) && m.neckLevel ? gold : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (v.on(108) && m.neckLevel)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Neck level: more work left than time left at your usual pace. Shrink it, or start now.',
                            style: TextStyle(color: gold, fontWeight: FontWeight.w800))),
                  fact(101, 'Your own due date (48 h early)', dayLabel(m.fakeDue)),
                  fact(125, 'Start by', dayLabel(m.startBy)),
                  fact(102, 'Sessions left (25 min each)', '${m.sessionsLeft}'),
                  fact(117, 'Daily quota', '${m.quota} min'),
                  if (v.on(118) && m.quota != m.firstQuota) fact(118, 'Quota when you added it', '${m.firstQuota} min'),
                  fact(106, 'If you start today', '${m.panic().$1} min a day'),
                  fact(106, 'If you wait 5 days', '${m.panic().$2} min a day'),
                  fact(112, 'XP multiplier for work today', '${m.earlyBird.toStringAsFixed(1)}x'),
                  fact(111, 'Bonus if finished today', '+${decayingBonus(m.due - v.today)} XP'),
                  if (v.on(107)) ...[
                    const SizedBox(height: 8),
                    const H('Work done', size: 10),
                    Bar(m.pace.$1),
                    const SizedBox(height: 6),
                    const H('Time gone', size: 10),
                    Bar(m.pace.$2, color: m.pace.$2 > m.pace.$1 ? gold : cyan),
                  ],
                ])),
            if (v.on(103)) ...[
              const SizedBox(height: 16),
              const H('Backward plan'),
              for (final (day, label) in m.milestones)
                if (label.startsWith('Draft zero') ? v.on(113) : true)
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(day < v.today ? Icons.check : Icons.flag_outlined, color: day < v.today ? dim : cyan, size: 20),
                      title: Text(label),
                      trailing: Text(dayLabel(day), style: const TextStyle(color: dim))),
            ],
          ],
          const SizedBox(height: 16),
          if (m.hasDue)
            Wrap(spacing: 8, children: [
              OutlinedButton(key: const Key('postpone'), onPressed: postpone, child: const Text('POSTPONE')),
              if (v.on(192))
                OutlinedButton(key: const Key('moveTomorrow'), onPressed: () => app.moveToTomorrow(t), child: const Text('MOVE TO TOMORROW')),
              if (v.on(123))
                OutlinedButton(
                    key: const Key('shareDue'),
                    onPressed: () => ref.read(shareProvider)(
                        text: 'Hold me to this: "${t.str('title')}" is due ${dayLabel(m.due)}. I am aiming for ${dayLabel(m.fakeDue)}. Ask me how it is going.'),
                    child: const Text('TELL MY BUDDY')),
            ]),
        ]));
  }
}

// ---- Work vault tools (features 126 to 150) -----------------------------------
