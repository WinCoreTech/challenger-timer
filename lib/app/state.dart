import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/flags.dart';
import '../core/reminders.dart';
import '../core/rules.dart';
import '../core/tools.dart';
import '../data/store.dart';
import 'native.dart';

/// In-memory copy of the whole database. The data set is small (a few rows per
/// day), so every screen derives what it needs from this snapshot.
class AppData {
  const AppData(this.events, this.recs, this.kv);
  static const empty = AppData([], [], {});
  final List<Event> events;
  final List<Rec> recs;
  final Map<String, String> kv;
}

final storeProvider = Provider<Store>((ref) => throw UnimplementedError('override in main'));
final nativeProvider = Provider<Native>((ref) => FakeNative());
final clockProvider = Provider<Clock>((ref) => systemClock);
final ranksProvider = Provider<List<Rank>>((ref) => const [Rank('Professional Postponer', 0, '')]);
final catalogProvider = Provider<Catalog>((ref) => Catalog.empty);
final toolsProvider = Provider<Map<int, ToolDef>>((ref) => const {});
final achievementsProvider = Provider<List<Achievement>>((ref) => const []);

/// Bumped by a timer so time-dependent views (bonus drain, locks) refresh.
class Tick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final tickProvider = NotifierProvider<Tick, int>(Tick.new);
final appProvider = NotifierProvider<App, AppData>(App.new);

final viewProvider = Provider<DayView>((ref) {
  ref.watch(tickProvider);
  final d = ref.watch(appProvider);
  return DayView(
      events: d.events, recs: d.recs, kv: d.kv, now: ref.watch(clockProvider)(), ranks: ref.watch(ranksProvider),
      catalog: ref.watch(catalogProvider));
});

class App extends Notifier<AppData> {
  @override
  AppData build() => AppData.empty;

  Store get _store => ref.read(storeProvider);
  Native get native => ref.read(nativeProvider);
  Moment get _now => ref.read(clockProvider)();
  DayView get view => DayView(
      events: state.events, recs: state.recs, kv: state.kv, now: _now, ranks: ref.read(ranksProvider),
      catalog: ref.read(catalogProvider));
  int _seq = 0;
  String newId() => '${_now.ms.toRadixString(36)}-${_seq++}';

  Future<void> load() async {
    state = AppData(await _store.allEvents(), await _store.allRecs(), await _store.allKv());
    await _settleSwitches();
    await syncNative();
  }

  // ---- primitives
  Future<Event> log(String type, [Map<String, Object?> payload = const {}, Moment? at]) async {
    final e = await _store.addEvent(Event.at(at ?? _now, view.dayEndHour, type, payload));
    state = AppData([...state.events, e], state.recs, state.kv);
    return e;
  }

  Future<void> setKv(String key, String? value) async {
    await _store.setKv(key, value);
    final kv = Map.of(state.kv);
    value == null ? kv.remove(key) : kv[key] = value;
    state = AppData(state.events, state.recs, kv);
  }

  Future<Rec> putRec(Rec r) async {
    await _store.putRec(r);
    state = AppData(state.events, [...state.recs.where((x) => x.id != r.id), r], state.kv);
    return r;
  }

  Future<Rec> addRec(String kind, Map<String, Object?> data) =>
      putRec(Rec(id: newId(), kind: kind, created: _now.ms, data: data));

  Future<void> deleteRec(String id) async {
    await _store.deleteRec(id);
    state = AppData(state.events, state.recs.where((x) => x.id != id).toList(), state.kv);
  }

  Future<void> setSetting(String key, String value) async {
    await setKv(key, value);
    await log(Ev.setting, {'key': key, 'value': value});
    await syncNative();
  }

