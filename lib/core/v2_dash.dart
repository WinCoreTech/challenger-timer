/// Dashboard helpers (reference spec 5.1, 5.7). Pure Dart.
library;

import 'engine.dart';
import 'extras.dart';
import 'rules.dart';

/// The one-line slogan on the WORK tile, by state. Our own words.
String workSlogan(DayView v) {
  final need = v.ladder.minutesToAdvance;
  if (v.active != null) return 'The clock is running. Go back to it.';
  if (!v.workedToday && daysAway(v) >= 3) return 'Been a while. Nobody is keeping score of that. One session.';
  if (need != null && need > 0 && need <= 25) return '$need minutes from the next rank. That is one session.';
  if (v.workedToday) return 'Today is on the board. More is optional.';
  return 'Nothing started yet. That is fixable in one press.';
}

/// First logical day on which [a] was earned, found by replaying the log
/// day by day. Null if it is not earned.
int? earnedDay(DayView v, Achievement a) {
  if (!a.earned(v.metrics)) return null;
  final days = {for (final e in v.events) e.day}.toList()..sort();
  var lo = 0, hi = days.length - 1;
  // Metrics used by achievements only grow or are checked as "ever reached",
  // so the first day is found by bisection.
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (a.earned(_upTo(v, days[mid]).metrics)) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return days.isEmpty ? v.today : days[lo];
}

DayView _upTo(DayView v, int day) => DayView(
    events: v.events.where((e) => e.day <= day).toList(), recs: v.recs, kv: v.kv, now: v.now, ranks: v.ranks, catalog: v.catalog, streakMin: v.streakMin);
