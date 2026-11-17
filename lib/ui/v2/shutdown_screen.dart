import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/day.dart';
import '../../core/v2_day.dart';
import '../theme.dart';

/// Plan v2 6.7: three lines, today's score, and tomorrow set by rules.
class ShutdownScreen extends ConsumerStatefulWidget {
  const ShutdownScreen({super.key});
  @override
  ConsumerState<ShutdownScreen> createState() => _ShutdownState();
}

class _ShutdownState extends ConsumerState<ShutdownScreen> {
  final c = [TextEditingController(), TextEditingController(), TextEditingController()];
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
    final app = ref.read(appProvider.notifier);
    final score = dailyScore(v, v.today);
    final next = suggestTomorrow(v);
    final ms = milestones(v);
    const prompts = ['What I got done', 'What got in the way', 'What I will do first tomorrow'];
    return Scaffold(
        appBar: AppBar(title: const Text('SHUTDOWN')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Panel(
              border: cyan,
              child: Row(children: [
                Big('$score', size: 56, color: cyan, key: const Key('dayScore')),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('today, out of 100\n${v.minutesToday} of ${dailyTargetMinutes(v)} target minutes (50), streak day (20), plan kept (15), focus (15)',
                        style: const TextStyle(color: dim))),
              ])),
          const SizedBox(height: 16),
          if (shutdownDone(v))
            const Text('Shutdown complete for today. The desk is closed.', key: Key('shutdownDone'), style: TextStyle(color: cyan, fontWeight: FontWeight.w700))
          else ...[
            for (var i = 0; i < 3; i++) ...[
              H(prompts[i]),
              const SizedBox(height: 4),
              TextField(key: Key('shut-$i'), controller: c[i], maxLength: 140, decoration: const InputDecoration(counterText: '')),
              const SizedBox(height: 10),
            ],
            FilledButton(
                key: const Key('shutSave'),
                onPressed: () async {
                  await app.addRec('shutdown', {'day': v.today, 'a': [for (final x in c) x.text.trim()], 'score': score});
                  if (c[2].text.trim().isNotEmpty && !v.planLocked) await app.setPlan(c[2].text, next.minute);
                },
                child: const Text('SHUTDOWN COMPLETE')),
          ],
          const SizedBox(height: 20),
          const H('Tomorrow, by the rules'),
          const SizedBox(height: 6),
          Text('First task: ${v.tomorrowPlan?.task ?? next.task}', key: const Key('tomorrowTask'), style: const TextStyle(fontSize: 16)),
          Text('Start at ${hhmm(v.tomorrowPlan?.cueMinute ?? next.minute)}', style: const TextStyle(color: dim)),
          if (v.tomorrowPlan == null)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(key: const Key('shutUsePlan'), onPressed: () => app.setPlan(next.task, next.minute), child: const Text('USE THIS PLAN'))),
          const SizedBox(height: 20),
          H('Streak titles · next at ${ms.next ?? '-'} days'),
          for (final t in ms.unlocked) Text('★ $t'),
          if (ms.unlocked.isEmpty) const Text('The first title arrives at a 7-day streak.', style: TextStyle(color: dim)),
        ]));
  }
}
