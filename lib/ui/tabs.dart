import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/extras.dart';
import '../core/game.dart';
import '../core/projects.dart';
import '../core/rules.dart';
import '../core/stats.dart';
import '../core/streak_engine.dart';
import '../core/vault.dart';
import 'home.dart';
import 'theme.dart';

Widget _page(String title, List<Widget> children, {Widget? fab, List<Widget>? actions}) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    floatingActionButton: fab,
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: children));

Widget _stat(String label, String value, {Color? color}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Big(value, size: 34, color: color),
      const SizedBox(height: 2),
      H(label, size: 10),
    ]));

/// Freezes shown as lives.
class Lives extends StatelessWidget {
  const Lives(this.left, {super.key, this.total = 2});
  final int left;
  final int total;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < (left > total ? left : total); i++)
          Icon(i < left ? Icons.favorite : Icons.favorite_border, color: i < left ? cyan : dim, size: 22),
      ]);
}

// ---- STREAKS ------------------------------------------------------------
class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  Widget _habitCard(BuildContext context, DayView v, App app, Rec h) {
    final days = v.habitDays(h.id);
    final s = v.habitStreak(h.id);
    final weekly = v.on(29) ? h.integer('weekly') : 0;
    final open = !v.on(49) || inWindow(h, v.now.minuteOfDay);
    final tiny = v.on(28) ? h.str('tiny') : '';
    final small = v.on(64) && restartAtTiny(v, h.id);
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel(
            key: Key('habit-${h.id}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: InkWell(
                        onTap: () => context.push('/habit/${h.id}'),
                        child: Text(h.str('name'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
                if (v.tickedToday(h.id))
                  const Icon(Icons.check_circle, color: cyan, size: 36)
                else if (open)
                  FilledButton(
                      key: Key('tick-${h.id}'),
                      onPressed: () async {
                        if (v.on(137) && h.flag('proofRequired')) {
                          final proof = await askText(context, 'Proof in one line', hint: 'What exactly did you do?', ok: 'COUNT IT');
                          if (proof == null || proof.trim().isEmpty) return;
                          await app.tickHabit(h.id, proof: proof);
                        } else {
                          await app.tickHabit(h.id);
                        }
                      },
                      child: const Text('DONE'))
                else
                  const Icon(Icons.schedule, color: dim),
              ]),
              if (!v.tickedToday(h.id) && open && tiny.isNotEmpty)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        key: Key('tiny-${h.id}'),
                        onPressed: () => app.tickHabit(h.id, tiny: true),
                        child: Text('TINY VERSION: ${tiny.toUpperCase()}'))),
              if (small)
                Text('Restarting small: for three days ${tiny.isEmpty ? 'the tiniest version' : '"$tiny"'} is all that is asked.',
                    style: const TextStyle(color: cyan)),
              if (!open)
                Text('Counts between ${hhmm(h.integer('from'))} and ${hhmm(h.integer('to'))}.', style: const TextStyle(color: dim)),
              const SizedBox(height: 12),
              Row(children: [
                if (weekly > 0) ...[
                  _stat('Weeks', '${weeklyStreak(days, v.today, weekly)}', color: cyan),
                  _stat('This week', '${doneThisWeek(days, v.today)}/$weekly'),
                ] else ...[
                  _stat('Current', '${s.current}', color: s.state == StreakState.paused ? dim : cyan),
                  _stat('Longest', '${s.longest}'),
                ],
                _stat('Total days', '${s.totalDays}'),
              ]),
              const SizedBox(height: 12),
              Heatmap(today: v.today, level: (d) => days.contains(d) ? 3 : s.frozenDays.contains(d) ? -1 : 0),
            ])));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    return _page('STREAKS', [
      Panel(
          child: Row(children: [
        const Poster(PosterArt.shield, size: 48),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H('Freezes left this month'),
          const SizedBox(height: 6),
          Lives(v.master.freezesLeft, key: const Key('lives')),
          const SizedBox(height: 6),
          const Text('A missed day uses one automatically. With none left, one miss only pauses the streak. It takes two in a row to break it.',
              style: TextStyle(color: dim, fontSize: 12)),
        ])),
      ])),
      const SizedBox(height: 14),
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
              key: const Key('masterCard'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SHOWED UP (master)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(children: [
                  _stat('Current', '${v.master.current}', color: v.master.state == StreakState.paused ? dim : cyan),
                  _stat('Longest', '${v.master.longest}'),
                  _stat('Total days', '${v.master.totalDays}'),
                  if (v.on(69)) _stat('Last 30', '${consistency(v)}%'),
                ]),
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  final half = v.on(68) ? halfDays(v) : const <int>{};
                  final golds = v.on(75) ? goldDays(v) : const <int>{};
                  return Heatmap(
                      today: v.today,
                      level: (d) => golds.contains(d)
                          ? 4
                          : v.showedUpDays.contains(d)
                              ? 3
                              : v.master.frozenDays.contains(d)
                                  ? -1
                                  : half.contains(d)
                                      ? 1
                                      : 0);
                }),
                const SizedBox(height: 8),
                Text(streakLine(v.master), style: const TextStyle(color: dim)),
                if (v.on(56) && v.master.comebacks > 0)
                  Text('Comebacks: ${v.master.comebacks}. That is the skill that matters.', style: const TextStyle(color: cyan)),
              ]))),
      if (v.on(34))
        Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
                key: const Key('track66'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  H('66-day track · ${v.master.current.clamp(0, 66)} of 66'),
                  const SizedBox(height: 8),
                  Bar(v.master.current / 66),
                  const SizedBox(height: 6),
                  const Text('In one UCL study, 66 days was the median time for a habit to become automatic. It varied a lot between people.',
                      style: TextStyle(color: dim, fontSize: 12)),
                ]))),
      if (examOn(v))
        const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Exam mode: only your exam set is showing. Other habits are paused, not broken.', style: TextStyle(color: gold))),
      for (final h in v.habits)
        if (!examOn(v) || h.flag('exam')) _habitCard(context, v, app, h),
      if (v.maintained.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: H('Maintained (runs on its own now)')),
        for (final h in v.maintained)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified, color: cyan),
              title: Text(h.str('name')),
              subtitle: Text('${v.habitDays(h.id).length} days done', style: const TextStyle(color: dim)),
              onTap: () => context.push('/habit/${h.id}')),
      ],
      if (v.habits.isEmpty)
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No habits yet. Add one tiny action, like "Open the book". Small on purpose.',
                style: TextStyle(color: dim))),
    ],
        fab: FloatingActionButton.extended(
            key: const Key('addHabit'),
            onPressed: () async {
              final name = await askText(context, 'New tiny habit', hint: 'Open the book', ok: 'ADD');
              if (name != null && name.trim().isNotEmpty) await app.addRec(Kind.habit, {'name': name.trim()});
            },
            backgroundColor: cyan,
            foregroundColor: ink,
            icon: const Icon(Icons.add),
            label: const Text('HABIT', style: TextStyle(fontWeight: FontWeight.w900))));
  }
}

