import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/flags.dart';
import '../core/stats.dart';
import '../core/tools.dart';
import 'share.dart';
import 'special.dart';
import 'theme.dart';

/// Features with their own screen instead of a generic tool: number -> route.
const customRoutes = <int, String>{9: '/ritual'};

/// Everything beyond the six tabs lives here, so Home stays one button.
class ToolboxScreen extends ConsumerStatefulWidget {
  const ToolboxScreen({super.key});
  @override
  ConsumerState<ToolboxScreen> createState() => _ToolboxState();
}

class _ToolboxState extends ConsumerState<ToolboxScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final tools = ref.watch(toolsProvider);
    bool has(Feature f) => tools.containsKey(f.n) || customRoutes.containsKey(f.n);
    final all = v.catalog.all.where((f) => has(f) && !f.v1 && f.built).toList();
    final shown = all.where((f) => q.isEmpty || '${f.name} ${f.desc}'.toLowerCase().contains(q.toLowerCase())).toList();
    final live = shown.where((f) => v.on(f.n)).toList();
    final locked = shown.where((f) => !v.on(f.n) && v.kv['flag.${f.n}'] != '0' && f.rank > v.rank.index).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return Scaffold(
        appBar: AppBar(title: const Text('TOOLBOX')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
          if (v.simpleMode)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Simple mode is on, so only the core app is showing. Switch it off in Settings to open the toolbox.',
                    style: TextStyle(color: dim)))
          else ...[
            TextField(
                key: const Key('toolSearch'),
                decoration: const InputDecoration(hintText: 'Search tools', prefixIcon: Icon(Icons.search)),
                onChanged: (s) => setState(() => q = s)),
            const SizedBox(height: 8),
            const Text('Optional extras. None of them is required. The one job is still two minutes a day.',
                style: TextStyle(color: dim, fontSize: 12)),
            for (final sec in v.catalog.sections)
              if (live.any((f) => f.sec == sec)) ...[
                Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: H(sec, color: cyan)),
                for (final f in live.where((f) => f.sec == sec))
                  ListTile(
                      key: Key('toolbox-${f.n}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(tools[f.n]?.title ?? f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(f.desc.isEmpty ? f.name : f.desc,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: dim, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(customRoutes[f.n] ?? '/tool/${f.n}')),
              ],
            if (locked.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 24, bottom: 6), child: H('Unlocks as you rank up')),
              for (final f in locked.take(8))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline, color: dim),
                    title: Text(f.name, style: const TextStyle(color: dim)),
                    subtitle: Text('At rank ${f.rank + 1}: ${v.ranks[f.rank.clamp(0, v.ranks.length - 1)].name}',
                        style: const TextStyle(color: dim, fontSize: 12))),
            ],
          ],
        ]));
  }
}

class ToolScreen extends ConsumerStatefulWidget {
  const ToolScreen(this.n, {super.key});
  final int n;
  @override
  ConsumerState<ToolScreen> createState() => _ToolState();
}

class _ToolState extends ConsumerState<ToolScreen> {
  final List<TextEditingController> c = [];
  String? choice;
  int minute = 9 * 60;
  bool loaded = false;

