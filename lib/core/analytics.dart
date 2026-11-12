/// Reflection and analytics (features 426 to 450). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'stats.dart';
import 'study.dart';
import 'tools.dart';

int _min(Iterable<Event> e) => e.fold(0, (a, x) => a + (x.get<num>('minutes') ?? 0).toInt());

/// 427: 0 to 100. Starting is worth 40, minutes up to 40, proof 20.
int dayScore(DayView v, int day) {
  final started = v.type(Ev.sessionStart).any((e) => e.day == day) ? 40 : 0;
  final minutes = _min(v.type(Ev.sessionDone).where((e) => e.day == day)).clamp(0, 40);
  final proof = v.type(Ev.proof).any((e) => e.day == day) ? 20 : 0;
  return started + minutes + proof;
}

/// 430: minutes per week for the last [weeks] weeks, oldest first.
List<int> weeklyMinutes(DayView v, {int weeks = 4}) {
  final w = weekOf(v.today);
  return [for (var k = w - weeks + 1; k <= w; k++) _min(v.type(Ev.sessionDone).where((e) => weekOf(e.day) == k))];
}

/// 431: average first-start minute per week, oldest first (null = no starts).
List<int?> startTimeTrend(DayView v, {int weeks = 4}) {
  final first = firstStartMinute(v);
  final w = weekOf(v.today);
  return [
    for (var k = w - weeks + 1; k <= w; k++)
      () {
        final xs = [for (final e in first.entries) if (weekOf(e.key) == k) e.value];
        return xs.isEmpty ? null : ((xs.reduce((a, b) => a + b) / xs.length).round() + v.dayEndHour * 60) % 1440;
      }()
  ];
}

/// 432: best weekday by minutes (1 = Monday), or null.
int? bestWeekday(DayView v) {
  final d = List.filled(8, 0);
  for (final e in v.type(Ev.sessionDone)) {
    d[weekdayOf(e.day)] += (e.get<num>('minutes') ?? 0).toInt();
  }
  final best = d.reduce((a, b) => a > b ? a : b);
  return best == 0 ? null : d.indexOf(best);
}

/// 434: share of planned days on which a session followed.
(int kept, int planned) plannedVsDone(DayView v) {
  final planned = {for (final e in v.type(Ev.planSet)) if ((e.get<int>('forDay') ?? v.today + 1) <= v.today) e.get<int>('forDay')!};
  return (planned.where(v.sessionDays.contains).length, planned.length);
}

/// 440, 441, 442: average minutes per day grouped by a label on that day.
Map<String, double> outputBy(DayView v, Map<int, String> labelOfDay) {
  final per = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    per[e.day] = (per[e.day] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
  }
  final sums = <String, List<int>>{};
  for (final e in labelOfDay.entries) {
    (sums[e.value] ??= []).add(per[e.key] ?? 0);
  }
  return {for (final e in sums.entries) e.key: e.value.reduce((a, b) => a + b) / e.value.length};
}

Map<String, double> placeFocus(DayView v) {
  final m = <String, List<int>>{};
  for (final e in v.type(Ev.sessionDone)) {
    final p = e.get<String>('place');
    if (p != null) (m[p] ??= []).add((e.get<num>('minutes') ?? 0).toInt());
  }
  return {for (final e in m.entries) e.key: e.value.reduce((a, b) => a + b) / e.value.length};
}

