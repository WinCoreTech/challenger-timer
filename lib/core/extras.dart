/// Small pure helpers for individual features. Each names its feature number.
library;

import 'dart:math';

import 'engine.dart';
import 'events.dart';

// ---- 18. Voice start ------------------------------------------------------
class VoiceCommand {
  const VoiceCommand(this.minutes, this.projectId);
  final int minutes;
  final String? projectId;
}

const _numberWords = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'ten': 10, 'fifteen': 15, 'twenty': 20,
  'twenty five': 25, 'twenty-five': 25, 'thirty': 30, 'forty five': 45, 'fifty': 50, 'ninety': 90,
};

/// Understands "start five minutes on DSA", "start 25", "begin". Returns null
/// when the phrase is not a start request.
VoiceCommand? parseVoice(String heard, List<Rec> projects) {
  final s = heard.toLowerCase().trim();
  if (!RegExp(r'\b(start|begin|go)\b').hasMatch(s)) return null;
  var minutes = 2;
  final digits = RegExp(r'(\d{1,3})').firstMatch(s);
  if (digits != null) {
    minutes = int.parse(digits.group(1)!);
  } else {
    for (final e in (_numberWords.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length)))) {
      if (RegExp('\\b${e.key}\\b').hasMatch(s)) {
        minutes = e.value;
        break;
      }
    }
  }
  if (RegExp(r'\bhours?\b').hasMatch(s)) minutes *= 60;
  String? pid;
  final on = RegExp(r'\b(?:on|for)\s+(.+)$').firstMatch(s.replaceAll(RegExp(r'\b(minutes?|mins?|hours?)\b'), ''));
  final wanted = on?.group(1)?.trim() ?? '';
  for (final p in projects) {
    final name = p.str('name').toLowerCase();
    if (name.isNotEmpty && (s.contains(name) || (wanted.isNotEmpty && name.contains(wanted)))) {
      pid = p.id;
      break;
    }
  }
  return VoiceCommand(minutes.clamp(1, 180), pid);
}

// ---- 14. Dice start -------------------------------------------------------
/// Up to three candidates: today's planned first task, then open tasks.
List<String> diceOptions(DayView v) {
  final out = <String>[];
  final p = v.todayPlan;
  if (p != null && p.task.isNotEmpty) out.add(p.task);
  for (final t in v.of(Kind.task)) {
    if (out.length >= 3) break;
    if (!t.flag('done') && !out.contains(t.str('title'))) out.add(t.str('title'));
  }
  if (out.isEmpty) out.add(v.nextStep);
  return out;
}

String rollDice(List<String> options, Random rng) => options[rng.nextInt(options.length)];

// ---- 29. Weekly streaks -----------------------------------------------------
/// Monday-based week index of a logical day.
int weekOf(int day) => (day + 3) ~/ 7; // 1970-01-01 was a Thursday

/// Consecutive weeks with at least [target] active days. The current week
/// counts once it reaches the target and never breaks the run while open.
int weeklyStreak(Set<int> days, int today, int target) {
  final per = <int, int>{};
  for (final d in days) {
    if (d <= today) per[weekOf(d)] = (per[weekOf(d)] ?? 0) + 1;
  }
  var w = weekOf(today);
  var n = 0;
  if ((per[w] ?? 0) >= target) n++;
  for (w = w - 1; (per[w] ?? 0) >= target; w--) {
    n++;
  }
  return n;
}

int doneThisWeek(Set<int> days, int today) => days.where((d) => d <= today && weekOf(d) == weekOf(today)).length;

