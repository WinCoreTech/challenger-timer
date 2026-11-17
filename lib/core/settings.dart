/// Every setting from reference spec 5.11 with its default, plus effective
/// session lengths (project overrides global). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';

abstract final class S {
  static const workMin = 'workSessionMinutes';
  static const shortBreakMin = 'shortBreakMinutes';
  static const longBreakMin = 'longBreakMinutes';
  static const longBreakEvery = 'longBreakEvery';
  static const almostSound = 'almostCompleteSound';
  static const overtimeStep = 'overtimeStep';
  static const weekStartsOn = 'weekStartsOn';
  static const sortProjectsBy = 'sortProjectsBy';
  static const enableNotes = 'enableNotes';
  static const casualMode = 'casualMode';
  static const notificationSound = 'notificationSound';
  static const soundChannel = 'soundChannel';
  static const completeVolume = 'completeVolume';
  static const tickingVolume = 'tickingVolume';
  static const otherVolume = 'otherSoundsVolume';
  static const keepScreenOn = 'keepScreenOn';
  static const screenDuringCountdown = 'screenDuringCountdown';
  static const screenOnComplete = 'turnOnScreenOnComplete';
  static const robustCountdown = 'robustCountdown';
  static const language = 'language';
  static const stayAway = 'stayAwayMode';
  static const focusMode = 'focusMode';
  static const dailyLimitHours = 'dailyLimitHours';
  static const remindersPerDay = 'remindersPerDay';
  static const theme = 'theme';
  static const muted = 'muted';
  static const hideLateWarning = 'hideLateWarning';
  static const lastBackup = 'lastExport';
  static const loop = 'loopSessions';
  static const showCount = 'workShowsCount';

  /// Defaults for every key above that has one.
  static const defaults = <String, String>{
    workMin: '25', shortBreakMin: '5', longBreakMin: '15', longBreakEvery: '5',
    almostSound: '0', overtimeStep: '0', weekStartsOn: '1', sortProjectsBy: 'activity',
    enableNotes: '1', casualMode: '0', notificationSound: 'default', soundChannel: 'media',
    completeVolume: '50', tickingVolume: '0', otherVolume: '50', keepScreenOn: '1',
    screenDuringCountdown: 'device', screenOnComplete: '1', robustCountdown: '0',
    language: 'device', stayAway: '0', focusMode: 'normal', dailyLimitHours: '6',
    remindersPerDay: '5', theme: 'dark', muted: '0', loop: '0', showCount: '0',
  };
}

extension SettingsView on DayView {
  String pref(String key) => kv[key] ?? S.defaults[key] ?? '';
  int prefInt(String key) => int.tryParse(pref(key)) ?? 0;
  bool prefOn(String key) => pref(key) == '1';

  /// Work length for [projectId]: the project's own value, else its parent's,
  /// else the global setting.
  int workMinutes([String? projectId]) => _override(projectId, 'workMin') ?? prefInt(S.workMin);
  int shortBreakMinutes([String? projectId]) => _override(projectId, 'shortBreakMin') ?? prefInt(S.shortBreakMin);
  int longBreakMinutes([String? projectId]) => _override(projectId, 'longBreakMin') ?? prefInt(S.longBreakMin);

  int? _override(String? projectId, String field) {
    var p = rec(projectId);
    for (var hops = 0; p != null && hops < 10; hops++) {
      if (p.integer(field) > 0) return p.integer(field);
      p = rec(p.str('parentId'));
    }
    return null;
  }

  /// Sessions finished in a row with no gap of 3 hours or more between them.
  int sessionsSinceLongGap() {
    var n = 0;
    int? next;
    for (final e in type(Ev.sessionDone).toList().reversed) {
      if (next != null && next - e.ts >= 3 * msPerHour) break;
      if (next == null && now.ms - e.ts >= 3 * msPerHour) break;
      n++;
      next = e.ts;
    }
    return n;
  }

  /// A late finish was recorded and the warning has not been hidden since.
  bool get lateWarning => type(Ev.lateFinish).isNotEmpty && pref(S.hideLateWarning) != '1';

  /// The break that follows the session just finished: long on every Nth.
  bool nextBreakIsLong() {
    final every = prefInt(S.longBreakEvery);
    final n = sessionsSinceLongGap();
    return every > 0 && n > 0 && n % every == 0;
  }
}
