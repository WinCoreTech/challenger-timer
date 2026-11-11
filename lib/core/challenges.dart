/// Challenges (features 84 to 89 and 99). Everything is derived from the
/// event log: targets are deterministic per day or week, so nothing is stored.
/// Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';

class Challenge {
  const Challenge(this.title, this.have, this.need, this.xp);
  final String title;
  final int have, need, xp;
  bool get done => have >= need;
  double get progress => need == 0 ? 1 : (have / need).clamp(0.0, 1.0);
}

int _sessions(DayView v, bool Function(Event) where) => v.type(Ev.sessionDone).where(where).length;
int _minutes(DayView v, bool Function(Event) where) =>
    v.type(Ev.sessionDone).where(where).fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());

/// Feature 84: one challenge per day, rotating through a fixed list.
Challenge dailyChallenge(DayView v, int day) {
  bool on(Event e) => e.day == day;
  // Minutes after the day boundary for the session's start.
  final starts = {for (final e in v.type(Ev.sessionStart)) e.get<String>('sid'): e.moment.minuteOfDay};
  switch (day % 5) {
    case 0:
      return Challenge('3 sessions today', _sessions(v, on), 3, 40);
    case 1:
      return Challenge(
          '2 sessions started before 2 pm',
          _sessions(v, (e) => on(e) && (starts[e.get<String>('sid')] ?? 1440) < 14 * 60 && (starts[e.get<String>('sid')] ?? 0) >= v.dayEndHour * 60),
          2, 40);
    case 2:
      return Challenge('15 minutes of work today', _minutes(v, on), 15, 40);
    case 3:
      return Challenge('Proof saved for 2 sessions', v.type(Ev.proof).where(on).length, 2, 40);
    default:
      return Challenge('One session of 15 minutes or more',
          _sessions(v, (e) => on(e) && (e.get<num>('minutes') ?? 0) >= 15), 1, 40);
  }
}

/// Feature 85: this week's boss is one more session than last week, at least 5.
Challenge weeklyBoss(DayView v, int week) {
  final last = _sessions(v, (e) => weekOf(e.day) == week - 1);
  final need = (last + 1).clamp(5, 40);
  return Challenge('Weekly boss: $need sessions by Sunday night', _sessions(v, (e) => weekOf(e.day) == week), need, 150);
}

const _campaigns = [
  'Show-up month', 'Proof month', 'Early-start month', 'Deep-work month', 'No-zero month', 'Finish-line month',
];

/// Feature 86: a 30-day themed campaign per calendar month: 20 active days.
Challenge monthlyCampaign(DayView v, int month) {
  final have = v.showedUpDays.where((d) => monthKey(d) == month).length;
  return Challenge('${_campaigns[month % _campaigns.length]}: 20 active days this month', have, 20, 500);
}

/// Feature 87: a mission appears on roughly one day in three.
Challenge? missionCard(DayView v, int day) {
  if ((day * 2654435761) % 3 != 0) return null;
  bool on(Event e) => e.day == day;
  return switch ((day ~/ 3) % 3) {
    0 => Challenge('Mission: save a photo as proof', v.type(Ev.proof).where((e) => on(e) && e.get<String>('kind') == 'photo').length, 1, 25),
    1 => Challenge('Mission: write a parking note', v.type(Ev.parkingNote).where(on).length, 1, 25),
    _ => Challenge('Mission: two sessions back to back', day == v.today ? inDayChain(v) : 0, 2, 25),
  };
}

/// Feature 88: today's target is yesterday's minutes plus one.
Challenge beatYesterday(DayView v) {
  final y = _minutes(v, (e) => e.day == v.today - 1);
  return Challenge('Beat yesterday: ${y + 1} minutes', v.minutesToday, y + 1, 0);
}

/// Feature 89: your best day so far and how far along it was by this time.
({int bestDay, int bestTotal, int ghostNow, int youNow}) ghostRace(DayView v) {
  final per = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    if (e.day != v.today) per[e.day] = (per[e.day] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
  }
  if (per.isEmpty) return (bestDay: -1, bestTotal: 0, ghostNow: 0, youNow: v.minutesToday);
  final best = per.entries.reduce((a, b) => a.value >= b.value ? a : b);
  int sinceBoundary(Moment m) => (m.minuteOfDay - v.dayEndHour * 60) % 1440;
  final nowMin = sinceBoundary(v.now);
  final ghost = _minutes(v, (e) => e.day == best.key && sinceBoundary(e.moment) <= nowMin);
  return (bestDay: best.key, bestTotal: best.value, ghostNow: ghost, youNow: v.minutesToday);
}

/// XP from finished challenges, summed over every day, week and month so far.
List<(String, int)> challengeXp(DayView v) {
  final out = <(String, int)>[];
  final days = {...v.sessionDays, for (final e in v.type(Ev.proof)) e.day, for (final e in v.type(Ev.parkingNote)) e.day};
  var daily = 0, missions = 0;
  for (final d in days) {
    if (v.flagOn(84) && dailyChallenge(v, d).done) daily += dailyChallenge(v, d).xp;
    if (v.flagOn(87)) {
      final m = missionCard(v, d);
      if (m != null && m.done) missions += m.xp;
    }
  }
  if (daily > 0) out.add(('Daily challenges', daily));
  if (missions > 0) out.add(('Mission cards', missions));
  if (v.flagOn(85)) {
    final weeks = {for (final d in v.sessionDays) weekOf(d)};
    final won = weeks.where((w) => weeklyBoss(v, w).done).length;
    if (won > 0) out.add(('Weekly bosses beaten', won * 150));
  }
  if (v.flagOn(86)) {
    final months = {for (final d in v.showedUpDays) monthKey(d)};
    final won = months.where((m) => monthlyCampaign(v, m).done).length;
    if (won > 0) out.add(('Monthly campaigns', won * 500));
  }
  return out;
}
