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
  return out;
}

// ---- 49. Time-window streaks ---------------------------------------------------
/// True when [minuteOfDay] is inside the habit's window (or it has none).
bool inWindow(Rec habit, int minuteOfDay) {
  final from = habit.data['from'], to = habit.data['to'];
  if (from is! int || to is! int || from == to) return true;
  return from < to ? minuteOfDay >= from && minuteOfDay < to : minuteOfDay >= from || minuteOfDay < to;
}
