/// Small pure rules: XP, ranks, the delayed off switch, the first-task lock and
/// the buddy message. No Flutter imports.
library;

import 'dart:convert';
import 'day.dart';
import 'events.dart';

// ---- XP ---------------------------------------------------------------
/// Starting pays the most: one 2-minute start (50 + 4) beats 25 idle minutes
/// added to a session that was already running (50).
const int xpStart = 50;
const int xpPerMinute = 2;
const int xpProof = 20;
const int xpHabitTick = 10;
const int xpDailyBonus = 100;

/// Starts beyond this many per day pay no start XP, so start-and-cancel loops
/// are pointless.
const int paidStartsPerDay = 5;

class XpBreakdown {
  const XpBreakdown(this.starts, this.minutes, this.proof, this.habits, this.bonus, this.extra);
  final int starts, minutes, proof, habits, bonus, extra;
  int get total => starts + minutes + proof + habits + bonus + extra;
}

/// XP is recomputed from the whole log every time. The daily bonus is granted
/// for today in advance and for each past day only if that day had a session.
XpBreakdown computeXp(List<Event> events, int today, {bool bonusOn = true}) {
  var starts = 0, minutes = 0, proof = 0, habits = 0, extra = 0;
  final startsPerDay = <int, int>{};
  final sessionDays = <int>{};
  int? first;
  for (final e in events) {
    if (first == null || e.day < first) first = e.day;
    switch (e.type) {
      case Ev.sessionStart:
        final n = startsPerDay[e.day] = (startsPerDay[e.day] ?? 0) + 1;
        if (n <= paidStartsPerDay) starts += xpStart;
      case Ev.sessionDone:
        minutes += (e.get<num>('minutes') ?? 0).toInt() * xpPerMinute;
        sessionDays.add(e.day);
      case Ev.proof:
        proof += xpProof;
      case Ev.habitTick:
        habits += xpHabitTick;
    }
    extra += (e.get<num>('xp') ?? 0).toInt();
  }
  var bonus = 0;
  if (bonusOn && first != null) {
    bonus = sessionDays.where((d) => d < today && d >= first!).length * xpDailyBonus;
    bonus += xpDailyBonus; // today's bonus is already in the pocket
  }
  return XpBreakdown(starts, minutes, proof, habits, bonus, extra);
}

// ---- Ranks (defined in assets/ranks.json) -----------------------------
class Rank {
  const Rank(this.name, this.xp, this.blurb);
  final String name;
  final int xp;
  final String blurb;
}

List<Rank> parseRanks(String json) => [
      for (final r in jsonDecode(json) as List)
        Rank(r['name'] as String, r['xp'] as int, r['blurb'] as String? ?? '')
    ]..sort((a, b) => a.xp.compareTo(b.xp));

class RankView {
  const RankView(this.index, this.rank, this.next, this.progress);
  final int index;
  final Rank rank;
  final Rank? next;

  /// 0..1 toward the next rank.
  final double progress;
}

RankView rankFor(int xp, List<Rank> ranks) {
  var i = 0;
  while (i + 1 < ranks.length && xp >= ranks[i + 1].xp) {
    i++;
  }
  final next = i + 1 < ranks.length ? ranks[i + 1] : null;
  final p = next == null ? 1.0 : (xp - ranks[i].xp) / (next.xp - ranks[i].xp);
  return RankView(i, ranks[i], next, p.clamp(0.0, 1.0));
}

// ---- Achievements (defined in assets/achievements.json) ----------------
class Achievement {
  const Achievement(this.id, this.name, this.desc, this.metric, this.gte, this.hidden);
  final String id, name, desc, metric;
  final int gte;
  final bool hidden;
  bool earned(Map<String, int> metrics) => (metrics[metric] ?? 0) >= gte;
}

List<Achievement> parseAchievements(String json) => [
      for (final a in jsonDecode(json) as List)
        Achievement(a['id'] as String, a['name'] as String, a['desc'] as String,
            a['metric'] as String, a['gte'] as int, a['hidden'] == true)
    ];

// ---- Delayed off switch ------------------------------------------------
/// Turning a lock ON is instant. Turning it OFF takes [offDelayMs]: the switch
/// stays effective until [offAt], and the request can be cancelled until then.
const int offDelayMs = 24 * msPerHour;

