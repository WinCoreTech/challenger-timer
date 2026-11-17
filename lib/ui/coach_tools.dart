import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/events.dart';
import '../core/coach.dart';
import '../core/tools.dart';
import 'theme.dart';

/// Features 520, 531, 538, 543, 529: small coach tools with fixed rules.
class CoachTool extends ConsumerStatefulWidget {
  const CoachTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<CoachTool> createState() => _CoachState();
}

class _CoachState extends ConsumerState<CoachTool> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    const note = Text('Fixed rules on your phone, not an AI. It never guesses facts about you.', style: TextStyle(color: dim, fontSize: 12));
    switch (widget.n) {
      case 531:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('excuse'), controller: c, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Type the excuse exactly as it sounds in your head')),
          const SizedBox(height: 12),
          if (c.text.trim().isNotEmpty) Panel(border: cyan, child: Text(excuseReply(c.text), key: const Key('excuseReply'), style: const TextStyle(fontSize: 17))),
          const SizedBox(height: 8),
          note,
        ]);
      case 529:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('vague'), controller: c, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'study ML')),
          const SizedBox(height: 12),
          if (c.text.trim().isNotEmpty) Panel(border: cyan, child: Text(rewriteTask(c.text), key: const Key('rewritten'), style: const TextStyle(fontSize: 17))),
          const SizedBox(height: 8),
          note,
        ]);
      case 543:
        final due = extractDeadline(c.text, v.today);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('notice'), controller: c, minLines: 2, maxLines: 6, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Paste the notice or message')),
          const SizedBox(height: 8),
          Text(due == null ? 'No date found yet.' : 'Due date found: ${dayLabel(due)}', key: const Key('foundDue'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('noticeAdd'),
              onPressed: due == null || v.projects.isEmpty
                  ? null
                  : () async {
                      final title = c.text.trim().split('\n').first;
                      await app.addRec(Kind.task, {'projectId': v.projects.first.id, 'title': title.length > 80 ? title.substring(0, 80) : title, 'done': false, 'due': due, 'est': 50});
                      c.clear();
                      setState(() {});
                    },
              child: Text(v.projects.isEmpty ? 'ADD A PROJECT FIRST' : 'ADD AS A TASK IN ${v.projects.first.str('name').toUpperCase()}')),
          note,
        ]);
      case 538:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton.icon(
              key: const Key('journalSpeak'),
              onPressed: () async {
                final heard = await ref.read(nativeProvider).listen();
                if (heard != null && heard.trim().isNotEmpty) await app.addRec('t538', {'a': [heard.trim()], 'day': v.today});
              },
              icon: const Icon(Icons.mic),
              label: const Text('SPEAK AN ENTRY')),
          for (final r in v.of('t538').reversed) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${dayLabel(r.integer('day'))}: ${(r.data['a'] as List).first}')),
        ]);
      case 520:
        const pack = ['Open the book', 'One DSA problem', 'Pack the bag at night'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final h in pack) Text('• $h'),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('starterPack'),
              onPressed: () async {
                final have = {for (final h in v.allHabits) h.str('name')};
                for (final h in pack) {
                  if (!have.contains(h)) await app.addRec(Kind.habit, {'name': h});
                }
              },
              child: const Text('ADD THESE HABITS')),
          const Text('Project templates (lab record, assignment, exam prep, hackathon) are in the Templates tool.', style: TextStyle(color: dim)),
        ]);
    }
    return const SizedBox();
  }
}

/// Features 551, 552, 571, 572: build a routine, run it step by step, time it.
class RoutineTool extends ConsumerStatefulWidget {
  const RoutineTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<RoutineTool> createState() => _RoutineState();
}

class _RoutineState extends ConsumerState<RoutineTool> {
  final c = TextEditingController();
  int step = -1;
  int startedMs = 0;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final kind = widget.n == 552 ? 'routine552' : 'routine551';
    final steps = v.of(kind);
    final runs = v.toolEvents(widget.n).where((e) => e.get<int>('seconds') != null).toList();
    final best = runs.isEmpty ? null : runs.map((e) => e.get<int>('seconds')!).reduce((a, b) => a < b ? a : b);
    if (step >= 0 && step < steps.length) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H('Step ${step + 1} of ${steps.length}'),
        const SizedBox(height: 12),
        Text(steps[step].str('text'), key: const Key('routineStep'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        FilledButton(
            key: const Key('routineNext'),
            onPressed: () async {
              if (step + 1 >= steps.length) {
                final secs = (ref.read(clockProvider)().ms - startedMs) ~/ 1000;
                await app.log(Ev.tool, {'n': widget.n, 'seconds': secs});
                app.celebrate();
                setState(() => step = -1);
              } else {
                setState(() => step++);
              }
            },
            child: Text(step + 1 >= steps.length ? 'DONE' : 'NEXT')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (steps.isNotEmpty)
        FilledButton(
            key: const Key('routineRun'),
            onPressed: () => setState(() {
                  step = 0;
                  startedMs = ref.read(clockProvider)().ms;
                }),
            child: const Text('RUN IT STEP BY STEP')),
      if (best != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Best time: ${best ~/ 60} min ${best % 60} s over ${runs.length} runs. Last: ${runs.last.get<int>('seconds')! ~/ 60} min ${runs.last.get<int>('seconds')! % 60} s.')),
      const SizedBox(height: 12),
      for (final s in steps)
        ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(s.str('text')), trailing: IconButton(icon: const Icon(Icons.close, color: dim), onPressed: () => app.deleteRec(s.id))),
      Row(children: [
        Expanded(child: TextField(key: const Key('routineField'), controller: c, decoration: const InputDecoration(hintText: 'Next step in the routine'))),
        const SizedBox(width: 8),
        FilledButton(
            key: const Key('routineAdd'),
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              await app.addRec(kind, {'text': c.text.trim()});
              c.clear();
            },
            child: const Text('ADD')),
      ]),
    ]);
  }
}
