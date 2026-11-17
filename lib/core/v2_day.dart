/// Plan v2 section 6: the 2-minute door, daily score, shutdown ritual,
/// long-term goal and the reminder line pack. Pure Dart.
library;

import 'dart:convert';

import 'coach.dart';
import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'focus.dart';
import 'planning.dart';
import 'pressure.dart';
import 'settings.dart';
import 'streak_engine.dart';

// ---- 6.4 The 2-minute door ------------------------------------------------
const doorSources = {'door', 'cue', 'alarm', 'rescue', 'nudge', 'widget', 'tile', 'sticky', 'auto', 'block', 'tag', 'facedown'};

bool isDoor(Event start) => doorSources.contains(start.get<String>('source'));

/// Days on which a door session (2 minutes, opened by the alarm or the door
/// button) was finished. Stopping after the door still counts.
Set<int> doorDays(DayView v) {
  final doors = {for (final e in v.type(Ev.sessionStart)) if (isDoor(e)) e.get<String>('sid')};
  return {for (final e in v.type(Ev.sessionDone)) if (doors.contains(e.get<String>('sid'))) e.day};
}

StreakResult doorStreak(DayView v) => computeStreak(doorDays(v), v.today, rules: const StreakRules(freezesPerMonth: 0));

int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

/// A small random bonus for opening the door: 5, 10 or 15 XP, fixed per session.
int doorBonus(String sid) => 5 + _hash('door$sid') % 3 * 5;

/// XP from the door: the random bonus, and double XP for the block when the
/// user stayed on after the door ("Stay for 25?").
List<(String, int)> doorXp(DayView v) {
  final starts = {for (final e in v.type(Ev.sessionStart)) e.get<String>('sid'): e};
  var bonus = 0, stay = 0;
  for (final e in v.type(Ev.sessionDone)) {
    final st = starts[e.get<String>('sid')];
    if (st == null) continue;
    if (isDoor(st)) bonus += doorBonus(e.get<String>('sid') ?? '');
    if (st.payload['stay'] == true) stay += 50 + 2 * (e.get<num>('minutes') ?? 0).toInt();
  }
  return [if (bonus > 0) ('Door bonus (random 5 to 15 each)', bonus), if (stay > 0) ('Stayed after the door (double XP)', stay)];
}

/// The proof waiting now came from a door session, so "Stay for 25?" applies.
bool stayOffer(DayView v) => doorSources.contains(v.pendingProof?['source']) && v.active == null;

// ---- 6.5 Milestones ---------------------------------------------------------
const streakMilestones = [7, 14, 21, 30, 50, 75, 90, 100, 150, 200, 250, 300, 365];
const milestoneTitles = {
  7: 'One-Week Regular', 14: 'Fortnight Fixture', 21: 'Three-Week Habit', 30: 'Month Maker', 50: 'Fifty Flat',
  75: 'Seventy-Five Strong', 90: 'Quarter Keeper', 100: 'Centurion Of Showing Up', 150: 'Hundred-Fifty Club',
  200: 'Two Hundred Steady', 250: 'Quarter-Thousand', 300: 'Three Hundred Solid', 365: 'Year-Round',
};

/// Titles unlocked by the longest streak, and the next milestone.
({List<String> unlocked, int? next}) milestones(DayView v) => (
      unlocked: [for (final m in streakMilestones) if (v.master.longest >= m) milestoneTitles[m]!],
      next: streakMilestones.where((m) => m > v.master.longest).firstOrNull,
    );

// ---- 6.7 Daily score, shutdown, goal ----------------------------------------
int dailyTargetMinutes(DayView v) => (int.tryParse(v.kv['dailyTargetMinutes'] ?? '') ?? 50).clamp(25, 600);

/// Out of 100: minutes against the daily target (50), a qualifying streak
/// day (20), the planned first task followed by a session (15), and the
/// day's average focus score (15).
int dailyScore(DayView v, int day) {
  final done = v.type(Ev.sessionDone).where((e) => e.day == day).toList();
  final minutes = done.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  final work = (50 * minutes / dailyTargetMinutes(v)).clamp(0, 50);
  final streak = v.showedUpDays.contains(day) ? 20 : 0;
  final plan = v.type(Ev.planSet).any((e) => e.get<int>('forDay') == day) && done.isNotEmpty ? 15 : 0;
  final focus = done.isEmpty ? 0 : 15 * done.fold(0, (a, e) => a + focusScore(v, e.get<String>('sid') ?? '')) / done.length / 100;
  return (work + streak + plan + focus).round().clamp(0, 100);
}

