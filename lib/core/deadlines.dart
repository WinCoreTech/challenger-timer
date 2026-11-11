/// Deadline tools (features 101 to 125). Pure Dart. A deadline is a task with
/// a due day ('due'), an estimate in minutes ('est') and a postpone count.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';

const int sessionSize = 25;

/// Minutes of finished sessions started from this task.
int taskMinutes(DayView v, String taskId) => v
    .type(Ev.sessionDone)
    .where((e) => e.get<String>('taskId') == taskId)
    .fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());

/// Average minutes per day over the last 14 days, never below one session,
/// so plans stay realistic (also used by feature 181).
int dailyCapacity(DayView v) {
  final m = v
      .type(Ev.sessionDone)
      .where((e) => e.day > v.today - 14 && e.day <= v.today)
      .fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  final avg = (m / 14).round();
  return avg < sessionSize ? sessionSize : avg;
}

class TaskMath {
  TaskMath(this.v, this.task);
  final DayView v;
  final Rec task;

  bool get hasDue => task.data['due'] is int;
  int get due => task.integer('due');
  int get created => dayOf(task.created, v.now.offsetMin, v.dayEndHour);
  int get est => task.integer('est');
  int get done => taskMinutes(v, task.id);
  int get left => (est - done).clamp(0, 1 << 30);
  int get postponed => task.integer('postponed');

  /// 101: your own due date is 48 hours before the real one.
  int get fakeDue => due - 2;

  /// Whole days left before the personal due date, at least 1.
  int get daysLeft => (fakeDue - v.today).clamp(1, 100000);

  /// 102: work left, counted in 25-minute sessions.
  int get sessionsLeft => (left / sessionSize).ceil();

  /// 117: minutes per day from now to the personal due date.
  int get quota => (left / daysLeft).ceil();

  /// 118: what the quota was on the day the task was created.
  int get firstQuota => (est / (fakeDue - created).clamp(1, 100000)).ceil();

  /// 125: latest day to start and still finish at your usual pace.
  int get startBy => fakeDue - (left / dailyCapacity(v)).ceil();

  /// 106: minutes per day if you start today and if you wait [wait] days.
  (int today, int later) panic({int wait = 5}) =>
      (quota, (left / (daysLeft - wait).clamp(1, 100000)).ceil());

  /// 107: share of work done and share of time gone, both 0..1.
  (double work, double time) get pace {
    final span = (fakeDue - created).clamp(1, 100000);
    return (est == 0 ? 0 : (done / est).clamp(0.0, 1.0), ((v.today - created) / span).clamp(0.0, 1.0));
  }

  /// 108: more work left than realistic time left.
  bool get neckLevel => hasDue && !task.flag('done') && est > 0 && left > dailyCapacity(v) * daysLeft;

  /// 119: minutes behind the even pace.
  int get debt {
    if (!hasDue || est == 0 || task.flag('done')) return 0;
    final expected = (est * pace.$2).round();
    return (expected - done).clamp(0, est);
  }

  /// 103 and 113: dated milestones between now and the personal due date.
  List<(int day, String label)> get milestones {
    if (!hasDue) return const [];
    final start = created, end = fakeDue;
    int at(double f) => start + ((end - start) * f).round();
    return [
      (at(0.25), 'First quarter done'),
      (at(0.5), 'Draft zero: a complete ugly version'),
      (at(0.75), 'Fixed the worst parts'),
      (end, 'Finished (your own due date)'),
      (due, 'Real due date. Buffer, not work time.'),
    ];
  }

  /// 104: a session on this task within 24 hours of creating it.
  bool get firstTouched => v.type(Ev.sessionStart).any(
      (e) => e.get<String>('taskId') == task.id && e.ts - task.created <= msPerDay);
  bool get firstTouchOpen => !firstTouched && v.now.ms - task.created <= msPerDay && !task.flag('done');

  /// 105: touched on the very day it was created.
  bool get dayOne => v.type(Ev.sessionStart).any((e) => e.get<String>('taskId') == task.id && e.day == created);

  /// 112: XP multiplier for work on this task today: 3x a week early, 1x on the last day.
  double get earlyBird => hasDue ? earlyMultiplier(due - v.today) : 1;
}

double earlyMultiplier(int daysBeforeDue) => (1 + 2 * daysBeforeDue / 7).clamp(1.0, 3.0);

/// 111: bonus for finishing early that shrinks by 15 XP for each day waited.
int decayingBonus(int daysEarly) => (daysEarly * 15).clamp(0, 150);

List<TaskMath> deadlines(DayView v, {bool open = true}) => [
      for (final t in v.of(Kind.task))
        if (t.data['due'] is int && (!open || !t.flag('done'))) TaskMath(v, t)
    ]..sort((a, b) => a.due.compareTo(b.due));

/// 115 and 116: due dates per week for the next [weeks] weeks.
List<({int week, int count, int minutes, bool collision})> loadCalendar(DayView v, {int weeks = 8}) {
  final now = weekOf(v.today);
  return [
    for (var w = now; w < now + weeks; w++)
      () {
        final ts = deadlines(v).where((t) => weekOf(t.due) == w).toList();
        return (week: w, count: ts.length, minutes: ts.fold(0, (a, t) => a + t.left), collision: ts.length >= 3);
      }()
  ];
}

/// First day (a Monday) of a week index from [weekOf].
int weekStart(int week) => week * 7 - 3;

/// 114: finished tasks with a due date, and how many beat it by 12 hours.
(int early, int total) submissionBuffer(DayView v) {
  var early = 0, total = 0;
  for (final t in v.of(Kind.task)) {
    if (!t.flag('done') || t.data['due'] is! int || t.data['doneTs'] is! int) continue;
    total++;
    final dueEnd = dayEndWallMs(t.integer('due'), v.dayEndHour);
    if (dueEnd - (t.integer('doneTs') + v.now.offsetMin * msPerMinute) >= 12 * msPerHour) early++;
  }
  return (early, total);
}

/// XP from deadline features.
List<(String, int)> deadlineXp(DayView v) {
  final out = <(String, int)>[];
  final tasks = {for (final t in v.of(Kind.task)) t.id: t};
  if (v.flagOn(111)) {
    var x = 0;
    for (final t in tasks.values) {
      if (t.flag('done') && t.data['due'] is int && t.data['doneTs'] is int) {
        final doneDay = dayOf(t.integer('doneTs'), v.now.offsetMin, v.dayEndHour);
        x += decayingBonus(t.integer('due') - doneDay);
      }
    }
    if (x > 0) out.add(('Early-finish bonus', x));
  }
  if (v.flagOn(112)) {
    var x = 0.0;
    for (final e in v.type(Ev.sessionDone)) {
      final t = tasks[e.get<String>('taskId')];
      if (t == null || t.data['due'] is! int) continue;
      x += (earlyMultiplier(t.integer('due') - e.day) - 1) * (e.get<num>('minutes') ?? 0) * 2;
    }
    if (x >= 1) out.add(('Early-bird multiplier', x.round()));
  }
  return out;
}
