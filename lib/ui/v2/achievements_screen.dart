import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/day.dart';
import '../../core/v2_dash.dart';
import '../theme.dart';

String _ymd(int day) {
  final d = dateOfDay(day);
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}

/// Reference 5.7: unknown until earned; earned rows expand to a date.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final all = ref.watch(achievementsProvider);
    final earned = all.where((a) => a.earned(v.metrics)).length;
    return Scaffold(
        appBar: AppBar(title: Text('ACHIEVEMENTS · $earned/${all.length}')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in all)
            if (!a.earned(v.metrics))
              ListTile(
                  key: Key('ach-${a.id}'),
                  leading: const Icon(Icons.lock_outline, color: dim),
                  title: const Text('Unknown achievement', style: TextStyle(color: dim)))
            else
              ExpansionTile(
                  key: Key('ach-${a.id}'),
                  shape: const Border(),
                  leading: const Icon(Icons.military_tech, color: gold),
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.desc),
                    Text('Achieved on ${_ymd(earnedDay(v, a) ?? v.today)}', style: const TextStyle(color: dim)),
                  ]),
        ]));
  }
}
