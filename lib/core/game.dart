/// Rank, XP and rewards (features 226 to 250). Pure Dart, all from the log.
library;

import 'dart:math';

import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'rules.dart';

/// 229: a slow, steady curve. Level 2 at 100 XP, 3 at 400, 4 at 900...
int levelFor(int xp) => sqrt(xp / 100).floor() + 1;
int xpForLevel(int level) => (level - 1) * (level - 1) * 100;

/// 230: the shown rank slips one step for every full 7 idle days. XP and
/// unlocked features are untouched, and one session restores it.
int idleSteps(DayView v) => v.flagOn(230) ? daysAway(v) ~/ 7 : 0;

/// 247: times the top of the ladder has been passed.
int prestige(DayView v) => v.flagOn(247) ? v.xpTotal ~/ v.ranks.last.xp : 0;

/// The rank shown on Home and Me: prestige laps (247) and idle decay (230).
RankView shownRank(DayView v) {
  final top = v.ranks.last.xp;
  final lap = prestige(v) > 0 ? v.xpTotal % top : v.xpTotal;
  final base = rankFor(lap, v.ranks);
  final i = (base.index - idleSteps(v)).clamp(0, v.ranks.length - 1);
  return i == base.index ? base : RankView(i, v.ranks[i], v.ranks[i + 1], 0);
}

int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

/// 236: about one finished session in four opens a chest of 10 to 50 XP.
/// Decided by the session id, so it is the same every time it is computed.
int chestFor(String sid) {
  final h = _hash(sid);
  return h % 4 == 0 ? 10 + (h ~/ 4) % 5 * 10 : 0;
}

/// 679: sessions since the last chest (for "one more to the chest" it is unknown
/// by design, so only the count since the last one is shown).
int sinceChest(DayView v) {
  var n = 0;
  for (final e in v.type(Ev.sessionDone).toList().reversed) {
    if (chestFor(e.get<String>('sid') ?? '') > 0) break;
    n++;
  }
  return n;
}

/// 237: three small quests, the same every day.
List<(String, bool)> dailyQuests(DayView v, int day) => [
      ('Start one session', v.type(Ev.sessionStart).any((e) => e.day == day)),
      ('Save one proof', v.type(Ev.proof).any((e) => e.day == day)),
      ('Tick a habit or leave a parking note',
          v.type(Ev.habitTick).any((e) => e.day == day) || v.type(Ev.parkingNote).any((e) => e.day == day)),
    ];

int _questXp(DayView v) {
  final days = {...v.sessionDays, for (final e in v.type(Ev.habitTick)) e.day, for (final e in v.type(Ev.sessionStart)) e.day};
  return days.fold(0, (a, d) => a + dailyQuests(v, d).where((q) => q.$2).length * 10);
}

/// 238: one coin per finished session, five more for a day with all quests done.
int coinsEarned(DayView v) {
  final full = v.sessionDays.where((d) => dailyQuests(v, d).every((q) => q.$2)).length;
  return v.type(Ev.sessionDone).length + full * 5;
}

int coinsSpent(DayView v) => v.type(Ev.tool).where((e) => e.get<int>('n') == 239).fold(0, (a, e) => a + (e.get<int>('coins') ?? 0));
int coins(DayView v) => coinsEarned(v) - coinsSpent(v);

/// 240: rupees saved, at the amount per session you chose.
int savingsJar(DayView v) => v.type(Ev.sessionDone).length * v.settingInt('jarAmount', 0);

/// 249: sessions finished today.
int combo(DayView v) => v.sessionsToday;

/// 245: personal records.
({int bestDayMinutes, int bestDay, int bestWeekMinutes, int longestStreak, int longestSession}) records(DayView v) {
  final day = <int, int>{}, week = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    final m = (e.get<num>('minutes') ?? 0).toInt();
    day[e.day] = (day[e.day] ?? 0) + m;
    week[weekOf(e.day)] = (week[weekOf(e.day)] ?? 0) + m;
  }
  final best = day.entries.fold<MapEntry<int, int>?>(null, (a, b) => a == null || b.value > a.value ? b : a);
  return (
    bestDayMinutes: best?.value ?? 0,
    bestDay: best?.key ?? -1,
    bestWeekMinutes: week.values.fold(0, (a, b) => a > b ? a : b),
    longestStreak: v.master.longest,
    longestSession: v.metrics['longestSession'] ?? 0,
  );
}

/// 244: twelve-week seasons. Minutes this season and last season up to the
/// same day of the season.
({int season, int now, int last}) seasons(DayView v) {
  final w = weekOf(v.today);
  final season = w ~/ 12;
  final dayIn = v.today - weekStartOf(season * 12);
  var now = 0, last = 0;
  for (final e in v.type(Ev.sessionDone)) {
    final s = weekOf(e.day) ~/ 12;
    final m = (e.get<num>('minutes') ?? 0).toInt();
    if (s == season) now += m;
    if (s == season - 1 && e.day - weekStartOf(s * 12) <= dayIn) last += m;
  }
  return (season: season, now: now, last: last);
}

int weekStartOf(int week) => week * 7 - 3;

/// 241: hours per project, as a simple skill ladder.
List<(String name, double hours, int tier)> skillTrees(DayView v) => [
      for (final p in v.projects)
        () {
          final m = v.type(Ev.sessionDone).where((e) => e.get<String>('projectId') == p.id).fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
          final h = m / 60;
          return (p.str('name'), h, const [1, 10, 50, 100, 500, 1000].where((t) => h >= t).length);
        }()
    ];

List<(String, int)> gameXp(DayView v) {
  final out = <(String, int)>[];
  if (v.flagOn(236)) {
    final c = v.type(Ev.sessionDone).fold(0, (a, e) => a + chestFor(e.get<String>('sid') ?? ''));
    if (c > 0) out.add(('Reward chests', c));
  }
  if (v.flagOn(237)) {
    final q = _questXp(v);
    if (q > 0) out.add(('Daily quests', q));
  }
  return out;
}
