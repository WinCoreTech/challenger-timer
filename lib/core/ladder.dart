/// Rank ladder with promotion and demotion (reference spec 5.9). Pure Dart.
///
/// This is separate from XP. XP only ever goes up and unlocks Toolbox items.
/// The ladder follows recent daily work:
///  * score = sum of each day's worked minutes x 0.5^(age in days / 5)
///  * promoted as soon as the score reaches the next rank's threshold
///  * demoted one step after 3 counted days in a row below the current
///    rank's own threshold
///  * rest weekdays, sick or travel days, exam days and freeze days are never
///    counted toward demotion.
library;

import 'dart:math';

import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'focus.dart';

const double halfLifeDays = 5;
const int demoteAfterDays = 3;

class RankChange {
  const RankChange(this.day, this.from, this.to);
  final int day, from, to;
  bool get promotion => to > from;
}

class Ladder {
  const Ladder(this.index, this.score, this.belowDays, this.changes, this.peak, this.nextScore);
  final int index;

  /// Today's live score.
  final double score;

  /// Counted days in a row spent under the current rank's threshold.
  final int belowDays;
  final List<RankChange> changes;

  /// Highest rank ever held.
  final int peak;

  /// Threshold of the next rank, or null at the top.
  final int? nextScore;

  /// Minutes of work needed today to be promoted, or null at the top.
  int? get minutesToAdvance => nextScore == null ? null : max(0, (nextScore! - score).ceil());

  int? get lastDemotionDay => changes.where((c) => !c.promotion).lastOrNull?.day;

  /// A rank lost earlier was reached again.
  bool get regained {
    var lost = <int>{};
    for (final c in changes) {
      if (!c.promotion) lost.add(c.from);
      if (c.promotion && lost.contains(c.to)) return true;
    }
    return false;
  }
}

/// Decayed score at the end of [day] from minutes per day.
double scoreAt(Map<int, int> minutesByDay, int day) {
  var s = 0.0;
  for (final e in minutesByDay.entries) {
    if (e.key <= day) s += e.value * pow(0.5, (day - e.key) / halfLifeDays);
  }
  return s;
}

Ladder computeLadder(Map<int, int> minutesByDay, List<int> thresholds, int today, {Set<int> exempt = const {}, bool Function(int day)? exemptDay}) {
  if (minutesByDay.isEmpty) return Ladder(0, 0, 0, const [], 0, thresholds.length > 1 ? thresholds[1] : null);
  final first = minutesByDay.keys.reduce(min);
  var idx = 0, below = 0, peak = 0;
  final changes = <RankChange>[];
  // Running score: decay one day, then add that day's minutes.
  final k = pow(0.5, 1 / halfLifeDays).toDouble();
  var score = 0.0;
  for (var d = first; d <= today; d++) {
    score = score * k + (minutesByDay[d] ?? 0);
    while (idx + 1 < thresholds.length && score >= thresholds[idx + 1]) {
      changes.add(RankChange(d, idx, idx + 1));
      idx++;
      below = 0;
    }
    if (idx > peak) peak = idx;
    if (d == today) break; // today is not over: no demotion counting yet
    final skip = exempt.contains(d) || (exemptDay?.call(d) ?? false);
    if (score >= thresholds[idx]) {
      below = 0;
    } else if (!skip) {
      below++;
      if (below >= demoteAfterDays && idx > 0) {
        changes.add(RankChange(d, idx, idx - 1));
        idx--;
        below = 0;
      }
    }
  }
  return Ladder(idx, score, below, changes, peak, idx + 1 < thresholds.length ? thresholds[idx + 1] : null);
}

Map<int, int> minutesByDay(DayView v) {
  final m = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    m[e.day] = (m[e.day] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
  }
  // A failed Beast session costs a fixed 10 minutes of that day's score, never below zero.
  for (final f in beastFails(v).entries) {
    final left = (m[f.key] ?? 0) - f.value * beastPenaltyMinutes;
    m[f.key] = left < 0 ? 0 : left;
  }
  return m;
}

/// The ladder for a view: rest, sick, exam and freeze days are exempt.
Ladder ladderOf(DayView v) => computeLadder(
      minutesByDay(v),
      [for (final r in v.ranks) r.score],
      v.today,
      exempt: {...v.master.frozenDays, ...pausedDays(v), ...examDays(v)},
      exemptDay: (d) => v.restWeekdays.contains(DateTime.utc(1970, 1, 1 + d).weekday),
    );

/// Longest run of days since the first session with no demotion, up to today.
int daysWithoutDemotion(DayView v, Ladder l) {
  if (v.sessionDays.isEmpty) return 0;
  final from = l.lastDemotionDay ?? v.sessionDays.reduce(min);
  return v.today - from;
}
