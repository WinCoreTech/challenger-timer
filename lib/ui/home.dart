import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/extras.dart';
import '../core/game.dart';
import '../core/rules.dart';
import '../core/streak_engine.dart';
import '../core/tools.dart';
import 'theme.dart';

String streakLine(StreakResult s) => switch (s.state) {
      StreakState.active => 'Done for today. Streak safe.',
      StreakState.pending => 'One start today keeps it going.',
      StreakState.paused => 'Paused, not broken. Two minutes today brings it back.',
      StreakState.none => s.longest > 0 ? 'Fresh page. Day one starts with two minutes.' : 'Day one starts with two minutes.',
    };

/// The one line under the streak. Kind by rule: no blame, ever.
String homeLine(DayView v) {
  final slipped = v.master.state == StreakState.paused || v.master.frozenDays.contains(v.today - 1);
  if (slipped && !v.workedToday) {
    final plan = (v.kv['t.72'] ?? '').length > 4 ? v.single(const ToolDef(n: 72, kind: 'single', title: '', prompts: [''])).first : '';
    if (v.on(72) && plan.isNotEmpty) return 'Your own plan for this moment: "$plan"';
    if (v.on(66)) return 'The day is not lost. Two minutes saves it.';
  }
  if (v.on(65) && !v.workedToday && v.master.state != StreakState.pending) {
    final f = freshStart(v.today, birthday: v.kv['t.65'] == null ? '' : v.single(const ToolDef(n: 65, kind: 'single', title: '', prompts: [''])).first);
    if (f != null) return 'It is $f. A clean page, if you want one.';
  }
  if (v.on(266) && v.name.isNotEmpty && !v.workedToday) return '${v.name}, start the timer. Two minutes.';
  if (v.on(462) && !v.workedToday && toneLines.containsKey(toneOf(v))) return toneLines[toneOf(v)]!;
  return streakLine(v.master);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final active = v.active;
    // Feature 71: after three or more days away, one button and no stats.
    final overwhelm = v.on(288) && v.kv['overwhelm'] == '1';
    if ((v.on(71) && daysAway(v) >= 3 && !v.workedToday && active == null) || (overwhelm && active == null && v.pendingProof == null)) {
      return SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: Poster(PosterArt.door, size: 120)),
                const SizedBox(height: 24),
                Text(overwhelm ? 'ONE THING.' : 'WELCOME BACK.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(overwhelm ? v.nextStep : 'Nothing to catch up on. No numbers today. Just this.', textAlign: TextAlign.center, style: const TextStyle(color: dim, fontSize: 16)),
                const SizedBox(height: 32),
                SizedBox(
                    height: 96,
                    child: FilledButton(
                        key: const Key('start'),
                        onPressed: () async {
                          await app.startSession();
                          if (context.mounted) context.go('/timer');
                        },
                        child: Text(overwhelm ? 'START 2 MIN' : 'START AGAIN', style: const TextStyle(fontSize: 30)))),
              ])));
    }
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: () => context.go('/me'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const H('Rank'),
                    const SizedBox(height: 4),
                    Text('${'★' * prestige(v)}${shownRank(v).rank.name.toUpperCase()}',
                        key: const Key('rankTitle'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cyan, letterSpacing: 1)),
                  ]))),
          InkWell(
              onTap: () => context.go('/streaks'),
              child: Row(children: [
                Poster(PosterArt.flame,
                    size: 44,
                    level: v.on(33) ? flameLevel(v.master.current) : (v.master.current / 30).clamp(0.0, 1.0),
                    color: v.master.state == StreakState.paused ? dim : cyan),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Big('${v.master.current}', size: 40, key: const Key('masterStreak')),
                  H(tr(v, 'DAY STREAK'), size: 10),
                ]),
              ])),
        ]),
        const SizedBox(height: 6),
        Text(homeLine(v), key: const Key('homeLine'), style: const TextStyle(color: dim)),
        const SizedBox(height: 20),
        Panel(
            border: cyan,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              H(tr(v, 'NEXT TINY STEP'), color: cyan),
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
                      Text(active == null ? tr(v, 'START') : 'RUNNING',
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
