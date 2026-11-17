import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/state.dart';
import '../core/events.dart';
import '../core/wellbeing.dart';
import 'theme.dart';

/// Features 277, 278, 281: name the feeling, get the matching fix, start.
class FeelingTool extends ConsumerStatefulWidget {
  const FeelingTool(this.n, this.options, {super.key});
  final int n;
  final List<String> options;
  @override
  ConsumerState<FeelingTool> createState() => _FeelingState();
}

class _FeelingState extends ConsumerState<FeelingTool> {
  String? pick;
  @override
  Widget build(BuildContext context) {
    final app = ref.read(appProvider.notifier);
    final fix = pick == null ? null : fixes[pick];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in widget.options)
          ChoiceChip(
              key: Key('feel-$o'),
              label: Text(o.toUpperCase()),
              selected: pick == o,
              onSelected: (_) {
                setState(() => pick = o);
                app.log(Ev.tool, {'n': widget.n, 'choice': o});
              }),
      ]),
      if (fix != null) ...[
        const SizedBox(height: 16),
        Panel(border: cyan, child: Text(fix.$1, key: const Key('fix'), style: const TextStyle(fontSize: 18))),
        const SizedBox(height: 12),
        FilledButton(
            key: const Key('fixStart'),
            onPressed: () async {
              await app.startSession(minutes: fix.$2, title: fix.$1, source: 'fix');
              if (context.mounted) context.go('/timer');
            },
            child: Text('START ${fix.$2} MIN THIS WAY')),
      ],
    ]);
  }
}

/// Feature 315: a 20-minute nap as a rest timer.
class NapTool extends ConsumerWidget {
  const NapTool({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
      key: const Key('nap'),
      onPressed: () async {
        await ref.read(appProvider.notifier).startBreak(20);
        if (context.mounted) context.go('/timer');
      },
      child: const Text('START A 20-MINUTE NAP'));
}