  // ---- sessions
  Future<void> startSession(
      {int? minutes,
      String? projectId,
      String? title,
      String source = 'app',
      int? startMs,
      bool flow = false,
      bool hard = false,
      String tag = '',
      String? chain,
      String? taskId,
      Map<String, Object?> meta = const {},
      int cycleWork = 0,
      int cycleRest = 0,
      int cycleLeft = 0}) async {
    final v = view;
    if (v.active != null) return;
    final now = _now;
    final begin = startMs ?? now.ms;
    minutes ??= v.doorMinutes;
    final pid = projectId ?? state.kv[K.lastProject];
    final s = ActiveSession(newId(), begin, flow ? 0 : minutes, pid, title ?? v.nextStep, source,
        flow: flow, hard: hard, tag: tag, chain: chain, taskId: taskId, meta: meta,
        cycleWork: cycleWork, cycleRest: cycleRest, cycleLeft: cycleLeft);
    await setKv(K.active, s.encode());
    if (pid != null) await setKv(K.lastProject, pid);
    await log(Ev.sessionStart, {
      'sid': s.sid, 'minutes': s.minutes, 'projectId': pid, 'source': source, 'title': s.title,
      if (tag.isNotEmpty) 'tag': tag, if (flow) 'flow': true, if (hard) 'hard': true, 'taskId': ?taskId, ...meta,
    }, Moment(begin, now.offsetMin));
    native.haptic();
    if (hard) await native.keepScreenOn(true);
    if (v.on(204) && v.kv['autoDnd'] == '1') await native.dnd(true);
    if (startMs == null) await native.startTimer(s.endMs, s.title);
    await syncNative();
  }

  /// Call often. If the running session (or break) has reached its end, even
  /// while the app was dead, records it at the moment it ended. Returns true
  /// if a work session was completed.
  Future<bool> completeIfDue() async {
    final s = view.active;
    final now = _now;
    if (s == null || s.paused || now.ms < s.endMs) return false;
    if (s.isBreak) {
      await _endBreak(s, now.ms - s.endMs);
      return false;
    }
    await _finish(s, s.flow ? ActiveSession.flowCapMinutes : s.minutes, Moment(s.endMs, now.offsetMin));
    // Feature 77: the next phase starts on its own, but only if we are
    // actually here. A cycle never runs by itself while the app is closed.
    if (s.cycleLeft > 0 && now.ms - s.endMs < 2 * msPerMinute) await startBreak(s.cycleRest, from: s, startMs: s.endMs);
    return true;
  }

  Future<void> _finish(ActiveSession s, int minutes, Moment at) async {
    // Linked sessions (just five more, pomodoro rounds) add to the waiting proof.
    final prior = view.pendingProof;
    final chain = s.chain ?? s.sid;
    await _quiet(s);
    final carried = prior != null && (prior['chain'] == chain || s.source == 'five_more') ? prior['minutes'] as int? ?? 0 : 0;
    await setKv(K.active, null);
    await log(Ev.sessionDone,
        {
          'sid': s.sid, 'minutes': minutes, 'projectId': s.projectId,
          if (s.tag.isNotEmpty) 'tag': s.tag, if (s.taskId != null) 'taskId': s.taskId, ...s.meta,
          if (s.pauses > 0) 'pauses': s.pauses,
        },
        at);
    await setKv(
        K.pendingProof,
        jsonEncode({
          'sid': s.sid, 'projectId': s.projectId, 'minutes': minutes + carried, 'title': s.title, 'chain': chain,
          if (s.flow) 'break': minutes ~/ 5 < 1 ? 1 : minutes ~/ 5,
        }));
    celebrate();
    await syncNative();
  }

  /// Stopping early. Two minutes or more still counts as a finished session.
  Future<void> stopSession({String reason = ''}) async {
    final s = view.active;
    if (s == null) return;
    final now = _now;
    await native.stopTimer();
    await _quiet(s);
    if (s.isBreak) {
      await setKv(K.active, null);
      return syncNative();
    }
    final elapsedMin = s.elapsedMs(now.ms) ~/ msPerMinute;
    if (elapsedMin >= view.doorMinutes.clamp(1, 2) && reason != 'left') {
      await _finish(s, elapsedMin, now);
    } else {
      await setKv(K.active, null);
      await log(Ev.sessionAbandon,
          {'sid': s.sid, 'elapsedSec': s.elapsedMs(now.ms) ~/ 1000, if (reason.isNotEmpty) 'reason': reason});
      await syncNative();
    }
  }

