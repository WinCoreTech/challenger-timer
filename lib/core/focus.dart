/// Focus modes, emergency pause and drift causes (plan v2, sections 6.2, 6.3).
/// Pure Dart.
library;

import 'engine.dart';
import 'events.dart';
import 'extras.dart';

class FocusMode {
  const FocusMode(this.id, this.name, this.pauses, this.graceMs, this.xp, this.about);
  final String id, name, about;

  /// Pauses allowed per session (each needs a reason).
  final int pauses;

  /// How long you may be out of the app before the session fails.
  final int graceMs;

  /// XP multiplier for a finished session.
  final double xp;
}

const focusModes = {
  'normal': FocusMode('normal', 'Normal', 2, 10000, 1, 'Two pauses, each with a reason. Ten seconds of grace if you leave the app.'),
  'hyper': FocusMode('hyper', 'Hyper', 0, 10000, 1.5, 'No pauses. Do Not Disturb if allowed. Ten seconds of grace. 1.5x XP.'),
  'beast': FocusMode('beast', 'Beast', 0, 0, 2, 'No pauses and no grace. A one-line goal before, proof after. 2x XP. Failing costs 10 minutes of rank score.'),
};

FocusMode modeOf(String? id) => focusModes[id] ?? focusModes['normal']!;

/// Minutes of rank score a failed Beast session costs that day.
const int beastPenaltyMinutes = 10;

const driftCauses = ['phone', 'thought', 'tired', 'noise', 'hunger', 'other'];
const int driftCauseTool = 920;
const int emergencyPauseMs = 10 * 60000;

/// One emergency pause a day.
bool emergencyUsedToday(DayView v) => v.type(Ev.sessionPause).any((e) => e.day == v.today && e.payload['emergency'] == true);

/// Drift causes logged in [fromDay]..[toDay], most common first.
List<(String, int)> topDriftCauses(DayView v, {int? fromDay, int? toDay}) {
  final m = <String, int>{};
  for (final e in v.type(Ev.tool)) {
    if (e.get<int>('n') != driftCauseTool) continue;
    if ((fromDay != null && e.day < fromDay) || (toDay != null && e.day > toDay)) continue;
    final c = e.get<String>('cause') ?? 'other';
    m[c] = (m[c] ?? 0) + 1;
  }
  return [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Drifts per hour of day (0..23).
List<int> driftsByHour(DayView v) {
  final h = List.filled(24, 0);
  for (final e in v.type(Ev.tool)) {
    if (e.get<int>('n') == 92) h[e.moment.hour]++;
  }
  return h;
}

/// Extra XP from Hyper and Beast sessions: (multiplier - 1) x the session's base XP.
List<(String, int)> focusXp(DayView v) {
  var x = 0.0;
  for (final e in v.type(Ev.sessionDone)) {
    final m = modeOf(e.get<String>('mode'));
    if (m.xp > 1) x += (m.xp - 1) * (50 + 2 * (e.get<num>('minutes') ?? 0));
  }
  return x >= 1 ? [('Focus mode bonus', x.round())] : const [];
}

/// Failed Beast sessions per day, for the rank-score penalty.
Map<int, int> beastFails(DayView v) {
  final m = <int, int>{};
  for (final e in v.type(Ev.sessionAbandon)) {
    if (e.get<String>('mode') == 'beast' && e.get<String>('reason') == 'left') m[e.day] = (m[e.day] ?? 0) + 1;
  }
  return m;
}

/// Focus score of the last finished session, if any.
int? lastFocusScore(DayView v) {
  final e = v.type(Ev.sessionDone).lastOrNull;
  return e == null ? null : focusScore(v, e.get<String>('sid') ?? '');
}