/// 445: dated milestones reached so far.
List<(int day, String what)> milestoneTimeline(DayView v) {
  final out = <(int, String)>[];
  final done = v.type(Ev.sessionDone).toList();
  if (done.isNotEmpty) out.add((done.first.day, 'First session finished'));
  final proofs = v.type(Ev.proof).toList();
  if (proofs.isNotEmpty) out.add((proofs.first.day, 'First proof saved'));
  for (final n in [10, 50, 100, 500]) {
    if (done.length >= n) out.add((done[n - 1].day, '${n}th session'));
  }
  var mins = 0;
  final marks = [60, 600, 6000];
  for (final e in done) {
    final before = mins;
    mins += (e.get<num>('minutes') ?? 0).toInt();
    for (final m in marks) {
      if (before < m && mins >= m) out.add((e.day, '${m ~/ 60} hours of work'));
    }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// 446: plain sentences, each backed by a real comparison in the log. A
/// sentence appears only when there is enough data to support it.
List<String> insights(DayView v) {
  final out = <String>[];
  final done = v.type(Ev.sessionDone).toList();
  if (done.length < 5) return ['Not enough sessions yet for honest insights. They start after five.'];
  final early = done.where((e) => e.moment.hour < 11 && e.moment.hour >= v.dayEndHour).toList();
  final late = done.where((e) => !(e.moment.hour < 11 && e.moment.hour >= v.dayEndHour)).toList();
  if (early.length >= 3 && late.length >= 3) {
    final a = _min(early) / early.length, b = _min(late) / late.length;
    final pct = ((a - b).abs() / (a < b ? a : b) * 100).round();
    if (pct >= 10) out.add('Your sessions run $pct% longer ${a > b ? 'before' : 'after'} 11 am.');
  }
  final wd = bestWeekday(v);
  if (wd != null) out.add('${const ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][wd]} is your strongest day.');
  final (kept, planned) = plannedVsDone(v);
  if (planned >= 3) out.add('On days with a locked first task you worked $kept times out of $planned.');
  final pf = placeFocus(v);
  if (pf.length >= 2) {
    final best = pf.entries.reduce((a, b) => a.value >= b.value ? a : b);
    out.add('Your longest sessions happen in the ${best.key} (${best.value.round()} min on average).');
  }
  final delay = startDelay(v);
  if (delay != null) out.add('You start ${delay.round()} minutes after your cue time on average.');
  if (out.isEmpty) out.add('Nothing stands out yet. More days will show a pattern.');
  return out;
}

/// 450: the whole event log as CSV.
String eventsCsv(DayView v) {
  String q(Object? x) => '"${'$x'.replaceAll('"', '""')}"';
  final b = StringBuffer('id,type,utc_ms,offset_min,day,date,payload\n');
  for (final e in v.events) {
    b.writeln([e.id, e.type, e.ts, e.offsetMin, e.day, dayLabel(e.day), q(e.payloadJson)].join(','));
  }
  return b.toString();
}

/// 433: habits ordered with those at risk today first.
List<(Rec habit, String state)> streakHealth(DayView v) {
  final rows = [
    for (final h in v.habits)
      (h, v.tickedToday(h.id) ? 'safe' : v.habitStreak(h.id).current > 0 ? 'at risk' : 'not started')
  ];
  const order = {'at risk': 0, 'not started': 1, 'safe': 2};
  rows.sort((a, b) => order[a.$2]!.compareTo(order[b.$2]!));
  return rows;
}

/// 437: deep minutes against all other minutes.
(int deep, int shallow) deepShallow(DayView v) {
  final d = deepMinutes(v);
  return (d, _min(v.type(Ev.sessionDone)) - d);
}

final Map<String, Stat> analyticsStats = {
  'exam': (v) {
    final units = v.of('t402').where((r) => !r.flag('done')).length;
    return ['$units units left', 'open units in your syllabus tracker', 'Counted in units, not days, because units are what you can act on.'];
  },
  'dayScore': (v) => ['${dayScore(v, v.today)}', 'today out of 100', 'Starting is 40, minutes up to 40, proof 20. Yesterday: ${dayScore(v, v.today - 1)}.'],
  'trend': (v) => ['${weeklyMinutes(v).last} min', 'this week', 'Last four weeks, oldest first: ${weeklyMinutes(v).join(', ')} minutes.'],
  'startTrend': (v) {
    final t = startTimeTrend(v);
    return [t.last == null ? '-' : hhmm(t.last!), 'average first start this week', 'Last four weeks: ${t.map((x) => x == null ? '-' : hhmm(x)).join(', ')}.'];
  },
  'bestDay': (v) {
    final wd = bestWeekday(v);
    return wd == null ? ['No data yet', ''] : [const ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][wd], 'is your best day by minutes', ...stats['peak']!(v).take(2)];
  },
  'health': (v) {
    final h = streakHealth(v);
    return ['${h.where((x) => x.$2 == 'at risk').length} at risk', 'Master streak: ${v.master.current} (${v.workedToday ? 'safe' : 'open today'})', for (final (hab, st) in h) '${hab.str('name')}: $st'];
  },
  'planRatio': (v) {
    final (k, p) = plannedVsDone(v);
    return ['$k of $p', 'planned days were followed by a session'];
  },
  'byProject': (v) {
    final t = timeByProject(v);
    return t.isEmpty ? ['No sessions yet', ''] : [t.first.$1, 'has had the most time', for (final (n, m) in t) '$n: ${(m / 60).toStringAsFixed(1)} h'];
  },
  'deepRatio': (v) {
    final (d, s) = deepShallow(v);
    return ['$d : $s min', 'deep work against everything else'];
  },
  'moodOutput': (v) {
    final m = outputBy(v, {for (final (d, x) in v.toolRatings(276)) d: x <= 2 ? 'low mood' : x >= 4 ? 'good mood' : 'middling'});
    return m.isEmpty ? ['No mood logs yet', 'Log "Mood check" on a few days.'] : ['Mood and output', for (final e in m.entries) '${e.key}: ${e.value.round()} min a day'];
  },
  'placeFocus': (v) {
    final m = placeFocus(v);
    return m.isEmpty ? ['No places yet', 'Pick library, room or lab on the Timer tab.'] : ['By place', for (final e in m.entries) '${e.key}: ${e.value.round()} min per session'];
  },
  'timeline': (v) {
    final t = milestoneTimeline(v);
    return t.isEmpty ? ['Nothing yet', 'Your first finished session starts the timeline.'] : ['${t.length} milestones', for (final (d, w) in t) '${dayLabel(d)}: $w'];
  },
  'insights': (v) => ['Insights', ...insights(v)],
  'month': (v) {
    final m = monthKey(v.today);
    final done = v.type(Ev.sessionDone).where((e) => monthKey(e.day) == m);
    return ['${_min(done)} min', 'this month', '${done.length} sessions on ${v.showedUpDays.where((d) => monthKey(d) == m).length} days', '${v.type(Ev.proof).where((e) => monthKey(e.day) == m).length} proofs'];
  },
};