  @override
  void dispose() {
    for (final x in c) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final t = ref.watch(toolsProvider)[widget.n];
    final app = ref.read(appProvider.notifier);
    if (t == null || !v.on(widget.n)) {
      return Scaffold(
          appBar: AppBar(title: const Text('TOOL')),
          body: const Center(child: Text('This tool is switched off or not unlocked yet.')));
    }
    if (!loaded) {
      final init = t.kind == 'single'
          ? v.single(t)
          : List.filled(t.kind == 'log' ? t.prompts.length : (t.prompts.isEmpty ? 1 : t.prompts.length), '');
      c.addAll([for (final s in init) TextEditingController(text: s)]);
      loaded = true;
    }
    return Scaffold(
        appBar: AppBar(title: Text(t.title.toUpperCase())),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
          if (t.intro.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(t.intro, style: const TextStyle(color: dim, fontSize: 15))),
          if (t.setOptions.isNotEmpty) ...[
            H(t.setLabel),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in t.setOptions)
                ChoiceChip(
                    key: Key('tool-set-$o'),
                    label: Text('$o'),
                    selected: v.settingInt(t.optKey, t.setOptions.first) == o,
                    onSelected: (_) => app.setSetting(t.optKey, '$o')),
            ]),
            const SizedBox(height: 16),
          ],
          ...switch (t.kind) {
            'card' => [Panel(border: cyan, child: Text(t.body, style: const TextStyle(fontSize: 18, height: 1.4)))],
            'stat' => _stat(v, t),
            'single' => _single(v, t, app),
            'log' => _log(v, t, app),
            'list' => _list(v, t, app),
            'check' => _check(v, t, app),
            'count' => _count(v, t, app),
            'rate' => _rate(v, t, app),
            'habit' => _habit(v, t, app),
            'session' => [
                if (t.task.isNotEmpty)
                  Panel(border: cyan, child: Text(t.task, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(height: 20),
                FilledButton(
                    key: const Key('tool-start'),
                    onPressed: () async {
                      await app.startSession(minutes: t.minutes, title: t.task.isEmpty ? t.title : t.task, source: 'tool${t.n}');
                      await app.log(Ev.tool, {'n': t.n});
                      if (context.mounted) context.go('/timer');
                    },
                    child: Text('START ${t.minutes} MIN')),
              ],
            'toggle' => [
                SwitchListTile(
                    key: const Key('tool-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.setLabel),
                    value: v.kv[t.setKey] == '1',
                    onChanged: (x) async {
                      if (x) await app.setKv('${t.setKey}From', '${v.today}');
                      await app.setSetting(t.setKey, x ? '1' : '0');
                    }),
              ],
            'dayflag' => [
                SwitchListTile(
                    key: const Key('tool-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.setLabel),
                    subtitle: const Text('Switches itself off when the day ends.', style: TextStyle(color: dim, fontSize: 12)),
                    value: v.kv[t.setKey] == '${v.today}',
                    onChanged: (x) => app.setSetting(t.setKey, x ? '${v.today}' : '')),
              ],
            'special' => [specialTool(t.n, v)],
            'share' => [
                ..._fields(t),
                Panel(child: Text(fillTemplate(t.body, v, [for (final x in c) x.text]), key: const Key('share-preview'))),
                const SizedBox(height: 12),
                FilledButton(
                    key: const Key('tool-share'),
                    onPressed: () async {
                      await ref.read(shareProvider)(text: fillTemplate(t.body, v, [for (final x in c) x.text]));
                      await app.log(Ev.tool, {'n': t.n});
                    },
                    child: const Text('SHARE')),
              ],
            _ => [const Text('Unknown tool type.')],
          },
        ]));
  }

  List<Widget> _stat(DayView v, ToolDef t) {
    final lines = (stats[t.stat] ?? (_) => const ['-'])(v);
    return [
      Big(lines.first, size: 48, color: cyan, key: const Key('stat-value')),
      const SizedBox(height: 8),
      for (final l in lines.skip(1)) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, style: const TextStyle(fontSize: 16))),
      if (t.action.isNotEmpty) ...[
        const SizedBox(height: 16),
        FilledButton(
            key: const Key('tool-action'),
            onPressed: () => ref.read(appProvider.notifier).log(Ev.tool, {'n': t.n}),
            child: Text(t.action.toUpperCase())),
      ],
    ];
  }

  List<Widget> _fields(ToolDef t) => [
        for (var i = 0; i < c.length; i++) ...[
          if (t.prompts.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: H(t.prompts[i], color: Colors.white, size: 12)),
          TextField(key: Key('tool-field-$i'), controller: c[i], minLines: 1, maxLines: 4, onChanged: t.kind == 'share' ? (_) => setState(() {}) : null),
          const SizedBox(height: 12),
        ],
        if (t.choices.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ch in t.choices)
              ChoiceChip(key: Key('tool-choice-$ch'), label: Text(ch), selected: choice == ch, onSelected: (_) => setState(() => choice = ch)),
          ]),
      ];

  List<Widget> _single(DayView v, ToolDef t, App app) => [
        ..._fields(t),
        FilledButton(
            key: const Key('tool-save'),
            onPressed: () async {
              await app.setKv(t.kvKey, jsonEncode([for (final x in c) x.text.trim()]));
              await app.log(Ev.tool, {'n': t.n});
              if (mounted) toast(context, 'Saved.');
            },
            child: const Text('SAVE')),
      ];

  List<Widget> _log(DayView v, ToolDef t, App app) => [
        ..._fields(t),
        if (t.time)
          Row(children: [
            const Text('Remind me at '),
            TextButton(
                key: const Key('tool-time'),
                onPressed: () async {
                  final x = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
                  if (x != null) setState(() => minute = x.hour * 60 + x.minute);
                },
                child: Text(hhmm(minute), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
        const SizedBox(height: 8),
        FilledButton(
            key: const Key('tool-add'),
            onPressed: () async {
              final a = [for (final x in c) x.text.trim()];
              if (a.every((s) => s.isEmpty) && choice == null) return toast(context, 'Write a little something first.');
              await app.addRec(t.recKind, {'a': a, 'choice': choice, 'day': v.today, if (t.time) 'minute': minute});
              if (t.time) await app.syncNative();
              await app.log(Ev.tool, {'n': t.n, if (choice != null) 'choice': choice, if (t.xp > 0) 'xp': t.xp});
              for (final x in c) {
                x.clear();
              }
              setState(() => choice = null);
            },
            child: const Text('ADD')),
        const SizedBox(height: 20),
        for (final r in v.toolRecs(t))
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: H(
                          '${dayLabel(r.integer('day'))}${r.str('choice').isEmpty ? '' : ' · ${r.str('choice')}'}'
                          '${r.data['minute'] is int ? ' · ${hhmm(r.integer('minute'))}' : ''}',
                          size: 10)),
                  InkWell(
                      onTap: () async {
                        await app.deleteRec(r.id);
                        if (t.time) await app.syncNative();
                      },
                      child: const Icon(Icons.close, size: 18, color: dim)),
                ]),
                for (final (i, a) in ((r.data['a'] as List?)?.cast<String>() ?? const <String>[]).indexed)
                  if (a.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(t.prompts.length > 1 && i < t.prompts.length ? '${t.prompts[i]}: $a' : a)),
              ]))),
      ];

  List<Widget> _list(DayView v, ToolDef t, App app) => [
        Row(children: [
          Expanded(child: TextField(key: const Key('tool-field-0'), controller: c[0], decoration: InputDecoration(hintText: t.prompts.isEmpty ? 'Add one' : t.prompts.first))),
          const SizedBox(width: 8),
          FilledButton(
              key: const Key('tool-add'),
              onPressed: () async {
                if (c[0].text.trim().isEmpty) return;
                await app.addRec(t.recKind, {'text': c[0].text.trim(), 'done': false, 'day': v.today});
                await app.log(Ev.tool, {'n': t.n});
                c[0].clear();
              },
              child: const Text('ADD')),
        ]),
        const SizedBox(height: 12),
        for (final r in v.toolRecs(t).reversed)
          CheckboxListTile(
              key: Key('tool-item-${r.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: r.flag('done'),
              onChanged: (_) => app.putRec(r.copy({'done': !r.flag('done')})),
              title: Text(r.str('text'), style: TextStyle(decoration: r.flag('done') ? TextDecoration.lineThrough : null)),
              secondary: IconButton(icon: const Icon(Icons.close, color: dim), onPressed: () => app.deleteRec(r.id))),
      ];

  List<Widget> _check(DayView v, ToolDef t, App app) {
    final done = v.checked(t.n, v.today);
    final streak = computeToolCheckStreak(v, t);
    return [
      for (final (i, item) in t.items.indexed)
        CheckboxListTile(
            key: Key('tool-check-$i'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: done.contains(i),
            onChanged: done.contains(i) ? null : (_) => app.toolTick(t, i),
            title: Text(item)),
      const SizedBox(height: 12),
      Text(done.length >= t.items.length ? 'All done for today.' : '${done.length} of ${t.items.length} today.',
          style: const TextStyle(color: cyan, fontWeight: FontWeight.w800)),
      Text('Completed $streak days in a row.', style: const TextStyle(color: dim)),
    ];
  }

  List<Widget> _count(DayView v, ToolDef t, App app) => [
        Center(child: Big('${v.toolSum(t.n, day: v.today)}', size: 96, color: cyan, key: const Key('tool-count'))),
        Center(child: H('${t.unit} today')),
        const SizedBox(height: 20),
        FilledButton(key: const Key('tool-plus'), onPressed: () => app.log(Ev.tool, {'n': t.n, 'add': 1}), child: const Text('+1')),
        const SizedBox(height: 12),
        Center(child: Text('Lifetime: ${v.toolSum(t.n)} ${t.unit}', style: const TextStyle(color: dim))),
      ];

  List<Widget> _rate(DayView v, ToolDef t, App app) {
    final r = v.toolRatings(t.n);
    final last = r.length > 14 ? r.sublist(r.length - 14) : r;
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 1; i <= t.max; i++)
          SizedBox(
              width: 56,
              child: OutlinedButton(
                  key: Key('tool-rate-$i'),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () async {
                    await app.log(Ev.tool, {'n': t.n, 'value': i});
                    if (mounted) toast(context, 'Logged $i.');
                  },
                  child: Text('$i'))),
      ]),
      if (t.choices.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('1 = ${t.choices.first}, ${t.max} = ${t.choices.last}', style: const TextStyle(color: dim))),
      const SizedBox(height: 24),
      if (last.isNotEmpty) const H('Last entries'),
      const SizedBox(height: 8),
      SizedBox(
          height: 80,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (_, val) in last)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FractionallySizedBox(heightFactor: (val / t.max).clamp(0.05, 1.0), child: Container(color: cyan)))),
          ])),
    ];
  }

  List<Widget> _habit(DayView v, ToolDef t, App app) {
    final h = v.habitFor(t);
    if (h == null) {
      return [
        Panel(border: cyan, child: Text(t.habit, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        FilledButton(
            key: const Key('tool-add-habit'),
            onPressed: () => app.addRec(Kind.habit, {'name': t.habit, 'feature': t.n}),
            child: const Text('ADD THIS HABIT')),
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('It gets its own streak on the Streaks tab.', style: TextStyle(color: dim))),
      ];
    }
    final s = v.habitStreak(h.id);
    return [
      Panel(
          border: cyan,
          child: Row(children: [
            Expanded(child: Text(h.str('name'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Big('${s.current}', size: 40, color: cyan),
          ])),
      const SizedBox(height: 16),
      v.tickedToday(h.id)
          ? const Text('Done today.', style: TextStyle(color: cyan, fontWeight: FontWeight.w800))
          : FilledButton(key: const Key('tool-tick'), onPressed: () => app.tickHabit(h.id), child: const Text('DONE TODAY')),
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Longest: ${s.longest} days.', style: const TextStyle(color: dim))),
    ];
  }
}

int computeToolCheckStreak(DayView v, ToolDef t) {
  final days = v.checkCompleteDays(t);
  var n = 0;
  for (var d = days.contains(v.today) ? v.today : v.today - 1; days.contains(d); d--) {
    n++;
  }
  return n;
}

/// Every feature with its flag (feature 489) and build status.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final built = v.catalog.all.where((f) => f.built).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('FEATURES')),
        body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
            itemCount: built.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        '${built.length} of ${v.catalog.all.length} features are built. Each has its own switch. '
                        'Version 1 features cannot be hidden here, they have their own delayed switches in Settings.',
                        style: const TextStyle(color: dim)));
              }
              final f = built[i - 1];
              final on = v.kv['flag.${f.n}'] == null ? f.on : v.kv['flag.${f.n}'] == '1';
              return SwitchListTile(
                  key: Key('flag-${f.n}'),
                  dense: true,
                  value: f.v1 || on,
                  onChanged: f.v1 ? null : (x) => app.setSetting('flag.${f.n}', x ? '1' : '0'),
                  title: Text('${f.n}. ${f.name}'),
                  subtitle: Text('${f.status}${f.rank > v.rank.index && !f.v1 ? ' · unlocks at rank ${f.rank + 1}' : ''}',
                      style: const TextStyle(color: dim, fontSize: 11)));
            }));
  }
}