// ---- 30. In-day chain ---------------------------------------------------------
/// Longest run of today's sessions where each started within [gapMin] minutes
/// of the previous one ending.
int inDayChain(DayView v, {int gapMin = 15}) {
  final starts = {for (final e in v.type(Ev.sessionStart)) e.get<String>('sid'): e.ts};
  final done = v.type(Ev.sessionDone).where((e) => e.day == v.today).toList();
  var best = 0, run = 0;
  int? lastEnd;
  for (final e in done) {
    final st = starts[e.get<String>('sid')] ?? e.ts;
    run = lastEnd != null && st - lastEnd <= gapMin * 60000 ? run + 1 : 1;
    if (run > best) best = run;
    lastEnd = e.ts;
  }
  return best;
}

// ---- 33. Growing flame --------------------------------------------------------
const flameSteps = [3, 7, 14, 30, 66, 100];

/// 0..1 size of the streak flame: one step up at each milestone.
double flameLevel(int streak) => flameSteps.where((s) => streak >= s).length / flameSteps.length;

// ---- 46. Odd milestones and 47. Streak wager: feature XP ----------------------
const oddMilestones = {11: 111, 23: 123, 47: 147};

class Wager {
  const Wager(this.day, this.amount, this.state);
  final int day, amount;

  /// 'open', 'won' or 'lost'.
  final String state;
}

/// A wager placed on day d is won when d..d+6 pass with no uncovered miss,
/// and lost as soon as one of those days is an uncovered miss.
List<Wager> wagers(DayView v) => [
      for (final e in v.type(Ev.tool).where((e) => e.get<int>('n') == 47 && e.get<int>('amount') != null))
        Wager(
            e.day,
            e.get<int>('amount')!,
            [for (var d = e.day; d <= e.day + 6; d++) d].any(v.master.missedDays.contains)
                ? 'lost'
                : v.today > e.day + 6 || (v.today == e.day + 6 && v.showedUpDays.contains(v.today))
                    ? 'won'
                    : 'open')
    ];

/// XP from features layered on top of the base rules. Uses [DayView.flagOn]
/// (never the rank gate) so XP cannot depend on itself.
List<(String, int)> featureXp(DayView v) {
  final out = <(String, int)>[];
  if (v.flagOn(46)) {
    for (final m in oddMilestones.entries) {
      if (v.master.longest >= m.key) out.add(('Surprise at ${m.key} days', m.value));
    }
  }
  if (v.flagOn(47)) {
    for (final w in wagers(v)) {
      if (w.state == 'won') out.add(('Streak wager won', w.amount));
      if (w.state == 'lost') out.add(('Streak wager lost', -w.amount));
    }
  }
  if (v.flagOn(57)) {
    final c = comebackBonus(v);
    if (c > 0) out.add(('Comeback bonus (double XP)', c));
  }
  return out;
}

// ---- 49. Time-window streaks ---------------------------------------------------
/// True when [minuteOfDay] is inside the habit's window (or it has none).
bool inWindow(Rec habit, int minuteOfDay) {
  final from = habit.data['from'], to = habit.data['to'];
  if (from is! int || to is! int || from == to) return true;
  return from < to ? minuteOfDay >= from && minuteOfDay < to : minuteOfDay >= from || minuteOfDay < to;
}

// ---- 58. Repair task ----------------------------------------------------------
/// Days restored by a repair (double minimum done the day after).
Set<int> repairedDays(DayView v) => {
      for (final e in v.type(Ev.tool))
        if (e.get<int>('n') == 58 && e.get<int>('repairDay') != null) e.get<int>('repairDay')!
    };

/// Yesterday can be repaired when it had nothing and today already holds
/// twice the minimum (4 minutes).
bool canRepair(DayView v) {
  final y = v.today - 1;
  final had = v.sessionDays.contains(y) ||
      v.type(Ev.habitTick).any((e) => e.day == y) ||
      repairedDays(v).contains(y);
  final any = v.events.any((e) => e.day < y);
  return !had && any && v.minutesToday >= 4;
}

