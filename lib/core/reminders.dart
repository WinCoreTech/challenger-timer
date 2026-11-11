/// Daily reminders handed to the native scheduler. Pure Dart.
library;

import 'engine.dart';
import 'events.dart';
import 'tools.dart';

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
  return out;
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

  add(0, 0, 0, '', ''); // feature 0 never exists: keeps the helper in use until batches add entries
  return out;
}

bool hasPlanFor(DayView v, int day) => v.type(Ev.planSet).any((e) => e.get<int>('forDay') == day);
