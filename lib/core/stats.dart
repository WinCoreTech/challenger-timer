/// Computed read-outs used by "stat" tools and the insights screens. Each
/// function returns lines of plain text: the first is the headline. Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'streak_engine.dart';

typedef Stat = List<String> Function(DayView v);

String _plural(int n, String one, [String? many]) => n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';

Iterable<Event> _done(DayView v) => v.type(Ev.sessionDone);
int _minutes(Iterable<Event> e) => e.fold(0, (a, x) => a + (x.get<num>('minutes') ?? 0).toInt());

/// First session start per day: day -> minute of day.
Map<int, int> firstStartMinute(DayView v) {
  final m = <int, int>{};
  for (final e in v.type(Ev.sessionStart)) {
    // Minutes after the day boundary, so 01:00 sorts after 23:00.
    final mins = (e.moment.minuteOfDay - v.dayEndHour * 60) % 1440;
    if (!m.containsKey(e.day) || mins < m[e.day]!) m[e.day] = mins;
  }
  return m;
}

/// Feature 3: days the app was opened before the chosen hour.
Set<int> openedEarlyDays(DayView v) {
  final by = v.settingInt('openBy', 10) * 60;
  return {
    for (final e in v.type(Ev.appOpen))
      if (e.moment.minuteOfDay < by && e.moment.minuteOfDay >= v.dayEndHour * 60) e.day
  };
}

/// Feature 24 and 438: average minutes between the cue time and the first start.
double? startDelay(DayView v, {int lastDays = 14}) {
  final first = firstStartMinute(v);
  final delays = <int>[];
  for (final e in first.entries) {
    if (e.key <= v.today - lastDays) continue;
    final cue = (rulesCue(v, e.key) - v.dayEndHour * 60) % 1440;
    delays.add(e.value > cue ? e.value - cue : 0);
  }
  if (delays.isEmpty) return null;
  return delays.reduce((a, b) => a + b) / delays.length;
}

int rulesCue(DayView v, int day) {
  for (final e in v.events.reversed) {
    if (e.type == Ev.planSet && e.get<int>('forDay') == day) return e.get<int>('cueMinute') ?? v.cueMinute;
  }
  return v.cueMinute;
}

/// Feature 25: days with any real action logged.
Set<int> nonZeroDays(DayView v) => {
      for (final e in v.events)
        if (const {Ev.sessionDone, Ev.habitTick, Ev.proof, Ev.taskDone, Ev.tool}.contains(e.type)) e.day
    };

/// Feature 69 and 443: share of the last [days] days with a finished session or tick.
int consistency(DayView v, {int days = 30}) {
  final n = [for (var d = v.today - days + 1; d <= v.today; d++) d].where(v.showedUpDays.contains).length;
  return (n * 100 / days).round();
}

final Map<String, Stat> stats = {
  'openStreak': (v) {
    final s = computeStreak(openedEarlyDays(v), v.today);
    return [
      '${s.current}',
      'days in a row opened before ${hhmm(v.settingInt('openBy', 10) * 60)}',
      'Longest: ${s.longest}. Opening the app is the smallest start there is.',
    ];
  },
  'startCount': (v) => ['${v.starts}', 'times started, ever', 'This number only goes up.'],
  'startDelay': (v) {
    final d = startDelay(v);
    if (d == null) return ['-', 'No sessions in the last 14 days yet.'];
    return [
      '${d.round()} min',
      'average gap between your cue time and your first start (last 14 days)',
      d < 10 ? 'That is close to on-the-dot.' : 'The goal is only to shrink it a little each week.',
    ];
  },
  'noZero': (v) {
    final nz = nonZeroDays(v);
    return [
      nz.contains(v.today) ? 'Not a zero' : 'Still open',
      nz.contains(v.today) ? 'Today already has something logged.' : 'Any one logged action keeps today from being a zero.',
      '${_plural(nz.length, 'non-zero day')} so far.',
    ];
  },
  'totalDays': (v) => ['${v.master.totalDays}', 'days shown up in total', 'Never resets, whatever the streak does.'],
  'consistency': (v) => ['${consistency(v)}%', 'of the last 30 days had a session or a habit tick'],
  'lifetime': (v) => [
        '${v.starts} starts',
        '${(_minutes(_done(v)) / 60).toStringAsFixed(1)} hours of work',
        _plural(v.type(Ev.proof).length, 'proof upload'),
        '${_plural(v.master.totalDays, 'day')} shown up',
      ],
};