  Future<void> _quiet(ActiveSession s) async {
    if (s.hard) await native.keepScreenOn(false);
    if (view.on(204) && view.kv['autoDnd'] == '1') await native.dnd(false);
    if (view.kv['noise'] != null && view.kv['noise']!.isNotEmpty) await native.noise('');
  }

  Future<void> skipBreak() async {
    final b = view.active;
    if (b == null || !b.isBreak) return;
    await native.stopTimer();
    await _endBreak(b, 0);
  }

  /// A rest timer. [from] carries a pomodoro cycle forward.
  Future<void> startBreak(int minutes, {ActiveSession? from, int? startMs}) async {
    if (view.active != null) return;
    final b = ActiveSession(newId(), startMs ?? _now.ms, minutes < 1 ? 1 : minutes, from?.projectId, from?.title ?? '', 'break',
        isBreak: true,
        chain: from?.chain ?? from?.sid,
        taskId: from?.taskId,
        tag: from?.tag ?? '',
        cycleWork: from?.cycleWork ?? 0,
        cycleRest: from?.cycleRest ?? 0,
        cycleLeft: from?.cycleLeft ?? 0);
    await setKv(K.active, b.encode());
    await log(Ev.breakStart, {'minutes': b.minutes});
    await native.startTimer(b.endMs, 'Break');
  }

  Future<void> _endBreak(ActiveSession b, int lateMs) async {
    await setKv(K.active, null);
    // Feature 93: a break has a hard end. Coming back late is counted, not punished.
    if (lateMs > msPerMinute && view.on(93)) await log(Ev.tool, {'n': 93, 'over': (lateMs / msPerMinute).ceil()});
    if (b.cycleLeft > 0 && lateMs < 2 * msPerMinute) {
      await startSession(
          minutes: b.cycleWork, projectId: b.projectId, title: b.title, source: 'cycle', tag: b.tag, taskId: b.taskId,
          chain: b.chain, cycleWork: b.cycleWork, cycleRest: b.cycleRest, cycleLeft: b.cycleLeft - 1);
    } else {
      await syncNative();
    }
  }

  /// Feature 91: at most two pauses per session, each with a reason.
  Future<bool> pauseSession(String reason) async {
    final s = view.active;
    if (s == null || s.paused || s.isBreak || s.hard || s.pauses >= 2) return false;
    await setKv(K.active, s.copy(pausedAt: _now.ms, pauses: s.pauses + 1).encode());
    await log(Ev.sessionPause, {'sid': s.sid, 'reason': reason});
    await native.stopTimer();
    return true;
  }

  Future<void> resumeSession() async {
    final s = view.active;
    if (s == null || !s.paused) return;
    final r = s.copy(startMs: s.startMs + (_now.ms - s.pausedAt!), clearPause: true);
    await setKv(K.active, r.encode());
    await native.startTimer(r.endMs, r.title);
  }

  /// Feature 90: called when the app comes back. Returns true if the session
  /// was ended because the user left during hard mode.
  Future<bool> hardModeCheck(int awayMs, {required bool leftWithScreenOn}) async {
    final s = view.active;
    if (s == null || !s.hard || s.isBreak || awayMs < 10000 || !leftWithScreenOn) return false;
    await stopSession(reason: 'left');
    return true;
  }

  String? lastProofId;

  Future<void> saveProof(
      {required String type,
      required String value,
      String parkingNote = '',
      String outcome = '',
      int difficulty = 0,
      int units = 0,
      String unit = '',
      String anyway = ''}) async {
    final p = view.pendingProof;
    if (p == null) return;
    final rec = await addRec(Kind.proof, {
      'sid': p['sid'], 'projectId': p['projectId'], 'type': type, 'value': value,
      'minutes': p['minutes'], 'title': p['title'], 'day': view.today,
      if (outcome.isNotEmpty) 'outcome': outcome, if (difficulty > 0) 'difficulty': difficulty,
      if (units > 0 && unit.isNotEmpty) ...{'units': units, 'unit': unit},
      if (anyway.isNotEmpty) 'anyway': anyway,
      if (view.type(Ev.sessionDone).where((e) => e.get<String>('sid') == p['sid']).firstOrNull?.get<String>('tag') case final String t) 'tag': t,
    });
    lastProofId = rec.id;
    await log(Ev.proof, {
      'sid': p['sid'], 'recId': rec.id, 'kind': type, 'projectId': p['projectId'],
      if (outcome.isNotEmpty) 'outcome': outcome, if (difficulty > 0) 'difficulty': difficulty,
    });
    if (parkingNote.trim().isNotEmpty) {
      await log(Ev.parkingNote, {'text': parkingNote.trim(), 'projectId': p['projectId']});
    }
    await setKv(K.pendingProof, null);
    celebrate();
    await syncNative();
  }