// ---- 59. Sick and travel mode, 60. Exam mode ----------------------------------
/// Days covered by on/off toggle events of tool [n], through today while on.
Set<int> _toggledDays(DayView v, int n) {
  final out = <int>{};
  int? from;
  for (final e in v.type(Ev.tool).where((e) => e.get<int>('n') == n && e.payload.containsKey('on'))) {
    if (e.payload['on'] == true) {
      from ??= e.day;
    } else if (from != null) {
      for (var d = from; d <= e.day; d++) {
        out.add(d);
      }
      from = null;
    }
  }
  if (from != null) {
    for (var d = from; d <= v.today; d++) {
      out.add(d);
    }
  }
  return out;
}

bool _toggleOn(DayView v, int n) {
  var on = false;
  for (final e in v.type(Ev.tool)) {
    if (e.get<int>('n') == n && e.payload.containsKey('on')) on = e.payload['on'] == true;
  }
  return on;
}

Set<int> pausedDays(DayView v) => _toggledDays(v, 59);
bool pauseOn(DayView v) => _toggleOn(v, 59);
Set<int> examDays(DayView v) => _toggledDays(v, 60);
bool examOn(DayView v) => v.flagOn(60) && _toggleOn(v, 60);

// ---- 57. Comeback bonus ---------------------------------------------------------
/// The first session of each comeback day pays its XP a second time.
int comebackBonus(DayView v) {
  var xp = 0;
  for (final d in v.master.comebackDays) {
    for (final e in v.type(Ev.sessionDone)) {
      if (e.day == d) {
        xp += 50 + 2 * (e.get<num>('minutes') ?? 0).toInt();
        break;
      }
    }
  }
  return xp;
}

// ---- 64. Restart at tiny ---------------------------------------------------------
/// For 3 days after a habit's streak broke, the tiny version is the ask.
bool restartAtTiny(DayView v, String habitId) {
  final b = v.habitStreak(habitId).lastBreakDay;
  return b != null && v.today - b <= 3;
}

// ---- 65. Fresh-start dates ---------------------------------------------------------
/// "Monday", "the 1st" or "your birthday" when today is one of them.
String? freshStart(int today, {String birthday = ''}) {
  final d = DateTime.utc(1970, 1, 1 + today);
  final m = RegExp(r'^(\d{1,2})\D+(\d{1,2})').firstMatch(birthday.trim());
  if (m != null && int.parse(m.group(1)!) == d.day && int.parse(m.group(2)!) == d.month) return 'your birthday';
  if (d.day == 1) return 'the 1st';
  if (d.weekday == DateTime.monday) return 'Monday';
  return null;
}

// ---- 68. Half-credit days, 75. Gold bad days ------------------------------------------
/// Days with a started session that was never finished and nothing else.
Set<int> halfDays(DayView v) =>
    {for (final e in v.type(Ev.sessionStart)) if (!v.showedUpDays.contains(e.day)) e.day};

/// Session days on which the mood check (tool 276) was 2 or lower.
Set<int> goldDays(DayView v) {
  final low = <int>{};
  for (final e in v.type(Ev.tool)) {
    final val = e.get<num>('value');
    if (e.get<int>('n') == 276 && val != null && val <= 2) low.add(e.day);
  }
  return low.intersection(v.sessionDays);
}

// ---- 71. Return screen ------------------------------------------------------------------
/// Whole days since the last finished session or habit tick, 0 if none yet.
int daysAway(DayView v) {
  final past = v.showedUpDays.where((d) => d <= v.today);
  if (past.isEmpty) return 0;
  return v.today - past.reduce((a, b) => a > b ? a : b);
}

// ---- 70. Gifted freeze (local honour version) -----------------------------------------------
/// Days a gifted freeze was logged, at most one per calendar month.
List<int> giftDays(DayView v) {
  final seen = <int>{};
  final out = <int>[];
  for (final e in v.type(Ev.tool)) {
    if (e.get<int>('n') != 70) continue;
    final d = DateTime.utc(1970, 1, 1 + e.day);
    if (seen.add(d.year * 12 + d.month)) out.add(e.day);
  }
  return out;
}
