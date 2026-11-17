import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/day.dart';
import '../../core/ranges.dart';
import '../../core/tree.dart';
import '../theme.dart';

/// Reference 5.8.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _StatsState();
}

class _StatsState extends ConsumerState<StatsScreen> {
  RangeKind kind = RangeKind.last7;
  int step = 0;
  int? from, to;

  Future<void> _pickDate(bool isFrom, int today) async {
    final base = dateOfDay((isFrom ? from : to) ?? today);
    final d = await showDatePicker(context: context, initialDate: DateTime(base.year, base.month, base.day), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => isFrom ? from = dayOfDate(d.year, d.month, d.day) : to = dayOfDate(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final (a, b) = rangeDays(v, kind, step: step, customFrom: from, customTo: to);
    final s = rangeStats(v, a, b);
    final maxWd = s.byWeekday.reduce((x, y) => x > y ? x : y);
    final maxHr = s.byHour.reduce((x, y) => x > y ? x : y);
    Widget fact(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(k, style: const TextStyle(color: dim))), Text(val, style: const TextStyle(fontWeight: FontWeight.w700))]));
    return Scaffold(
        appBar: AppBar(title: const Text('STATS')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<RangeKind>(
              key: const Key('statsRange'),
              initialValue: kind,
              isExpanded: true,
            dropdownColor: panel,
              items: [for (final k in RangeKind.values) DropdownMenuItem(value: k, child: Text(rangeNames[k]!))],
              onChanged: (k) => setState(() {
                    kind = k ?? kind;
                    step = 0;
                  })),
          const SizedBox(height: 8),
          Row(children: [
            if (steppable(kind)) IconButton(key: const Key('statsBack'), tooltip: 'Previous period', onPressed: () => setState(() => step--), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(rangeLabel(kind, a, b), key: const Key('statsLabel'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (steppable(kind))
              IconButton(key: const Key('statsFwd'), tooltip: 'Next period', onPressed: step >= 0 ? null : () => setState(() => step++), icon: const Icon(Icons.chevron_right)),
          ]),
          if (kind == RangeKind.custom)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(key: const Key('statsFrom'), onPressed: () => _pickDate(true, v.today), child: Text('FROM ${dayLabel(a)}')),
              TextButton(key: const Key('statsTo'), onPressed: () => _pickDate(false, v.today), child: Text('TO ${dayLabel(b)}')),
            ]),
          const SizedBox(height: 12),
          if (s.empty)
            const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('No work logged in this period.', key: Key('statsEmpty'), textAlign: TextAlign.center, style: TextStyle(color: dim, fontSize: 16)))
          else ...[
            Panel(
                border: cyan,
                child: Row(children: [
                  Big('${s.consistency}%', size: 52, color: cyan, key: const Key('statsConsistency')),
                  const SizedBox(width: 12),
                  Expanded(child: Text('consistency\n${s.activeDays} of ${s.countedDays} days had a session', style: const TextStyle(color: dim))),
                ])),
            const SizedBox(height: 12),
            fact('Time worked', hm(s.minutes)),
            fact('Sessions', '${s.sessions}'),
            fact('Sessions per day', s.sessionsPerDay.toStringAsFixed(1)),
            fact('Average session', '${s.averageSession} min'),
            if (s.longestDay != null) fact('Longest day', '${dayLabel(s.longestDay!)} · ${hm(s.longestDayMinutes)}'),
            fact('Drifts noticed', '${s.drifts}'),
            const SizedBox(height: 12),
            const H('Time per project'),
            for (final (n, m) in s.byProject)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(n)), Text(hm(m), style: const TextStyle(color: dim))]),
                    const SizedBox(height: 4),
                    Bar(m / s.minutes, height: 6),
                  ])),
            const SizedBox(height: 16),
            const H('By weekday'),
            const SizedBox(height: 6),
            for (var d = 1; d <= 7; d++)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    SizedBox(width: 44, child: Text(const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d], style: const TextStyle(color: dim))),
                    Expanded(child: Bar(maxWd == 0 ? 0 : s.byWeekday[d] / maxWd, height: 8)),
                    SizedBox(width: 64, child: Text(hm(s.byWeekday[d]), textAlign: TextAlign.right, style: const TextStyle(color: dim, fontSize: 12))),
                  ])),
            const SizedBox(height: 16),
            const H('By hour of day'),
            const SizedBox(height: 6),
            Semantics(
                label: 'Most work happens around ${two(s.byHour.indexOf(maxHr))}:00',
                child: SizedBox(
                    height: 70,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (var h = 0; h < 24; h++)
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: FractionallySizedBox(heightFactor: maxHr == 0 ? 0.02 : (s.byHour[h] / maxHr).clamp(0.02, 1.0), child: Container(color: s.byHour[h] > 0 ? cyan : line)))),
                    ]))),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('00', style: TextStyle(color: dim, fontSize: 11)), Text('06', style: TextStyle(color: dim, fontSize: 11)),
              Text('12', style: TextStyle(color: dim, fontSize: 11)), Text('18', style: TextStyle(color: dim, fontSize: 11)), Text('24', style: TextStyle(color: dim, fontSize: 11)),
            ]),
            Text('Most work happens around ${two(s.byHour.indexOf(maxHr))}:00.', style: const TextStyle(color: dim)),
          ],
        ]));
  }
}
