/// Stats ranges and figures (reference spec 5.8). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'settings.dart';

enum RangeKind { allTime, year, month, last30, week, last7, day, custom }

const rangeNames = {
  RangeKind.allTime: 'All-time', RangeKind.year: 'Year by year', RangeKind.month: 'Month by month',
  RangeKind.last30: 'Last 30 days', RangeKind.week: 'Week by week', RangeKind.last7: 'Last 7 days',
  RangeKind.day: 'Day by day', RangeKind.custom: 'User defined',
};

/// Kinds that can step back and forward one period at a time.
bool steppable(RangeKind k) => const {RangeKind.year, RangeKind.month, RangeKind.week, RangeKind.day}.contains(k);

/// Inclusive first and last logical day of a range. [step] is 0 for the
/// current period, -1 for the one before, and so on.
(int from, int to) rangeDays(DayView v, RangeKind kind, {int step = 0, int? customFrom, int? customTo}) {
  final t = dateOfDay(v.today);
  switch (kind) {
    case RangeKind.allTime:
      final first = v.events.isEmpty ? v.today : v.events.map((e) => e.day).reduce((a, b) => a < b ? a : b);
      return (first, v.today);
    case RangeKind.year:
      return (dayOfDate(t.year + step, 1, 1), dayOfDate(t.year + step, 12, 31));
    case RangeKind.month:
      return (dayOfDate(t.year, t.month + step, 1), dayOfDate(t.year, t.month + step + 1, 0));
    case RangeKind.last30:
      return (v.today - 29, v.today);
    case RangeKind.week:
      final startsOn = v.prefInt(S.weekStartsOn).clamp(1, 7);
      final back = (weekdayOf(v.today) - startsOn) % 7;
      final from = v.today - back + step * 7;
      return (from, from + 6);
    case RangeKind.last7:
      return (v.today - 6, v.today);
    case RangeKind.day:
      return (v.today + step, v.today + step);
    case RangeKind.custom:
      final a = customFrom ?? v.today, b = customTo ?? v.today;
      return a <= b ? (a, b) : (b, a);
  }
}

String rangeLabel(RangeKind kind, int from, int to) => switch (kind) {
      RangeKind.year => '${dateOfDay(from).year}',
      RangeKind.month => dayLabel(from).substring(dayLabel(from).indexOf(' ') + 1),
      RangeKind.day => dayLabel(from),
      _ => '${dayLabel(from)} to ${dayLabel(to)}',
    };

class RangeStats {
  RangeStats(this.from, this.to, this.minutes, this.sessions, this.activeDays, this.countedDays, this.byProject,
      this.byWeekday, this.byHour, this.longestDay, this.longestDayMinutes, this.drifts);
  final int from, to, minutes, sessions;

  /// Days in range with a qualifying session, and days that count (rest
  /// days and days after today are excluded).
  final int activeDays, countedDays;
  final List<(String name, int minutes)> byProject;
  final List<int> byWeekday; // index 1..7
  final List<int> byHour; // index 0..23
  final int? longestDay;
  final int longestDayMinutes, drifts;

  bool get empty => sessions == 0;
  int get consistency => countedDays == 0 ? 0 : (activeDays * 100 / countedDays).round();
  int get averageSession => sessions == 0 ? 0 : (minutes / sessions).round();
  double get sessionsPerDay => countedDays == 0 ? 0 : sessions / countedDays;
}

RangeStats rangeStats(DayView v, int from, int to) {
  final per = <int, int>{}, proj = <String, int>{};
  final wd = List.filled(8, 0), hr = List.filled(24, 0);
  var minutes = 0, sessions = 0;
  for (final e in v.type(Ev.sessionDone)) {
    if (e.day < from || e.day > to) continue;
    final m = (e.get<num>('minutes') ?? 0).toInt();
    minutes += m;
    sessions++;
    per[e.day] = (per[e.day] ?? 0) + m;
    wd[weekdayOf(e.day)] += m;
    hr[e.moment.hour] += m;
    final name = v.rec(e.get<String>('projectId'))?.str('name') ?? 'No project';
    proj[name] = (proj[name] ?? 0) + m;
  }
  final end = to > v.today ? v.today : to;
  var counted = 0;
  for (var d = from; d <= end; d++) {
    if (!v.restWeekdays.contains(weekdayOf(d))) counted++;
  }
  final best = per.entries.fold<MapEntry<int, int>?>(null, (a, b) => a == null || b.value > a.value ? b : a);
  return RangeStats(
      from, to, minutes, sessions, per.length, counted,
      [for (final e in proj.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2)),
      wd, hr, best?.key, best?.value ?? 0,
      v.type(Ev.tool).where((e) => e.get<int>('n') == 92 && e.day >= from && e.day <= to).length);
}
