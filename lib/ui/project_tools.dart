import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/events.dart';
import '../core/planning.dart';
import '../core/projects.dart';
import 'theme.dart';

/// Features 153, 154, 159, 168: project building tools.
class ProjectTool extends ConsumerStatefulWidget {
  const ProjectTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<ProjectTool> createState() => _ProjectToolState();
}

class _ProjectToolState extends ConsumerState<ProjectTool> {
  final c = TextEditingController();
  String? pid;
  int wd = 1, from = 9 * 60, to = 10 * 60;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final project = pid ?? (v.projects.isEmpty ? null : v.projects.first.id);
    Widget picker() => v.projects.isEmpty
        ? const Text('Add a project on the Plan tab first.', style: TextStyle(color: dim))
        : Wrap(spacing: 6, children: [
            for (final p in v.projects) ChoiceChip(label: Text(p.str('name')), selected: project == p.id, onSelected: (_) => setState(() => pid = p.id)),
          ]);
    Future<void> add(String title) => app.addRec(Kind.task, {'projectId': project, 'title': title, 'done': false, 'est': 25});
    switch (widget.n) {
      case 153:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          picker(),
          const SizedBox(height: 12),
          const Text('What is the first physical action? Keep answering until every step is under 25 minutes.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextField(key: const Key('wizardStep'), controller: c, decoration: const InputDecoration(hintText: 'Open the PDF to question 1')),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('wizardAdd'),
              onPressed: project == null || c.text.trim().isEmpty
                  ? null
                  : () async {
                      await add(c.text.trim());
                      c.clear();
                      setState(() {});
                    },
              child: const Text('ADD STEP, THEN ASK AGAIN')),
          if (project != null) for (final t in openTasks(v, project)) Text('• ${t.str('title')}${vague(t) ? '  (start it with a verb?)' : ''}'),
        ]);
      case 154:
        final steps = splitAssignment(c.text);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('The AI splitter is not connected (BACKEND.md). This simpler version cuts pasted text into steps at lines, bullets and sentences. You edit them afterwards.',
              style: TextStyle(color: gold)),
          const SizedBox(height: 8),
          picker(),
          const SizedBox(height: 8),
          TextField(key: const Key('splitText'), controller: c, minLines: 3, maxLines: 8, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Paste the assignment')),
          for (final s in steps) Text('• $s'),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('splitAdd'),
              onPressed: project == null || steps.isEmpty
                  ? null
                  : () async {
                      for (final s in steps) {
                        await add(s);
                      }
                      c.clear();
                      setState(() {});
                    },
              child: Text('ADD ${steps.length} TASKS')),
        ]);
      case 159:
        const names = ['Urgent and important: do now', 'Important, not urgent: schedule', 'Urgent, not important: keep it quick', 'Neither: drop or shelve'];
        final open = v.of(Kind.task).where((t) => !t.flag('done')).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mark tasks urgent or important on their task screen.', style: TextStyle(color: dim)),
          for (var q = 0; q < 4; q++) ...[
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: H(names[q], color: q == 0 ? accent : dim)),
            for (final t in open.where((t) => quadrant(t) == q))
              InkWell(onTap: () => context.push('/task/${t.id}'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('• ${t.str('title')}'))),
          ],
        ]);
      case 185:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in v.projects) ...[
            H(p.str('name')),
            Wrap(spacing: 6, children: [
              for (final n in const [0, 3, 5, 7, 10])
                ChoiceChip(
                    key: Key('target-${p.id}-$n'),
                    label: Text(n == 0 ? 'NONE' : '$n A WEEK'),
                    selected: p.integer('weekly') == n,
                    onSelected: (_) => app.putRec(p.copy({'weekly': n}))),
            ]),
            const SizedBox(height: 10),
          ],
          for (final (n, have, need) in weeklyTargets(v)) Text('$n: $have of $need sessions this week'),
        ]);
      case 179:
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('There is no file import. Add each class once: name, day, start and end.', style: TextStyle(color: dim)),
          const SizedBox(height: 8),
          TextField(key: const Key('className'), controller: c, decoration: const InputDecoration(hintText: 'Class name')),
          Wrap(spacing: 6, children: [
            for (var d = 1; d <= 7; d++) ChoiceChip(key: Key('wd-$d'), label: Text(names[d - 1]), selected: wd == d, onSelected: (_) => setState(() => wd = d)),
          ]),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final (label, cur, set) in [('FROM', from, (int x) => from = x), ('TO', to, (int x) => to = x)])
              TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
                    if (t != null) setState(() => set(t.hour * 60 + t.minute));
                  },
                  child: Text('$label ${hhmm(cur)}')),
            FilledButton(
                key: const Key('classAdd'),
                onPressed: () async {
                  if (c.text.trim().isEmpty || to <= from) return;
                  await app.addRec('class', {'name': c.text.trim(), 'wd': wd, 'from': from, 'to': to});
                  c.clear();
                },
                child: const Text('ADD')),
          ]),
          for (var d = 1; d <= 7; d++)
            for (final k in classesOn(v, d))
              ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${names[d - 1]} ${hhmm(k.integer('from'))} to ${hhmm(k.integer('to'))} · ${k.str('name')}'),
                  trailing: IconButton(tooltip: 'Remove this class', icon: const Icon(Icons.close, color: dim), onPressed: () => app.deleteRec(k.id))),
        ]);
      case 168:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in templates.entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                    key: Key('template-${e.key}'),
                    onPressed: wipFull(v)
                        ? () => toast(context, 'Three active projects is the limit. Finish or archive one first.')
                        : () async {
                            final p = await app.addRec(Kind.project, {'name': e.key});
                            for (final s in e.value) {
                              await app.addRec(Kind.task, {'projectId': p.id, 'title': s, 'done': false, 'est': 25});
                            }
                            if (context.mounted) toast(context, '${e.key} added with ${e.value.length} steps.');
                          },
                    child: Text('${e.key.toUpperCase()} · ${e.value.length} STEPS'))),
        ]);
    }
    return const SizedBox();
  }
}