/// Tomorrow's first task and start time, by fixed rules: the top open task
/// (earliest due, then smallest) or the current next step; the time you
/// usually start, or your cue time. Never inside the sleep window.
({String task, int minute}) suggestTomorrow(DayView v) {
  final top = autoPriority(v).firstOrNull;
  var minute = learnedCue(v) ?? v.cueMinute;
  if (minute < 4 * 60) minute = 7 * 60;
  return (task: top?.str('title') ?? v.nextStep, minute: minute);
}

bool shutdownDone(DayView v) => v.of('shutdown').any((r) => r.integer('day') == v.today);

/// Long-term goal: hours logged against a target the user set.
({String text, int target, double hours, double progress})? goal(DayView v) {
  final text = v.kv['goalText'] ?? '';
  final target = int.tryParse(v.kv['goalHours'] ?? '') ?? 0;
  if (text.isEmpty || target <= 0) return null;
  final hours = v.type(Ev.sessionDone).fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt()) / 60;
  return (text: text, target: target, hours: hours, progress: (hours / target).clamp(0.0, 1.0));
}

// ---- 6.6 Reminder lines -------------------------------------------------------
class Lines {
  const Lines(this.tiers);
  factory Lines.parse(String json) => Lines((jsonDecode(json) as Map).map((k, v) => MapEntry('$k', (v as List).cast<String>())));
  static const empty = Lines({});
  final Map<String, List<String>> tiers;
  int get count => tiers.values.fold(0, (a, b) => a + b.length);

  /// One line for [day] at the current pressure level. Deterministic, so the
  /// same day shows the same line everywhere.
  String pick(DayView v, int day, {int salt = 0}) {
    final tier = const ['gentle', 'firm', 'relentless'][pressureLevel(v).clamp(0, 2)];
    final list = tiers[tier] ?? const [];
    return list.isEmpty ? 'Two minutes. That is the whole ask.' : list[(day * 7 + salt) % list.length];
  }
}

/// 7 pm: the streak is alive, today has no qualifying session yet.
bool streakAtRiskTonight(DayView v) => v.master.current > 0 && !v.showedUpDays.contains(v.today);

int reminderCap(DayView v) => v.prefInt(S.remindersPerDay).clamp(0, 5);

/// Top drift causes and the worst hour, as plain lines for Stats.
List<String> driftLines(DayView v, int from, int to) {
  final causes = topDriftCauses(v, fromDay: from, toDay: to);
  final byHour = List.filled(24, 0);
  for (final e in v.type(Ev.tool)) {
    if (e.get<int>('n') == 92 && e.day >= from && e.day <= to) byHour[e.moment.hour]++;
  }
  final worst = byHour.reduce((a, b) => a > b ? a : b);
  return [
    if (causes.isNotEmpty) 'Top causes: ${causes.take(3).map((c) => '${c.$1} (${c.$2})').join(', ')}',
    if (worst > 0) 'Most drifts around ${two(byHour.indexOf(worst))}:00.',
  ];
}

// ---- 6.5 Recovery challenge ---------------------------------------------------
/// After a streak breaks, a short challenge brings it back: three qualifying
/// days within the next five. Finishing it pays 100 XP once.
class Recovery {
  const Recovery(this.fromDay, this.have, this.need, this.daysLeft);
  final int fromDay, have, need, daysLeft;
  bool get done => have >= need;
}

Recovery? recoveryChallenge(DayView v) {
  final b = v.master.lastBreakDay;
  if (b == null) return null;
  final have = [for (var d = b + 1; d <= b + 5; d++) d].where((d) => d <= v.today && v.showedUpDays.contains(d)).length;
  final left = (b + 5 - v.today).clamp(0, 5);
  final r = Recovery(b, have, 3, left);
  return r.done || left > 0 ? r : null;
}

List<(String, int)> recoveryXp(DayView v) {
  final r = recoveryChallenge(v);
  return r != null && r.done ? [('Recovery challenge done', 100)] : const [];
}

/// When the "still there" nudge rings. After 14 days of use it moves to the
/// hour you actually get the most done, never inside the sleep window.
int nudgeMinute(DayView v) {
  final first = v.type(Ev.sessionDone).firstOrNull?.day;
  final peak = first != null && v.today - first >= 14 ? peakHour(v) : null;
  if (peak == null) return (v.cueMinute + 30) % 1440;
  return (peak * 60).clamp(4 * 60, 23 * 60 + 59);
}
