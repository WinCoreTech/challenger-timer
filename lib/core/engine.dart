/// Everything the screens show, computed from the event log for one moment.
/// Pure Dart. Build a new [DayView] whenever the log or the clock changes.
library;

import 'dart:convert';
import 'day.dart';
import 'events.dart';
import 'extras.dart';
import 'flags.dart';
import 'rules.dart';
import 'streak_engine.dart';

abstract final class K {
  static const name = 'name';
  static const dayEndHour = 'dayEndHour';
  static const cueMinute = 'cueMinute';
  static const buddyName = 'buddyName';
  static const buddyPhone = 'buddyPhone';
  static const blockedApps = 'blockedApps';
  static const active = 'active';
  static const pendingProof = 'pendingProof';
  static const lastProject = 'lastProject';
  static const simpleMode = 'simpleMode';
  static const swBlock = 'sw.block';
  static const swCue = 'sw.cue';
  static const swBuddy = 'sw.buddy';
  static const swRescue = 'sw.rescue';
  static const swLock = 'sw.lock';
  static const swBonus = 'sw.bonus';
  static const switches = [swBlock, swCue, swBuddy, swRescue, swLock, swBonus];

  /// Force-stack parts that are on unless the user switches them off.
  static const defaultOn = {swCue, swRescue, swLock, swBonus};
}

class ActiveSession {
  const ActiveSession(this.sid, this.startMs, this.minutes, this.projectId, this.title, this.source);
  factory ActiveSession.parse(String s) {
    final j = jsonDecode(s) as Map;
    return ActiveSession(j['sid'] as String, j['startMs'] as int, j['minutes'] as int,
        j['projectId'] as String?, j['title'] as String? ?? '', j['source'] as String? ?? 'app');
  }
  final String sid;
  final int startMs;
  final int minutes;
  final String? projectId;
  final String title;
  final String source;
  int get endMs => startMs + minutes * msPerMinute;
  int remainingMs(int nowMs) => (endMs - nowMs).clamp(0, minutes * msPerMinute);
  String encode() => jsonEncode({
        'sid': sid, 'startMs': startMs, 'minutes': minutes, 'projectId': projectId,
        'title': title, 'source': source
      });
}

class DayView {
  DayView({required this.events, required this.recs, required this.kv, required this.now, required this.ranks, Catalog? catalog})
      : catalog = catalog ?? Catalog.empty;

  final List<Event> events;
  final List<Rec> recs;
  final Map<String, String> kv;
  final Moment now;
  final List<Rank> ranks;
  final Catalog catalog;

  // ---- settings
  int get dayEndHour => int.tryParse(kv[K.dayEndHour] ?? '') ?? 3;
  int get cueMinute => int.tryParse(kv[K.cueMinute] ?? '') ?? 9 * 60;
  String get name => kv[K.name] ?? '';
  bool get onboarded => events.any((e) => e.type == Ev.onboarded);
  DelayedSwitch sw(String key) => DelayedSwitch.parse(kv[key], or: K.defaultOn.contains(key));
  bool isOn(String key) => sw(key).effective(now.ms);
  List<String> get blockedApps =>
      kv[K.blockedApps] == null ? const [] : (jsonDecode(kv[K.blockedApps]!) as List).cast<String>();

  late final int today = now.day(dayEndHour);

  // ---- feature flags
  /// Simple mode hides everything outside Version 1.
  bool get simpleMode => kv[K.simpleMode] == '1';

  /// True when feature [n] is switched on, built and unlocked by rank.
  bool on(int n) => featureLive(catalog, n, kv: kv, rankIndex: rank.index, simpleMode: simpleMode);
  /// Flag check without the rank gate. Used by XP rules, which must not
  /// depend on rank (rank depends on XP).
  bool flagOn(int n) => featureLive(catalog, n, kv: kv, rankIndex: 1 << 20, simpleMode: simpleMode);
  String setting(String key, [String or = '']) => kv[key] ?? or;
  int settingInt(String key, int or) => int.tryParse(kv[key] ?? '') ?? or;

  /// Feature 15: on a declared rough day the door shrinks to one minute.
  bool get badDay => on(15) && kv['badDay'] == '$today';
  int get doorMinutes => badDay ? 1 : 2;

  // ---- records
  List<Rec> of(String kind) => recs.where((r) => r.kind == kind).toList()
    ..sort((a, b) => a.created.compareTo(b.created));
  late final List<Rec> allHabits = of(Kind.habit).where((h) => !h.flag('archived')).toList();

