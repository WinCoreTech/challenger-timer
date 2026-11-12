/// Identity, emotions, energy and sleep (features 251 to 325). Pure Dart.
library;

import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'tools.dart';

/// 252/253: every finished session, habit tick and proof is one vote.
int votes(DayView v) => v.type(Ev.sessionDone).length + v.type(Ev.habitTick).length + v.type(Ev.proof).length;

double? _avg(Iterable<num> xs) => xs.isEmpty ? null : xs.fold<num>(0, (a, b) => a + b) / xs.length;
List<(int, int)> _lastDays(DayView v, int tool, int days) => v.toolRatings(tool).where((r) => r.$1 > v.today - days).toList();

/// 278 and 281: the fix that matches the feeling or the kind of dislike.
const fixes = <String, (String, int)>{
  'overwhelmed': ('Shrink it. Pick the smallest piece and do only that for two minutes.', 2),
  'confused': ('Write the exact question you cannot answer yet. That is the task now.', 2),
  'bored': ('Race the timer. How much fits in five minutes?', 5),
  'anxious': ('Ugly draft. Make it bad on purpose, nobody sees it.', 5),
  'boring': ('Pair it with music or race a five-minute timer.', 5),
  'hard': ('Do the easiest tenth first. Hard things are easy things in a row.', 2),
  'unclear': ('Write what "done" would look like in one sentence, then the first action.', 2),
  'pointless': ('Write one line on who cares if this gets done. If nobody does, drop it.', 2),
};

/// 292: average mood before sessions (tool 276) and after (tool 292).
(double?, double?) moodBeforeAfter(DayView v) =>
    (_avg(v.toolRatings(276).map((r) => r.$2)), _avg(v.toolRatings(292).map((r) => r.$2)));

/// 299: two weeks of low mood (average 2 or less over at least 5 entries).
bool lowMoodTwoWeeks(DayView v) {
  final r = _lastDays(v, 276, 14);
  return r.length >= 5 && _avg(r.map((x) => x.$2))! <= 2;
}

/// 296: the latest weekly stress rating is 4 or 5.
bool highStress(DayView v) {
  final r = _lastDays(v, 296, 7);
  return r.isNotEmpty && r.last.$2 >= 4;
}

int _weekMinutes(DayView v, int week) => v
    .type(Ev.sessionDone)
    .where((e) => weekOf(e.day) == week)
    .fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());

/// 297: more minutes than last week while mood fell.
bool burnoutRisk(DayView v) {
  final w = weekOf(v.today);
  final now = _avg(v.toolRatings(276).where((r) => weekOf(r.$1) == w).map((r) => r.$2));
  final before = _avg(v.toolRatings(276).where((r) => weekOf(r.$1) == w - 1).map((r) => r.$2));
  return now != null && before != null && now < before && _weekMinutes(v, w) > _weekMinutes(v, w - 1) && _weekMinutes(v, w) > 300;
}

/// 325: more minutes than last week but fewer finished tasks.
bool hoursWarning(DayView v) {
  final w = weekOf(v.today);
  int tasks(int k) => v.type(Ev.taskDone).where((e) => weekOf(e.day) == k).length;
  return _weekMinutes(v, w) > _weekMinutes(v, w - 1) && tasks(w) < tasks(w - 1);
}

/// 303: the protected sleep window in minutes of day (from, to).
(int, int) sleepWindow(DayView v) => (v.settingInt('bedHour', 23) * 60, v.settingInt('wakeHour', 7) * 60);

bool inSleepWindow(DayView v, int minute) {
  if (!v.flagOn(303)) return false;
  final (from, to) = sleepWindow(v);
  return from < to ? minute >= from && minute < to : minute >= from || minute < to;
}

/// 304: average work minutes on days after 7+ hours of sleep and after less.
(double?, double?) sleepVsFocus(DayView v) {
  final per = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    per[e.day] = (per[e.day] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
  }
  final good = <int>[], short = <int>[];
  for (final (day, hours) in v.toolRatings(301)) {
    (hours >= 7 ? good : short).add(per[day] ?? 0);
  }
  return (_avg(good), _avg(short));
}

/// 320: 0 to 100 from sleep (last 7 logs), a rest day this week and breaks taken.
int recoveryScore(DayView v) {
  final sleep = _avg(_lastDays(v, 301, 7).map((r) => r.$2)) ?? 0;
  final sleepPts = (sleep / 8 * 60).clamp(0, 60);
  final week = [for (var d = v.today - 6; d <= v.today; d++) d];
  final restPts = week.any((d) => !v.sessionDays.contains(d)) ? 20 : 0;
  final breaks = v.type(Ev.breakStart).where((e) => e.day > v.today - 7).length;
  return (sleepPts + restPts + (breaks >= 3 ? 20 : breaks * 6)).round().clamp(0, 100);
}

/// 269: minutes in your first 30 days against the last 30.
(int first, int last) changeTimeline(DayView v) {
  final days = v.sessionDays;
  if (days.isEmpty) return (0, 0);
  final start = days.reduce((a, b) => a < b ? a : b);
  int sum(bool Function(int) f) => v.type(Ev.sessionDone).where((e) => f(e.day)).fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  return (sum((d) => d < start + 30), sum((d) => d > v.today - 30));
}

/// 290: sessions finished on low-mood days plus proofs tagged "did it anyway".
int discomfortReps(DayView v) => goldDays(v).length + v.proofs.where((p) => p.str('anyway').isNotEmpty).length;

/// 280 and 439: open tasks pushed or moved most often.
List<Rec> mostPostponed(DayView v) => (v.of(Kind.task).where((t) => !t.flag('done') && t.integer('postponed') + t.integer('moved') > 0).toList()
      ..sort((a, b) => (b.integer('postponed') + b.integer('moved')).compareTo(a.integer('postponed') + a.integer('moved'))))
    .take(5)
    .toList();

/// 287: yesterday was closed with the forgive button.
bool forgaveYesterday(DayView v) => v.type(Ev.tool).any((e) => e.get<int>('n') == 287 && e.day == v.today);