// ---- VAULT ---------------------------------------------------------------
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});
  @override
  ConsumerState<VaultScreen> createState() => _VaultState();
}

class _VaultState extends ConsumerState<VaultScreen> {
  String? project;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final items = searchProofs(v, v.on(140) ? q : '', projectId: project);
    final memories = v.on(148) ? onThisDay(v) : const <(String, Rec)>[];
    int? lastDay;
    return _page('VAULT', actions: [
      if (v.on(147) && backupStale(v))
        IconButton(
            key: const Key('backupWarning'),
            tooltip: 'Not backed up',
            icon: const Icon(Icons.warning_amber, color: gold),
            onPressed: () => toast(context, 'The vault has not been exported in the last 7 days. Me, Settings, Export JSON makes a backup file.')),
    ], [
      if (v.on(140))
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
                key: const Key('vaultSearch'),
                decoration: const InputDecoration(hintText: 'Search proof, task, project or tag', prefixIcon: Icon(Icons.search)),
                onChanged: (x) => setState(() => q = x))),
      for (final (label, p) in memories)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
                border: gold,
                child: Text('$label today: ${p.str('type') == 'photo' ? 'a photo for "${p.str('title')}"' : p.str('value')}'))),
      if (v.projects.isNotEmpty)
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('ALL'), selected: project == null, onSelected: (_) => setState(() => project = null))),
              for (final pr in v.projects)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(pr.str('name')),
                        selected: project == pr.id,
                        onSelected: (_) => setState(() => project = pr.id))),
            ])),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Column(children: [
              Poster(PosterArt.vault, size: 120),
              SizedBox(height: 16),
              Text('Empty for now. Every finished session drops one piece of proof in here.',
                  textAlign: TextAlign.center, style: TextStyle(color: dim)),
            ])),
      for (final pr in items) ...[
        if (lastDay != (lastDay = pr.integer('day')))
          Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: H(dayLabel(pr.integer('day')))),
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
                key: Key('proof-${pr.id}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(
                        switch (pr.str('type')) { 'photo' => Icons.photo_camera, 'link' => Icons.link, 'voice' => Icons.mic, _ => Icons.notes },
                        color: cyan,
                        size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: H(
                            '${pr.integer('minutes')} min · ${v.rec(pr.str('projectId'))?.str('name') ?? 'No project'}'
                            '${pr.integer('units') > 0 ? ' · ${pr.integer('units')} ${pr.str('unit')}' : ''}'
                            '${pr.str('tag').isEmpty ? '' : ' · ${pr.str('tag')}'}',
                            size: 11)),
                    if (v.on(139))
                      InkWell(
                          key: Key('pin-${pr.id}'),
                          onTap: () => app.putRec(pr.copy({'pinned': !pr.flag('pinned')})),
                          child: Icon(pr.flag('pinned') ? Icons.push_pin : Icons.push_pin_outlined, color: pr.flag('pinned') ? gold : dim, size: 20)),
                  ]),
                  const SizedBox(height: 8),
                  if (pr.str('type') == 'photo')
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(pr.str('value')),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Text('Photo file is missing.', style: TextStyle(color: dim))))
                  else if (pr.str('type') == 'voice')
                    TextButton.icon(
                        onPressed: () => ref.read(nativeProvider).play(pr.str('value')),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('PLAY VOICE NOTE'))
                  else
                    SelectableText(pr.str('value'), style: const TextStyle(fontSize: 16)),
                ]))),
      ],
    ]);
  }
}