  /// Active habits. Graduated ones (feature 50) move to "maintained".
  late final List<Rec> habits = allHabits.where((h) => !h.flag('maintained')).toList();
  late final List<Rec> maintained = allHabits.where((h) => h.flag('maintained')).toList();
  late final List<Rec> projects = of(Kind.project).where((p) => !p.flag('archived')).toList();
  late final List<Rec> proofs = of(Kind.proof).reversed.toList();
  List<Rec> tasksOf(String projectId) =>
      of(Kind.task).where((t) => t.str('projectId') == projectId).toList();
  Rec? rec(String? id) {
    for (final r in recs) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ---- sessions
  Iterable<Event> type(String t) => events.where((e) => e.type == t);
  late final Set<int> sessionDays = {for (final e in type(Ev.sessionDone)) e.day};
  late final int sessionsToday = type(Ev.sessionDone).where((e) => e.day == today).length;
  late final int minutesToday = type(Ev.sessionDone)
      .where((e) => e.day == today)
      .fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  late final int starts = type(Ev.sessionStart).length;
  bool get workedToday => sessionsToday > 0;
  ActiveSession? get active => kv[K.active] == null ? null : ActiveSession.parse(kv[K.active]!);
  Map<String, Object?>? get pendingProof =>
      kv[K.pendingProof] == null ? null : (jsonDecode(kv[K.pendingProof]!) as Map).cast<String, Object?>();

  // ---- streaks
  /// Master streak: any finished session or any habit tick.
  late final Set<int> showedUpDays = {
    ...sessionDays,
    for (final e in type(Ev.habitTick)) e.day
  };
  /// Feature 48: weekdays that never count as a miss.
  Set<int> get restWeekdays => flagOn(48)
      ? {for (final c in (kv['restDays'] ?? '').split('')) if (int.tryParse(c) != null) int.parse(c)}
      : const {};
  late final StreakRules streakRules = StreakRules(restWeekdays: restWeekdays);
  late final StreakResult master = computeStreak(showedUpDays, today, rules: streakRules);
  Set<int> habitDays(String habitId) =>
      {for (final e in type(Ev.habitTick)) if (e.get<String>('habitId') == habitId) e.day};
  StreakResult habitStreak(String habitId) => computeStreak(habitDays(habitId), today, rules: streakRules);
  bool tickedToday(String habitId) => habitDays(habitId).contains(today);

  // ---- XP, rank, bonus
  late final XpBreakdown xp = computeXp(events, today, bonusOn: isOn(K.swBonus), stackBonus: flagOn(43));

  /// Feature XP on top of the base rules, as (label, amount) lines.
  late final List<(String, int)> xpExtras = featureXp(this);
  late final int xpTotal = () {
    final t = xp.total + xpExtras.fold<int>(0, (a, e) => a + e.$2);
    return t < 0 ? 0 : t;
  }();
  late final RankView rank = rankFor(xpTotal, ranks);

  /// Today's 100 XP: held until the first session, then kept for good.
  bool get bonusAtRisk => isOn(K.swBonus) && !workedToday;
  double get dayLeft => dayFractionLeft(now, dayEndHour);
  int get msToDayEnd => dayEndWallMs(today, dayEndHour) - now.wallMs;

  // ---- plan
  Plan? get todayPlan => planFor(events, today);
  Plan? get tomorrowPlan => planFor(events, today + 1);

  /// Tomorrow's first task can be edited unless it is already set and we are
  /// inside the 10 pm lock window (and the lock has not been switched off).
  bool get planLocked => tomorrowPlan != null && isOn(K.swLock) && inLockWindow(now, dayEndHour);

  /// The one card on Home: today's locked first task until the first session,
  /// then the latest parking note.
  String get nextStep {
    final p = todayPlan;
    if (p != null && !workedToday && p.task.isNotEmpty) return p.task;
    for (final e in events.reversed) {
      if (e.type == Ev.parkingNote && (e.get<String>('text') ?? '').isNotEmpty) {
        return e.get<String>('text')!;
      }
      if (e.type == Ev.planSet && e.get<int>('forDay') == today && workedToday) break;
    }
    return p != null && p.task.isNotEmpty ? p.task : defaultStep;
  }

  // ---- achievements
  late final Map<String, int> metrics = () {
    final perDay = <int, int>{};
    var longestSession = 0, minutes = 0;
    for (final e in type(Ev.sessionDone)) {
      perDay[e.day] = (perDay[e.day] ?? 0) + 1;
      final m = (e.get<num>('minutes') ?? 0).toInt();
      minutes += m;
      if (m > longestSession) longestSession = m;
    }
    return {
      'starts': starts,
      'sessions': type(Ev.sessionDone).length,
      'minutes': minutes,
      'proofs': type(Ev.proof).length,
      'photos': type(Ev.proof).where((e) => e.get<String>('kind') == 'photo').length,
      'links': type(Ev.proof).where((e) => e.get<String>('kind') == 'link').length,
      'habitTicks': type(Ev.habitTick).length,
      'streak': master.current,
      'longest': master.longest,
      'totalDays': master.totalDays,
      'comebacks': master.comebacks,
      'plans': type(Ev.planSet).length,
      'longestSession': longestSession,
      'bestDaySessions': perDay.values.fold(0, (a, b) => a > b ? a : b),
      'xp': xpTotal,
    };
  }();

  String get buddyText =>
      buddyMessage(name: name, sessions: sessionsToday, minutes: minutesToday, streak: master.current);
}
