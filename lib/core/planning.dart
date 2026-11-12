/// Daily and weekly planning (features 176 to 200). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';

/// 179: one class in the timetable. wd is 1 = Monday .. 7 = Sunday.
List<Rec> classesOn(DayView v, int weekday) =>
    v.of('class').where((c) => c.integer('wd') == weekday).toList()..sort((a, b) => a.integer('from').compareTo(b.integer('from')));

/// True while a lecture is running (used by class silence, feature 468).
bool inClass(DayView v, Moment m) {
  final wd = DateTime.utc(1970, 1, 1).add(Duration(milliseconds: m.wallMs)).weekday;
  return classesOn(v, wd).any((c) => m.minuteOfDay >= c.integer('from') && m.minuteOfDay < c.integer('to'));
}

/// 180: gaps of at least [min] minutes between 08:00 and 21:00 on [weekday].
List<(int from, int to)> freeSlots(DayView v, int weekday, {int min = 30, int dayFrom = 8 * 60, int dayTo = 21 * 60}) {
  final out = <(int, int)>[];
  var cursor = dayFrom;
  for (final c in classesOn(v, weekday)) {
    if (c.integer('from') - cursor >= min) out.add((cursor, c.integer('from')));
    if (c.integer('to') > cursor) cursor = c.integer('to');
  }
  if (dayTo - cursor >= min) out.add((cursor, dayTo));
  return out;
}

/// 195 and 306: minutes of finished work per hour of day.
List<int> minutesByHour(DayView v) {
  final h = List.filled(24, 0);
  for (final e in v.type(Ev.sessionDone)) {
    h[e.moment.hour] += (e.get<num>('minutes') ?? 0).toInt();
  }
  return h;
}

int? peakHour(DayView v) {
  final h = minutesByHour(v);
  final best = h.reduce((a, b) => a > b ? a : b);
  return best == 0 ? null : h.indexOf(best);
}

/// 185: sessions this week per project against its weekly target.
List<(String name, int have, int need)> weeklyTargets(DayView v) => [
      for (final p in v.projects)
        if (p.integer('weekly') > 0)
          (
            p.str('name'),
            v.type(Ev.sessionDone).where((e) => e.get<String>('projectId') == p.id && weekOf(e.day) == weekOf(v.today)).length,
            p.integer('weekly')
          )
    ];

/// 200: this week's numbers.
Map<String, int> scoreboard(DayView v) {
  bool wk(Event e) => weekOf(e.day) == weekOf(v.today);
  final done = v.type(Ev.sessionDone).where(wk);
  return {
    'Days shown up': v.showedUpDays.where((d) => weekOf(d) == weekOf(v.today)).length,
    'Starts': v.type(Ev.sessionStart).where(wk).length,
    'Sessions finished': done.length,
    'Minutes': done.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt()),
    'Proof saved': v.type(Ev.proof).where(wk).length,
    'Habit ticks': v.type(Ev.habitTick).where(wk).length,
    'Tasks finished': v.type(Ev.taskDone).where(wk).length,
  };
}

/// 191: for the last [days] days, the planned cue minute and the real first start.
List<(int day, int? planned, int? actual)> planVsActual(DayView v, {int days = 7}) {
  final first = <int, int>{};
  for (final e in v.type(Ev.sessionStart)) {
    final m = e.moment.minuteOfDay;
    if (!first.containsKey(e.day) || m < first[e.day]!) first[e.day] = m;
  }
  return [
    for (var d = v.today - days + 1; d <= v.today; d++)
      (
        d,
        v.type(Ev.planSet).where((e) => e.get<int>('forDay') == d).lastOrNull?.get<int>('cueMinute'),
        first[d]
      )
  ];
}
