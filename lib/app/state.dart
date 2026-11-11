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
      {int? minutes, String? projectId, String? title, String source = 'app', int? startMs}) async {
    final v = view;
    if (v.active != null) return;
    final now = _now;
    final begin = startMs ?? now.ms;
    minutes ??= v.doorMinutes;
    final pid = projectId ?? state.kv[K.lastProject];
    final s = ActiveSession(newId(), begin, minutes, pid, title ?? v.nextStep, source);
    await setKv(K.active, s.encode());
    if (pid != null) await setKv(K.lastProject, pid);
    await log(Ev.sessionStart,
        {'sid': s.sid, 'minutes': minutes, 'projectId': pid, 'source': source, 'title': s.title},
        Moment(begin, now.offsetMin));
    native.haptic();
    if (startMs == null) await native.startTimer(s.endMs, s.title);
    await syncNative();
  }

  /// Call often. If the running session has reached its end (even while the
  /// app was dead), records it at the moment it ended. Returns true if it did.
  Future<bool> completeIfDue() async {
    final s = view.active;
    final now = _now;
    if (s == null || now.ms < s.endMs) return false;
    await _finish(s, s.minutes, Moment(s.endMs, now.offsetMin));
    return true;
  }

  Future<void> _finish(ActiveSession s, int minutes, Moment at) async {
    // "Just five more" adds to the proof that is already waiting.
    final carried = s.source == 'five_more' ? (view.pendingProof?['minutes'] as int? ?? 0) : 0;
    await setKv(K.active, null);
    await log(Ev.sessionDone, {'sid': s.sid, 'minutes': minutes, 'projectId': s.projectId}, at);
    await setKv(K.pendingProof,
        jsonEncode({'sid': s.sid, 'projectId': s.projectId, 'minutes': minutes + carried, 'title': s.title}));
    celebrate();
    await syncNative();
  }

  /// Stopping early. Two minutes or more still counts as a finished session.
  Future<void> stopSession() async {
    final s = view.active;
    if (s == null) return;
    final now = _now;
    final elapsedMin = (now.ms - s.startMs) ~/ msPerMinute;
    await native.stopTimer();
    if (elapsedMin >= 2) {
      await _finish(s, elapsedMin, now);
    } else {
      await setKv(K.active, null);
      await log(Ev.sessionAbandon, {'sid': s.sid, 'elapsedSec': (now.ms - s.startMs) ~/ 1000});
      await syncNative();
    }
  }

  Future<void> saveProof({required String type, required String value, String parkingNote = ''}) async {
    final p = view.pendingProof;
    if (p == null) return;
    final rec = await addRec(Kind.proof, {
      'sid': p['sid'], 'projectId': p['projectId'], 'type': type, 'value': value,
      'minutes': p['minutes'], 'title': p['title'], 'day': view.today,
    });
    await log(Ev.proof, {'sid': p['sid'], 'recId': rec.id, 'kind': type, 'projectId': p['projectId']});
    if (parkingNote.trim().isNotEmpty) {
      await log(Ev.parkingNote, {'text': parkingNote.trim(), 'projectId': p['projectId']});
    }
    await setKv(K.pendingProof, null);
    celebrate();
    await syncNative();
  }

  // ---- habits, projects, tasks, plan
  Future<void> tickHabit(String habitId) async {
    if (view.tickedToday(habitId)) return;
    await log(Ev.habitTick, {'habitId': habitId});
    celebrate();
    await syncNative();
  }

  Future<void> toggleTask(Rec task) async {
    final done = !task.flag('done');
    await putRec(task.copy({'done': done}));
    if (done) {
      await log(Ev.taskDone, {'taskId': task.id});
      celebrate();
    }
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
    Map<String, Object?> sw(String k) => {'on': v.sw(k).on, 'offAt': v.sw(k).offAt ?? 0};
    final lastDone = v.sessionDays.isEmpty ? -1 : v.sessionDays.reduce((a, b) => a > b ? a : b);
    await native.sync({
      'dayEndHour': v.dayEndHour,
      'cueMinute': v.todayPlan?.cueMinute ?? v.cueMinute,
      'nextCueMinute': v.tomorrowPlan?.cueMinute ?? v.cueMinute,
      'task': v.nextStep,
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