// ---- PLAN ----------------------------------------------------------------
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});
  @override
  ConsumerState<PlanScreen> createState() => _PlanState();
}

class _PlanState extends ConsumerState<PlanScreen> {
  final task = TextEditingController();
  int? cue;
  bool loaded = false;

  @override
  void dispose() {
    task.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final plan = v.tomorrowPlan;
    if (!loaded) {
      task.text = plan?.task ?? '';
      cue = plan?.cueMinute ?? v.cueMinute;
      loaded = true;
    }
    final locked = v.planLocked;
    return _page('PLAN', [
      Panel(
          key: const Key('planCard'),
          border: locked ? gold : cyan,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: H("Tomorrow's first task", color: locked ? gold : cyan)),
              if (locked) const Icon(Icons.lock, color: gold, key: Key('planLock')),
            ]),
            const SizedBox(height: 10),
            if (locked) ...[
              Text(plan!.task, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Alarm at ${hhmm(plan.cueMinute)}. Locked since 10 pm, so tomorrow-you has nothing to negotiate.',
                  style: const TextStyle(color: dim)),
            ] else ...[
              TextField(
                  key: const Key('planTask'),
                  controller: task,
                  maxLength: 120,
                  decoration: const InputDecoration(hintText: 'Open notebook to page 12')),
              Row(children: [
                const Text('Alarm at '),
                TextButton(
                    key: const Key('planCue'),
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: TimeOfDay(hour: cue! ~/ 60, minute: cue! % 60));
                      if (t != null) setState(() => cue = t.hour * 60 + t.minute);
                    },
                    child: Text(hhmm(cue!), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                const Spacer(),
                FilledButton(
                    key: const Key('planSave'),
                    onPressed: () async {
                      if (task.text.trim().isEmpty) return toast(context, 'Write the first tiny action first.');
                      final ok = await app.setPlan(task.text, cue!);
                      if (context.mounted) {
                        toast(context, ok ? 'Set. It locks at 10 pm.' : 'Already locked for tonight.');
                        if (!startsWithVerb(task.text)) {
                          toast(context, 'Tip: start with a verb, like "Open" or "Write". Easier to begin.');
                        }
                      }
                    },
                    child: const Text('SET')),
              ]),
              const Text('You can edit this until 10 pm. After that it is locked until tomorrow ends.',
                  style: TextStyle(color: dim, fontSize: 12)),
            ],
          ])),
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: H('Projects')),
        TextButton.icon(
            key: const Key('addProject'),
            onPressed: () async {
              if (wipFull(v)) return toast(context, 'Three active projects is the limit. Finish or archive one first, so each gets real attention.');
              final name = await askText(context, 'New project', hint: 'DSA practice', ok: 'ADD');
              if (name != null && name.trim().isNotEmpty) await app.addRec(Kind.project, {'name': name.trim()});
            },
            icon: const Icon(Icons.add),
            label: const Text('PROJECT')),
      ]),
      if (v.projects.isEmpty)
        const Text('No projects yet. A project keeps its sessions, tasks and proof together.', style: TextStyle(color: dim)),
      for (final pr in v.projects)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Panel(
                padding: 4,
                child: ExpansionTile(
                    key: Key('project-${pr.id}'),
                    shape: const Border(),
                    title: Text(pr.str('name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    subtitle: Text(
                        '${v.tasksOf(pr.id).where((t) => !t.flag('done')).length} open · '
                        '${v.type(Ev.sessionDone).where((e) => e.get<String>('projectId') == pr.id).length} sessions · '
                        '${v.proofs.where((p) => p.str('projectId') == pr.id).length} proof',
                        style: const TextStyle(color: dim)),
                    children: [
                      if (v.on(170)) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Bar(headStart(v, pr.id), height: 6)),
                      if (v.on(152))
                        ListTile(
                            dense: true,
                            title: Text(pr.str('why').isEmpty ? 'Add one line: why does this matter to you?' : 'Why: ${pr.str('why')}',
                                style: const TextStyle(color: dim)),
                            onTap: () async {
                              final w = await askText(context, 'Why it matters', initial: pr.str('why'));
                              if (w != null) await app.putRec(pr.copy({'why': w.trim()}));
                            }),
                      if (v.on(155))
                        ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_forward, color: cyan, size: 18),
                            title: Text(nextAction(v, pr.id)?.str('title') ?? 'No next action defined. Add one small task.',
                                key: Key('next-${pr.id}'), style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (v.on(171) && projectSessionsLeft(v, pr.id) > 0 && projectSessionsLeft(v, pr.id) <= 3)
                        ListTile(dense: true, title: Text('Almost there: ${projectSessionsLeft(v, pr.id)} sessions left to finish.', style: const TextStyle(color: cyan))),
                      for (final t in v.tasksOf(pr.id))
                        CheckboxListTile(
                            key: Key('task-${t.id}'),
                            value: t.flag('done'),
                            onChanged: (_) => app.toggleTask(t),
                            controlAffinity: ListTileControlAffinity.leading,
                            subtitle: t.data['due'] is int ? Text('Due ${dayLabel(t.integer('due'))}', style: const TextStyle(color: dim, fontSize: 12)) : null,
                            secondary: IconButton(
                                key: Key('due-${t.id}'),
                                tooltip: 'Due date and deadline tools',
                                icon: const Icon(Icons.chevron_right, color: dim),
                                onPressed: () => context.push('/task/${t.id}')),
                            title: Text(
                                '${v.on(162) && t.flag('frog') ? '🐸 ' : ''}${v.on(173) && blocked(v, t) ? '🔒 ' : ''}${t.str('title')}'
                                '${v.on(167) && vague(t) ? '  (verb?)' : ''}'
                                '${v.on(193) && t.integer('moved') >= 3 ? '  (moved ${t.integer('moved')} times)' : ''}',
                                style: TextStyle(
                                    decoration: t.flag('done') ? TextDecoration.lineThrough : null,
                                    color: t.flag('done') ? dim : null))),
                      Row(children: [
                        TextButton.icon(
                            onPressed: () async {
                              final title = await askText(context, 'New task', hint: 'Write the first function', ok: 'ADD');
                              if (title != null && title.trim().isNotEmpty) {
                                await app.addRec(Kind.task, {'projectId': pr.id, 'title': title.trim(), 'done': false});
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('TASK')),
                        const Spacer(),
                        TextButton(
                            onPressed: () async {
                              await app.putRec(pr.copy({'archived': true}));
                            },
                            child: const Text('ARCHIVE')),
                        TextButton(
                            onPressed: () async {
                              await app.startSession(projectId: pr.id);
                              if (context.mounted) context.go('/timer');
                            },
                            child: const Text('START 2 MIN')),
                      ]),
                    ]))),
    ]);
  }
}

