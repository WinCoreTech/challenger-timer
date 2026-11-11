import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/rules.dart';
import '../core/streak_engine.dart';
import 'theme.dart';

String streakLine(StreakResult s) => switch (s.state) {
      StreakState.active => 'Done for today. Streak safe.',
      StreakState.pending => 'One start today keeps it going.',
      StreakState.paused => 'Paused, not broken. Two minutes today brings it back.',
      StreakState.none => s.longest > 0 ? 'Fresh page. Day one starts with two minutes.' : 'Day one starts with two minutes.',
    };

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final active = v.active;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: () => context.go('/me'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const H('Rank'),
                    const SizedBox(height: 4),
                    Text(v.rank.rank.name.toUpperCase(),
                        key: const Key('rankTitle'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cyan, letterSpacing: 1)),
                  ]))),
          InkWell(
              onTap: () => context.go('/streaks'),
              child: Row(children: [
                Poster(PosterArt.flame,
                    size: 44,
                    level: (v.master.current / 30).clamp(0.0, 1.0),
                    color: v.master.state == StreakState.paused ? dim : cyan),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Big('${v.master.current}', size: 40, key: const Key('masterStreak')),
                  const H('Day streak', size: 10),
                ]),
              ])),
        ]),
        const SizedBox(height: 6),
        Text(streakLine(v.master), style: const TextStyle(color: dim)),
        const SizedBox(height: 20),
        Panel(
            border: cyan,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H('Next tiny step', color: cyan),
              const SizedBox(height: 8),
              Text(v.nextStep,
                  key: const Key('nextStep'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
            ])),
        const SizedBox(height: 28),
        Center(
            child: SizedBox.square(
                dimension: 220,
                child: FilledButton(
                    key: const Key('start'),
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: () async {
                      if (active == null && v.on(9) && v.kv['ritual'] == '1') return context.push<void>('/ritual');
                      if (active == null) await app.startSession();
                      if (context.mounted) context.go('/timer');
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(active == null ? 'START' : 'RUNNING',
                          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      Text(active != null ? 'TAP TO SEE THE TIMER' : v.badDay ? '1 MINUTE. ROUGH-DAY RULES.' : '2 MINUTES. THAT IS THE WHOLE JOB.',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ])))),
        if (v.on(23))
          Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(children: [
                Big('${v.starts}', size: 64, key: const Key('startCount')),
                const H('Times started', size: 10),
              ])),
        const SizedBox(height: 28),
        if (v.pendingProof != null && active == null) ...[
          Panel(
              border: gold,
              onTap: () => context.push('/proof'),
              child: const Row(children: [
                Icon(Icons.inventory_2_outlined, color: gold),
                SizedBox(width: 12),
                Expanded(child: Text('Your last session is waiting for its proof. One line is enough.')),
                Icon(Icons.chevron_right),
              ])),
          const SizedBox(height: 12),
        ],
        if (v.isOn(K.swBonus)) _Bonus(v),
      ]),
    );
  }
}

class _Bonus extends StatelessWidget {
  const _Bonus(this.v);
  final DayView v;
  @override
  Widget build(BuildContext context) {
    final risk = v.bonusAtRisk;
    final end = hhmm(v.dayEndHour * 60);
    return Panel(
        key: const Key('bonus'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: H(risk ? 'Bonus in your pocket' : 'Bonus kept', color: risk ? gold : cyan)),
            Big('+$xpDailyBonus XP', size: 20, color: risk ? gold : cyan),
          ]),
          const SizedBox(height: 10),
          Bar(risk ? v.dayLeft : 1, color: risk ? gold : cyan),
          const SizedBox(height: 8),
          Text(
              risk
                  ? 'You already have it. It leaves at $end if no session happens (${countdown(v.msToDayEnd)} left).'
                  : 'Locked in for today. Nothing can take it now.',
              style: const TextStyle(color: dim)),
        ]));
  }
}