class DelayedSwitch {
  const DelayedSwitch({this.on = false, this.offAt});
  factory DelayedSwitch.parse(String? s, {bool or = false}) {
    if (s == null) return DelayedSwitch(on: or);
    final j = jsonDecode(s) as Map;
    return DelayedSwitch(on: j['on'] == true, offAt: j['offAt'] as int?);
  }
  final bool on;
  final int? offAt;

  bool effective(int nowMs) => on && (offAt == null || nowMs < offAt!);
  bool pendingOff(int nowMs) => on && offAt != null && nowMs < offAt!;
  int msUntilOff(int nowMs) => pendingOff(nowMs) ? offAt! - nowMs : 0;

  DelayedSwitch turnOn() => const DelayedSwitch(on: true);
  DelayedSwitch requestOff(int nowMs) =>
      effective(nowMs) ? DelayedSwitch(on: true, offAt: offAt ?? nowMs + offDelayMs) : const DelayedSwitch();
  DelayedSwitch cancelOff() => DelayedSwitch(on: on);

  /// Collapses an elapsed countdown into plain "off".
  DelayedSwitch settle(int nowMs) => effective(nowMs) ? this : const DelayedSwitch();
  String encode() => jsonEncode({'on': on, 'offAt': offAt});
}

String countdown(int ms) {
  final s = (ms / 1000).ceil();
  final h = s ~/ 3600, m = s % 3600 ~/ 60, sec = s % 60;
  return h > 0 ? '${h}h ${two(m)}m' : '${two(m)}:${two(sec)}';
}

// ---- Locked first task ---------------------------------------------------
const int planLockHour = 22;

class Plan {
  const Plan(this.forDay, this.task, this.cueMinute);
  final int forDay;
  final String task;
  final int cueMinute;
}

/// Latest plan written for [day], if any.
Plan? planFor(List<Event> events, int day) {
  for (final e in events.reversed) {
    if (e.type == Ev.planSet && e.get<int>('forDay') == day) {
      return Plan(day, e.get<String>('task') ?? '', e.get<int>('cueMinute') ?? 0);
    }
  }
  return null;
}

/// True from 10 pm until the logical day ends. Inside this window an existing
/// plan for tomorrow cannot be edited (an empty one can still be set once).
bool inLockWindow(Moment now, int dayEndHour) =>
    now.hour >= planLockHour || now.hour < dayEndHour;

// ---- Buddy report --------------------------------------------------------
String buddyMessage({required String name, required int sessions, required int minutes, required int streak}) {
  final who = name.trim().isEmpty ? 'Your buddy' : name.trim();
  final s = streak == 1 ? '1 day' : '$streak days';
  if (sessions <= 0) {
    return '$who did not start a session today. Streak stands at $s. '
        'A kind nudge tomorrow morning would help. (Sent automatically by Challenger Timer)';
  }
  final n = sessions == 1 ? '1 session' : '$sessions sessions';
  return '$who showed up today: $n, $minutes min of work, proof saved. Streak: $s. '
      '(Sent automatically by Challenger Timer)';
}

// ---- Next tiny step ------------------------------------------------------
const String defaultStep = 'Open your notebook to the page you stopped on.';

/// Flags a step that does not start with a physical verb (feature 167 reuses it).
const _verbs = {
  'open', 'write', 'read', 'draw', 'type', 'solve', 'pick', 'put', 'take', 'find', 'list', 'run',
  'sketch', 'copy', 'call', 'send', 'print', 'pack', 'clear', 'start', 'create', 'make', 'fix',
  'watch', 'review', 'mark', 'fill', 'install', 'download', 'email', 'ask', 'draft', 'outline',
  'highlight', 'code', 'debug', 'test', 'push', 'commit', 'submit', 'upload', 'note', 'do', 'finish',
  'continue', 'revise', 'practice', 'practise', 'build', 'plug', 'sit', 'set', 'go', 'get', 'paste',
};
bool startsWithVerb(String s) {
  final w = s.trim().toLowerCase().split(RegExp(r'[^a-z]+')).where((x) => x.isNotEmpty);
  return w.isNotEmpty && _verbs.contains(w.first);
}