  // ---- habits, projects, tasks, plan
  Future<void> tickHabit(String habitId, {bool tiny = false, String proof = ''}) async {
    final v = view;
    if (v.tickedToday(habitId)) return;
    // Feature 137: a proof-required habit only counts with a line of proof.
    if (v.on(137) && v.rec(habitId)?.flag('proofRequired') == true && proof.trim().isEmpty) return;
    await log(Ev.habitTick, {'habitId': habitId, if (tiny) 'tiny': true, if (proof.trim().isNotEmpty) 'proof': proof.trim()});
    celebrate();
    await syncNative();
  }

  Future<void> toggleTask(Rec task) async {
    final done = !task.flag('done');
    await putRec(task.copy({'done': done, 'doneTs': done ? _now.ms : null}));
    if (done) {
      // Feature 174: a recurring task comes back after its interval.
      final every = task.integer('every');
      if (every > 0 && view.on(174)) {
        await addRec(Kind.task, {
          ...task.data, 'done': false, 'doneTs': null, 'postponed': 0,
          if (task.data['due'] is int) 'due': task.integer('due') + every,
        });
      }
      await log(Ev.taskDone, {'taskId': task.id, if (task.flag('milestone')) 'milestone': true});
      celebrate();
    }
  }

  /// Features 120 to 122: pushing a due date needs a reason and is counted.
  Future<void> postponeTask(Rec task, int days, String reason) async {
    await putRec(task.copy({
      'due': task.integer('due') + days,
      'postponed': task.integer('postponed') + 1,
      'reasons': [...(task.data['reasons'] as List? ?? const []), reason],
    }));
    await log(Ev.tool, {'n': 120, 'taskId': task.id, 'days': days, 'reason': reason});
  }

  /// Features 192 and 193: move a task to tomorrow in one tap, counted.
  Future<void> moveToTomorrow(Rec task) async {
    await putRec(task.copy({'due': view.today + 1, 'moved': task.integer('moved') + 1}));
    await log(Ev.tool, {'n': 192, 'taskId': task.id});
  }

  /// Returns false when the plan is locked.
  Future<bool> setPlan(String task, int cueMinute) async {
    final v = view;
    if (v.planLocked) return false;
    await log(Ev.planSet, {'forDay': v.today + 1, 'task': task.trim(), 'cueMinute': cueMinute});
    await setKv(K.cueMinute, '$cueMinute');
    await syncNative();
    return true;
  }

  // ---- data-driven tools
  Future<void> toolTick(ToolDef t, int item) async {
    if (view.checked(t.n, view.today).contains(item)) return;
    await log(Ev.tool, {'n': t.n, 'item': item});
    if (view.checked(t.n, view.today).length >= t.items.length) celebrate();
  }

  // ---- delayed off switch
  Future<void> switchOn(String key) => _setSwitch(key, view.sw(key).turnOn());
  Future<void> switchRequestOff(String key) => _setSwitch(key, view.sw(key).requestOff(_now.ms));
  Future<void> switchCancelOff(String key) => _setSwitch(key, view.sw(key).cancelOff());
  Future<void> _setSwitch(String key, DelayedSwitch s) async {
    await setKv(key, s.encode());
    await log(Ev.setting, {'key': key, 'value': s.encode()});
    await syncNative();
  }

  Future<void> _settleSwitches() async {
    final v = view;
    for (final key in K.switches) {
      final s = v.sw(key);
      if (s.on && !s.effective(_now.ms)) await setKv(key, const DelayedSwitch().encode());
    }
  }

