/// Daily reminders handed to the native scheduler. Pure Dart.
library;

import 'day.dart';
import 'deadlines.dart';
import 'engine.dart';
import 'planning.dart';
import 'events.dart';
import 'tools.dart';
import 'wellbeing.dart';

class Reminder {
  const Reminder(this.id, this.minute, this.title, this.text,
      {this.start = false, this.days = '', this.skipIfWorked = false});
  final int id;

  /// Minute of the local day, 0..1439.
  final int minute;
  final String title, text;

  /// Adds the "Start 2 min" button.
  final bool start;

  /// Seven characters of 0/1 for Monday..Sunday, or empty for every day.
  final String days;
  final bool skipIfWorked;
  Map<String, Object?> toJson() => {
        'id': id, 'minute': minute, 'title': title, 'text': text, 'start': start,
        'days': days, 'skipIfWorked': skipIfWorked,
      };
}

/// Everything that should ring today and on following days. The native side
/// applies quiet hours (455) and the daily cap (454).
List<Reminder> buildReminders(DayView v, Map<int, ToolDef> tools) {
  final out = <Reminder>[];
  for (final t in tools.values) {
    if (!t.time || !v.on(t.n)) continue;
    for (final (i, r) in v.of(t.recKind).indexed) {
      final minute = r.data['minute'];
      if (minute is! int || r.flag('done')) continue;
      final a = ((r.data['a'] as List?)?.cast<String>() ?? const <String>[]).where((s) => s.isNotEmpty).join(' → ');
      out.add(Reminder(t.n * 50 + i % 50, minute, t.title, a, start: true));
    }
  }
  out.addAll(fixedReminders(v));
  // 303: nothing is ever scheduled inside the protected sleep window.
  // 468: nothing rings during a lecture on today's timetable.
  final wd = weekdayOf(v.today);
  bool lecture(int m) => v.on(468) && classesOn(v, wd).any((c) => m >= c.integer('from') && m < c.integer('to'));
  return [for (final r in out) if (!inSleepWindow(v, r.minute) && !lecture(r.minute)) r];
}

/// Reminders that come from settings rather than from user-written entries.
/// Each later batch adds its own here, always behind its feature flag.
List<Reminder> fixedReminders(DayView v) {
  final out = <Reminder>[];
  void add(int feature, int id, int minute, String title, String text,
      {bool start = false, String days = '', bool skipIfWorked = false}) {
    if (v.on(feature) && v.kv['rem.$feature'] == '1') {
      out.add(Reminder(id, minute % 1440, title, text, start: start, days: days, skipIfWorked: skipIfWorked));
    }
  }

  // 108 Neck-level alarm: once a day at cue time while any deadline needs
  // more work than the time left allows.
  if (v.on(108)) {
    final neck = deadlines(v).where((t) => t.neckLevel).toList();
    if (neck.isNotEmpty) {
      out.add(Reminder(108, v.cueMinute, 'Deadline math',
          '"${neck.first.task.str('title')}" needs more than the time left at your usual pace. Two minutes now changes the sum.',
          start: true));
    }
  }
  add(302, 302, v.settingInt('bedHour', 23) * 60 - 45, 'Wind down', 'Bed in 45 minutes. Screens down, bag packed, tomorrow\'s first task set.');
  add(308, 308, v.settingInt('wakeHour', 7) * 60 + 20, 'Morning light', 'Ten minutes outside in daylight wakes the body clock up.');
  add(314, 314, 15 * 60, 'Caffeine cut-off', 'Last tea or coffee for today, so tonight\'s sleep is safe.');
  add(224, 2241, 13 * 60, 'Message check', 'First of two message slots today. Reply, then close them.');
  add(224, 2242, 19 * 60, 'Message check', 'Second message slot. After this, messages can wait until tomorrow.');
  add(225, 225, v.settingInt('nightHour', 23) * 60, 'Screens down', 'This is the hour you chose to stop screens. Tomorrow starts with tonight.');
  // 460: on the start-by date itself, not the due date.
  if (v.on(460)) {
    final due = deadlines(v).where((t) => t.est > 0 && t.startBy <= v.today).toList();
    if (due.isNotEmpty) {
      out.add(Reminder(460, v.cueMinute + 5, 'Start-by date reached', '"${due.first.task.str('title')}" has to start today to finish calmly.', start: true));
    }
  }
  // 453: gentle nudge half an hour after the cue, before the 9 pm rescue.
  if (v.on(453)) out.add(Reminder(453, (v.cueMinute + 30) % 1440, 'Still there', v.nextStep, start: true, skipIfWorked: true));
  // 456: the streak is alive and today is still open at 6 pm.
  if (v.on(456) && v.master.current > 0) {
    out.add(Reminder(456, 18 * 60, 'Streak still open today', '${v.master.current} days so far. Two minutes keeps it.', start: true, skipIfWorked: true));
  }
  // 457 and 458: one line in the morning, one in the evening.
  if (v.on(457) && v.kv['rem.457'] == '1') out.add(Reminder(457, v.settingInt('wakeHour', 7) * 60 + 30, 'Today', 'First step: ${v.nextStep}'));
  if (v.on(458) && v.kv['rem.458'] == '1') {
    out.add(Reminder(458, 21 * 60 + 30, 'Today in one line',
        v.workedToday ? '${v.sessionsToday} sessions, ${v.minutesToday} minutes. Done is done.' : 'Nothing logged yet. The day ends at ${hhmm(v.dayEndHour * 60)}.'));
  }
  // 459: only while tomorrow has no first task.
  if (v.on(459) && v.tomorrowPlan == null) {
    out.add(const Reminder(459, 21 * 60, 'Tomorrow', 'Set tomorrow\'s first task before 10 pm. It takes one line.'));
  }
  // 465: one of your own encouraging lines, a different one each day.
  if (v.on(465)) {
    final lines = v.of('t465').map((r) => r.str('text')).where((t) => t.isNotEmpty).toList();
    if (lines.isNotEmpty) out.add(Reminder(465, 16 * 60, 'From past you', lines[v.today % lines.length]));
  }
  // 473: Sunday evening, the week ahead.
  if (v.on(473)) {
    final n = deadlines(v).where((t) => t.due > v.today && t.due <= v.today + 7).length;
    out.add(Reminder(473, 18 * 60, 'The week ahead', n == 0 ? 'No due dates this week. Pick one thing to move forward.' : '$n due this week. Open Plan for the first one.', days: '0000001'));
  }
  return out;
}

bool hasPlanFor(DayView v, int day) => v.type(Ev.planSet).any((e) => e.get<int>('forDay') == day);
