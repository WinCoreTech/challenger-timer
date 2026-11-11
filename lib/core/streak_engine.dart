/// Streak engine. Pure Dart, no Flutter imports. See test/streak_engine_test.dart.
///
/// Rules:
///  * A streak is fed by "active" logical days (see day.dart for day boundaries).
///  * A missed day is covered automatically by a freeze if one is left.
///    [StreakRules.freezesPerMonth] freezes per calendar month, no rollover.
///  * With no freeze, one missed day pauses the streak (the count is kept) and
///    two uncovered misses in a row break it.
///  * Today is never a miss until it is over.
library;

import 'day.dart';

class StreakRules {
  const StreakRules({
    this.freezesPerMonth = 2,
    this.earnFreezeEvery = 0,
    this.decayKeepPercent = 0,
    this.restWeekdays = const {},
    this.pausedDays = const {},
    this.freezeGainDays = const [],
  });

  final int freezesPerMonth;

  /// Feature 53: every N-day run earns one extra freeze (0 = off). Earned
  /// freezes are kept until used.
  final int earnFreezeEvery;

  /// Feature 55: on a break keep this percent of the streak (0 = full reset).
  final int decayKeepPercent;

  /// Feature 48: weekdays (1 = Mon .. 7 = Sun) that never count as a miss.
  final Set<int> restWeekdays;

  /// Feature 59: days paused for sickness or travel; never a miss.
  final Set<int> pausedDays;

  /// Feature 70: days on which one extra freeze was received. It can only
  /// cover misses after that day.
  final List<int> freezeGainDays;
}

enum StreakState {
  /// Nothing to protect yet.
  none,

  /// Today is done.
  active,

  /// Alive, today not done yet.
  pending,

  /// Yesterday was missed with no freeze left. Act today or it breaks.
  paused,
}

class StreakResult {
  const StreakResult({
    required this.current,
    required this.longest,
    required this.state,
    required this.freezesLeft,
    required this.frozenDays,
    required this.missedDays,
    required this.totalDays,
    required this.comebacks,
    required this.breaks,
    required this.earnedFreezes,
    this.comebackDays = const {},
    this.lastBreakDay,
  });
  final int current;
  final int longest;
  final StreakState state;

  /// Freezes still available today (this month's allowance plus earned ones).
  final int freezesLeft;
  final Set<int> frozenDays;
  final Set<int> missedDays;

  /// Lifetime active days. Never resets.
  final int totalDays;

  /// Times an active day followed an uncovered miss.
  final int comebacks;
  final int breaks;
  final int earnedFreezes;

  /// Active days that followed an uncovered miss (feature 57).
  final Set<int> comebackDays;

  /// The second missed day of the most recent break (feature 64).
  final int? lastBreakDay;
}

StreakResult computeStreak(Set<int> activeDays, int today,
    {StreakRules rules = const StreakRules()}) {
  final past = activeDays.where((d) => d <= today).toList()..sort();
  if (past.isEmpty) {
    return StreakResult(
        current: 0,
        longest: 0,
        state: StreakState.none,
        freezesLeft: rules.freezesPerMonth,
        frozenDays: const {},
        missedDays: const {},
        totalDays: 0,
        comebacks: 0,
        breaks: 0,
        earnedFreezes: 0);
  }
  final active = past.toSet();
  final used = <int, int>{}; // month -> monthly freezes used
  final frozen = <int>{};
  final missed = <int>{};
  var streak = 0, longest = 0, missRun = 0, comebacks = 0, breaks = 0;
  var earned = 0, run = 0;
  var hadGap = false;
  final comebackDays = <int>{};
  int? lastBreak;

  for (var d = past.first; d <= today; d++) {
    earned += rules.freezeGainDays.where((g) => g == d).length;
    if (active.contains(d)) {
      if (hadGap) {
        comebacks++;
        comebackDays.add(d);
      }
      hadGap = false;
      missRun = 0;
      streak++;
      run++;
      if (rules.earnFreezeEvery > 0 && run % rules.earnFreezeEvery == 0) earned++;
      if (streak > longest) longest = streak;
      continue;
    }
    if (d == today) break; // not over yet
    if (rules.restWeekdays.contains(weekdayOf(d)) || rules.pausedDays.contains(d)) continue;
    if (streak == 0) {
      hadGap = true;
      continue; // nothing to protect
    }
    final m = monthKey(d);
    if ((used[m] ?? 0) < rules.freezesPerMonth) {
      used[m] = (used[m] ?? 0) + 1;
      frozen.add(d);
      continue;
    }
    if (earned > 0) {
      earned--;
      frozen.add(d);
      continue;
    }
    missed.add(d);
    hadGap = true;
    missRun++;
    run = 0;
    if (missRun >= 2) {
      streak = streak * rules.decayKeepPercent ~/ 100;
      breaks++;
      lastBreak = d;
      missRun = 0;
    }
  }

  final StreakState state;
  if (active.contains(today)) {
    state = StreakState.active;
  } else if (streak == 0) {
    state = StreakState.none;
  } else if (missRun == 1) {
    state = StreakState.paused;
  } else {
    state = StreakState.pending;
  }
  final left = rules.freezesPerMonth - (used[monthKey(today)] ?? 0) + earned;
  return StreakResult(
      current: streak,
      longest: longest,
      state: state,
      freezesLeft: left,
      frozenDays: frozen,
      missedDays: missed,
      totalDays: active.length,
      comebacks: comebacks,
      breaks: breaks,
      earnedFreezes: earned,
      comebackDays: comebackDays,
      lastBreakDay: lastBreak);
}
