/// Student mode (features 401 to 425). Pure Dart.
library;

import 'engine.dart';
import 'events.dart';

/// 404: review gaps in days after each successful recall.
const reviewGaps = [1, 3, 7, 21];

/// 404/405: the card after a review. Correct moves one step up the ladder,
/// a miss sends it back to tomorrow.
Map<String, Object?> reviewed(Rec card, int today, {required bool correct}) {
  final step = correct ? (card.integer('step') + 1).clamp(1, reviewGaps.length) : 0;
  return {'step': step, 'next': today + (correct ? reviewGaps[step - 1] : 1), 'reviews': card.integer('reviews') + 1};
}

List<Rec> dueCards(DayView v) => v.of('card').where((c) => c.integer('next') <= v.today).toList();

/// 410: spreads [units] across [days] as evenly as possible, earliest first.
List<List<String>> examPlan(List<String> units, int days) {
  if (days < 1) days = 1;
  final plan = List.generate(days, (_) => <String>[]);
  for (final (i, u) in units.indexed) {
    plan[(i * days / units.length).floor()].add(u);
  }
  return plan;
}

/// 414: attendance percent and how many classes can still be missed while
/// staying at or above [floor] percent (negative = classes needed in a row).
(int percent, int canMiss) attendance(int present, int total, {int floor = 75}) {
  if (total == 0) return (100, 0);
  final pct = (present * 100 / total).floor();
  if (pct >= floor) return (pct, (present * 100 / floor - total).floor());
  // Classes to attend in a row to get back to the floor.
  final need = ((floor * total - 100 * present) / (100 - floor)).ceil();
  return (pct, -need);
}

/// 418: minutes per project.
List<(String, int)> timeByProject(DayView v) {
  final m = <String, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    final name = v.rec(e.get<String>('projectId'))?.str('name') ?? 'No project';
    m[name] = (m[name] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
  }
  return [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
}