// ---- ME ------------------------------------------------------------------
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final ach = ref.watch(achievementsProvider);
    final r = shownRank(v);
    final earned = ach.where((a) => a.earned(v.metrics)).length;
    return _page('ME', actions: [
      IconButton(key: const Key('openSettings'), onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings)),
    ], [
      Panel(
          border: cyan,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H(v.name.isEmpty ? 'Rank' : '${v.name} · rank ${r.index + 1} of ${v.ranks.length}'),
            const SizedBox(height: 6),
            Text(r.rank.name.toUpperCase(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cyan, height: 1.1)),
            const SizedBox(height: 6),
            Text(r.rank.blurb, style: const TextStyle(color: dim)),
            if (idleSteps(v) > 0)
              const Text('Your title slipped a step while you were away. One session brings it back. Nothing you unlocked is lost.',
                  style: TextStyle(color: gold)),
            if (v.on(229)) Text('Level ${levelFor(v.xpTotal)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Big('${v.xpTotal}', size: 44, key: const Key('xpTotal')),
              const Padding(padding: EdgeInsets.only(left: 6, bottom: 6), child: H('XP')),
            ]),
            const SizedBox(height: 8),
            Bar(r.progress),
            const SizedBox(height: 6),
            Text(r.next == null ? 'Top of the ladder. Keep showing up.' : '${r.next!.xp - v.xpTotal} XP to the next rank.',
                style: const TextStyle(color: dim)),
          ])),
      const SizedBox(height: 14),
      Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Where the XP came from'),
        const SizedBox(height: 8),
        for (final (label, n) in [
          ('Starting ($xpStart each)', v.xp.starts),
          ('Minutes ($xpPerMinute each)', v.xp.minutes),
          ('Proof ($xpProof each)', v.xp.proof),
          ('Habit ticks ($xpHabitTick each)', v.xp.habits),
          ('Daily bonus kept', v.xp.bonus),
          if (v.xp.extra != 0) ('Extras', v.xp.extra),
          ...v.xpExtras,
        ])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [Expanded(child: Text(label)), Text('$n', style: const TextStyle(fontWeight: FontWeight.w800))])),
      ])),
      const SizedBox(height: 14),
      Panel(
          onTap: () => context.push('/settings'),
          child: Row(children: [
            const Icon(Icons.person_outline, color: cyan),
            const SizedBox(width: 12),
            Expanded(
                child: Text((v.kv[K.buddyPhone] ?? '').isEmpty
                    ? 'No buddy yet. Add one person who gets your daily result.'
                    : 'Buddy: ${v.kv[K.buddyName] ?? ''} ${v.kv[K.buddyPhone]}')),
            const Icon(Icons.chevron_right),
          ])),
      if (!v.simpleMode) ...[
        const SizedBox(height: 14),
        Panel(
            key: const Key('openToolbox'),
            onTap: () => context.push('/toolbox'),
            child: const Row(children: [
              Icon(Icons.handyman_outlined, color: cyan),
              SizedBox(width: 12),
              Expanded(child: Text('Toolbox: optional extras that unlock as you rank up.')),
              Icon(Icons.chevron_right),
            ])),
      ],
      const SizedBox(height: 20),
      H('Achievements · $earned of ${ach.length}'),
      const SizedBox(height: 8),
      for (final a in ach)
        if (!a.hidden || a.earned(v.metrics))
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.earned(v.metrics) ? Icons.military_tech : Icons.lock_outline,
                  color: a.earned(v.metrics) ? gold : dim, size: 30),
              title: Text(a.name, style: TextStyle(fontWeight: FontWeight.w800, color: a.earned(v.metrics) ? null : dim)),
              subtitle: Text(a.desc, style: const TextStyle(color: dim))),
    ]);
  }
}
