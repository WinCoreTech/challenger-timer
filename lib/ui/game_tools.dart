import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/state.dart';
import '../core/events.dart';
import '../core/extras.dart';
import '../core/game.dart';
import 'theme.dart';

/// Features 239, 240, 242, 243: coins shop, savings jar, avatar, workshop.
class GameTool extends ConsumerWidget {
  const GameTool(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    switch (n) {
      case 239:
        final rewards = v.of('reward');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Big('${coins(v)}', size: 48, color: gold, key: const Key('coins')), const SizedBox(width: 8), const H('Coins')]),
          const Text('One coin per finished session, five more for a day with all three quests. Coins buy only rewards you set yourself. Nothing can be bought to skip work.',
              style: TextStyle(color: dim)),
          const SizedBox(height: 12),
          for (final r in rewards)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.str('name')),
                subtitle: Text('${r.integer('price')} coins'),
                trailing: FilledButton(
                    key: Key('redeem-${r.id}'),
                    onPressed: coins(v) < r.integer('price') ? null : () => app.log(Ev.tool, {'n': 239, 'coins': r.integer('price'), 'reward': r.str('name')}),
                    child: const Text('REDEEM'))),
          OutlinedButton(
              key: const Key('addReward'),
              onPressed: () async {
                final name = await askText(context, 'Reward', hint: 'Cutting chai, one movie');
                if (name == null || name.trim().isEmpty || !context.mounted) return;
                final price = await askText(context, 'Price in coins', hint: '10', keyboard: TextInputType.number);
                final p = int.tryParse(price ?? '');
                if (p != null && p > 0) await app.addRec('reward', {'name': name.trim(), 'price': p});
              },
              child: const Text('ADD A REWARD')),
        ]);
      case 240:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Big('₹${savingsJar(v)}', size: 56, color: gold, key: const Key('jar')),
          const Text('Set an amount per finished session. The app only counts. Moving real money into a real jar is your part.', style: TextStyle(color: dim)),
        ]);
      case 242:
        final stage = (levelFor(v.xpTotal) - 1).clamp(0, 9);
        return Column(children: [
          SizedBox(height: 220, child: Center(child: Poster(PosterArt.flame, size: 60.0 + stage * 16, level: stage / 9))),
          Text('Stage ${stage + 1} of 10. It grows one stage per level.', style: const TextStyle(color: dim)),
        ]);
      case 243:
        final bricks = v.type(Ev.sessionDone).length;
        final cracked = v.on(609) ? (daysAway(v) - 1).clamp(0, bricks) : 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$bricks bricks. One per finished session.', key: const Key('bricks'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (cracked > 0) Text('$cracked show cracks after idle days. One session repairs them.', style: const TextStyle(color: gold)),
          const SizedBox(height: 12),
          Wrap(spacing: 3, runSpacing: 3, verticalDirection: VerticalDirection.up, children: [
            for (var i = 0; i < bricks.clamp(0, 400); i++)
              Container(width: 26, height: 12, color: i >= bricks - cracked ? gold.withValues(alpha: 0.5) : cyan),
          ]),
        ]);
    }
    return const SizedBox();
  }
}