  // ---- buddy report (share-sheet fallback path runs through the UI)
  Future<bool> sendBuddySms() async {
    final v = view;
    final phone = state.kv[K.buddyPhone] ?? '';
    if (phone.isEmpty) return false;
    final ok = await native.sendSms(phone, v.buddyText);
    if (ok) await log(Ev.buddyReport, {'channel': 'sms'});
    return ok;
  }

  // ---- native
  void celebrate() {
    native.haptic(heavy: true);
    native.tone();
  }

  Future<void> syncNative() async {
    final v = view;
    await native.faceDown(v.on(206) && v.kv['faceDown'] == '1' && v.active == null);
    Map<String, Object?> sw(String k) => {'on': v.sw(k).on, 'offAt': v.sw(k).offAt ?? 0};
    final lastDone = v.sessionDays.isEmpty ? -1 : v.sessionDays.reduce((a, b) => a > b ? a : b);
    await native.sync({
      'dayEndHour': v.dayEndHour,
      'cueMinute': v.todayPlan?.cueMinute ?? v.cueMinute,
      'nextCueMinute': v.tomorrowPlan?.cueMinute ?? v.cueMinute,
      'task': v.nextStep,
      'cueTitle': v.on(452) && (v.kv['t.452'] ?? '').length > 4 ? v.single(const ToolDef(n: 452, kind: 'single', title: '', prompts: [''])).first : '',
      'tomorrowTask': v.tomorrowPlan?.task ?? '',
      'lastSessionDay': lastDone,
      'name': v.name,
      'buddyPhone': state.kv[K.buddyPhone] ?? '',
      'msgDone': v.workedToday ? v.buddyText : '',
      'msgDoneDay': v.today,
      'msgZero': buddyMessage(name: v.name, sessions: 0, minutes: 0, streak: v.master.current),
      'blockedApps': v.blockedApps,
      'block': sw(K.swBlock),
      'cue': sw(K.swCue),
      'buddy': sw(K.swBuddy),
      'rescue': sw(K.swRescue),
      'onboarded': v.onboarded,
      'streak': v.master.current,
      'chargeCue': v.on(21) && v.kv['chargeCue'] == '1',
      'blockAll': v.on(22) && v.kv['blockAll'] == '1',
      'blockInSession': v.on(201) && v.kv['blockInSession'] == '1',
      'allowApps': v.kv['allowApps'] == null ? const <String>[] : (jsonDecode(v.kv['allowApps']!) as List).cast<String>(),
      'unlockFriction': v.on(211) && v.kv['unlockFriction'] == '1',
      'scrollFrom': v.on(212) && v.settingInt('scrollHour', 0) > 0 ? v.settingInt('scrollHour', 0) * 60 : null,
      'quietFrom': v.on(455) ? v.settingInt('quietFrom', 0) : 0,
      'quietTo': v.on(455) ? v.settingInt('quietTo', 0) : 0,
      'remCap': v.on(454) ? v.settingInt('remCap', 3) : 99,
      'reminders': [for (final r in buildReminders(v, ref.read(toolsProvider))) r.toJson()],
    });
  }

  /// Picks up a "Start 2 min" tap from the alarm, a notification or the
  /// overlay. Returns the action name ('start2', 'report') or null.
  Future<String?> handleLaunchAction() async {
    final a = await native.takeLaunchAction();
    if (a == null) return null;
    if (a['action'] == 'start2') {
      await completeIfDue();
      if (!view.onboarded) return null;
      await startSession(minutes: 2, source: a['source'] as String? ?? 'alarm', startMs: a['startMs'] as int?);
    }
    return a['action'] as String?;
  }

  // ---- data ownership
  Future<void> markExported() => setKv('lastExport', '${_now.ms}');

  String exportJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'Productivity Challenger Timer',
        'exportedAt': _now.ms,
        'settings': state.kv,
        'events': [for (final e in state.events) e.toJson()],
        'records': [for (final r in state.recs) r.toJson()],
      });

  Future<void> wipe() async {
    await native.stopTimer();
    await _store.wipe();
    state = AppData.empty;
    await syncNative();
  }
}
