import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/events.dart';
import '../core/analytics.dart';
import '../core/study.dart';
import 'share.dart';
import 'theme.dart';

/// Features 404, 405, 410, 414, 450.
class StudyTool extends ConsumerStatefulWidget {
  const StudyTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<StudyTool> createState() => _StudyState();
}

class _StudyState extends ConsumerState<StudyTool> {
  final a = TextEditingController(), b = TextEditingController();
  bool show = false;
  int days = 7;
  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    switch (widget.n) {
      case 404 || 405:
        final due = dueCards(v);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          H('${due.length} to review today · ${v.of('card').length} cards in total'),
          const SizedBox(height: 8),
          if (due.isNotEmpty) ...[
            Panel(
                border: cyan,
                onTap: () => setState(() => show = !show),
                child: Text(show ? due.first.str('back') : due.first.str('front'), key: const Key('cardFace'), style: const TextStyle(fontSize: 20))),
            const SizedBox(height: 8),
            if (!show)
              OutlinedButton(key: const Key('cardFlip'), onPressed: () => setState(() => show = true), child: const Text('SHOW ANSWER'))
            else
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        key: const Key('cardMiss'),
                        onPressed: () {
                          app.putRec(due.first.copy(reviewed(due.first, v.today, correct: false)));
                          setState(() => show = false);
                        },
                        child: const Text('NOT YET'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton(
                        key: const Key('cardGot'),
                        onPressed: () {
                          app.putRec(due.first.copy(reviewed(due.first, v.today, correct: true)));
                          app.log(Ev.tool, {'n': 404});
                          setState(() => show = false);
                        },
                        child: const Text('GOT IT'))),
              ]),
            const SizedBox(height: 16),
          ],
          TextField(key: const Key('cardFront'), controller: a, decoration: const InputDecoration(hintText: 'Question or topic')),
          const SizedBox(height: 6),
          TextField(key: const Key('cardBack'), controller: b, decoration: const InputDecoration(hintText: 'Answer or key points')),
          const SizedBox(height: 6),
          FilledButton(
              key: const Key('cardAdd'),
              onPressed: () async {
                if (a.text.trim().isEmpty) return;
                await app.addRec('card', {'front': a.text.trim(), 'back': b.text.trim(), 'step': 0, 'next': v.today + 1});
                a.clear();
                b.clear();
              },
              child: const Text('ADD CARD (FIRST REVIEW TOMORROW)')),
          const Text('Reviews come back after 1, 3, 7 and 21 days.', style: TextStyle(color: dim)),
        ]);
      case 410:
        final units = a.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        final plan = units.isEmpty ? const <List<String>>[] : examPlan(units, days);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('units'), controller: a, minLines: 3, maxLines: 8, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'One unit per line')),
          Wrap(spacing: 6, children: [
            for (final d in const [3, 5, 7, 10, 14, 21]) ChoiceChip(label: Text('$d DAYS'), selected: days == d, onSelected: (_) => setState(() => days = d)),
          ]),
          for (final (i, day) in plan.indexed) Text('${dayLabel(v.today + i)}: ${day.isEmpty ? 'buffer' : day.join(', ')}'),
        ]);
      case 414:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final s in v.of('att'))
            Builder(builder: (_) {
              final (pct, room) = attendance(s.integer('present'), s.integer('total'));
              return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${s.str('name')} · $pct%'),
                  subtitle: Text(room >= 0 ? 'Can miss $room more and stay at 75%.' : 'Attend the next ${-room} to get back to 75%.', style: const TextStyle(color: dim)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check, color: cyan), onPressed: () => app.putRec(s.copy({'present': s.integer('present') + 1, 'total': s.integer('total') + 1}))),
                    IconButton(icon: const Icon(Icons.close, color: dim), onPressed: () => app.putRec(s.copy({'total': s.integer('total') + 1}))),
                  ]));
            }),
          TextField(key: const Key('attName'), controller: a, decoration: const InputDecoration(hintText: 'Subject')),
          FilledButton(
              onPressed: () async {
                if (a.text.trim().isEmpty) return;
                await app.addRec('att', {'name': a.text.trim(), 'present': 0, 'total': 0});
                a.clear();
              },
              child: const Text('ADD SUBJECT')),
        ]);
      case 450:
        return FilledButton(
            key: const Key('csv'),
            onPressed: () async {
              final file = File(p.join((await getTemporaryDirectory()).path, 'challenger-timer-events.csv'));
              await file.writeAsString(eventsCsv(v));
              await ref.read(shareProvider)(filePath: file.path);
              await app.markExported();
            },
            child: const Text('EXPORT EVERYTHING AS CSV'));
    }
    return const SizedBox();
  }
}
