/// Daily reminders handed to the native scheduler. Pure Dart.
library;

import 'deadlines.dart';
import 'engine.dart';
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
  return [for (final r in out) if (!inSleepWindow(v, r.minute)) r];
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
  add(460, 460, v.cueMinute, 'Start-by date', 'A task reaches its start-by date today. Open Plan to see which.', start: true);
  return out;
}

bool hasPlanFor(DayView v, int day) => v.type(Ev.planSet).any((e) => e.get<int>('forDay') == day);
