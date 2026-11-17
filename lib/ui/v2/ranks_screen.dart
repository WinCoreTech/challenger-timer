import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../theme.dart';

const ranksHelpText = 'Your rank follows recent work, not lifetime totals.\n\n'
    'Score: each day\'s worked minutes, counting half as much every 5 days.\n\n'
    'Promotion: the moment your score reaches the next line.\n\n'
    'Demotion: one step, after 3 counted days in a row under your own rank\'s line.\n\n'
    'Never counted: rest days, sick or travel days, exam days and days a freeze covered.\n\n'
    'XP is separate. XP never drops and is what unlocks tools.';

/// Reference 5.9: the ladder. Far ranks are unknown, lower ones dimmed.
class RanksScreen extends ConsumerWidget {
  const RanksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final l = v.ladder;
    final need = l.minutesToAdvance;
    return Scaffold(
        appBar: AppBar(title: const Text('RANKS'), actions: [
          IconButton(
              key: const Key('ranksHelp'),
              tooltip: 'How ranks work',
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                      backgroundColor: panel,
                      title: const H('How ranks work', color: Colors.white, size: 16),
                      content: const SingleChildScrollView(child: Text(ranksHelpText)),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('GOT IT'))])),
              icon: const Icon(Icons.help_outline)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (var i = v.ranks.length - 1; i >= 0; i--)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                    key: Key('rank-$i'),
                    border: i == l.index ? accent : null,
                    child: i > l.index + 1
                        ? const Row(children: [Icon(Icons.lock_outline, color: dim, size: 18), SizedBox(width: 8), Text('Unknown rank', style: TextStyle(color: dim))])
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (i == l.index) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.arrow_right, color: accent)),
                              Expanded(
                                  child: Text(v.ranks[i].name.toUpperCase(),
                                      style: TextStyle(
                                          fontWeight: i == l.index ? FontWeight.w900 : FontWeight.w500,
                                          color: i == l.index ? accent : i < l.index ? dim : Colors.white))),
                              Text(i == l.index ? 'YOU' : i < l.index ? 'passed' : 'next', style: const TextStyle(color: dim, fontSize: 12)),
                            ]),
                            if (i == l.index) ...[
                              const SizedBox(height: 6),
                              Text(v.ranks[i].blurb, style: const TextStyle(color: dim)),
                              const SizedBox(height: 6),
                              Text('Score ${l.score.round()}. ${need == null ? 'Top of the ladder. Keep it by showing up.' : '$need more minutes today to advance.'}',
                                  key: const Key('rankScore')),
                              if (l.belowDays > 0)
                                Text('${l.belowDays} of 3 days under this rank\'s line. One solid session lifts it back.', style: const TextStyle(color: gold)),
                            ],
                            if (i == l.index + 1) Text('Line at ${v.ranks[i].score}.', style: const TextStyle(color: dim, fontSize: 12)),
                          ]))),
        ]));
  }
}
