import 'dart:convert';

import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/rules.dart';
import 'package:challenger_timer/core/streak_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('one-tap start: default session is 2 minutes and a full win', () async {
    final r = Rig();
    await r.app.startSession();
    expect(r.v.active!.minutes, 2);
    expect(r.native.calls, contains('startTimer:${r.v.active!.endMs}'));
    expect(r.v.starts, 1);
    expect(r.v.workedToday, isFalse);

    r.clock.advance(const Duration(seconds: 119));
    expect(await r.app.completeIfDue(), isFalse);
    r.clock.advance(const Duration(seconds: 1));
    expect(await r.app.completeIfDue(), isTrue);
    expect(r.v.active, isNull);
    expect(r.v.workedToday, isTrue);
    expect(r.v.master.current, 1);
    expect(r.v.master.state, StreakState.active);
    expect(r.v.pendingProof!['minutes'], 2);
    expect(r.native.calls, contains('haptic:heavy'));
    expect(r.native.calls, contains('tone'));
  });

  test('timer survives the app being killed: state reloads and ends at the stored time', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25);
    final end = r.v.active!.endMs;
    // "Kill" the app: new container, same database, 40 minutes later.
    r.clock.advance(const Duration(minutes: 40));
    final r2 = Rig(store: r.store, clock: r.clock);
    await r2.app.load();
    expect(r2.v.active!.endMs, end);
    expect(await r2.app.completeIfDue(), isTrue);
    final done = r2.v.type(Ev.sessionDone).single;
    expect(done.ts, end, reason: 'recorded at the moment it ended, not when the app reopened');
    expect(done.payload['minutes'], 25);
  });

  test('stopping under 2 minutes does not count, 2 minutes or more does', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25);
    r.clock.advance(const Duration(seconds: 90));
    await r.app.stopSession();
    expect(r.v.workedToday, isFalse);
    expect(r.v.type(Ev.sessionAbandon).length, 1);

    await r.app.startSession(minutes: 25);
    r.clock.advance(const Duration(minutes: 7, seconds: 30));
    await r.app.stopSession();
    expect(r.v.workedToday, isTrue);
    expect(r.v.minutesToday, 7);
    expect(r.native.calls.where((c) => c == 'stopTimer').length, 2);
  });

  test('proof and parking note: the note becomes the next tiny step', () async {
    final r = Rig();
    expect(r.v.nextStep, defaultStep);
    await r.session();
    await r.app.saveProof(type: 'text', value: 'Solved two array problems', parkingNote: 'Open LeetCode problem 15');
    expect(r.v.pendingProof, isNull);
    expect(r.v.proofs.single.str('value'), 'Solved two array problems');
    expect(r.v.proofs.single.integer('day'), r.v.today);
    expect(r.v.nextStep, 'Open LeetCode problem 15');
    expect(r.v.xp.proof, xpProof);
  });

  test('just five more adds to the waiting proof', () async {
    final r = Rig();
    await r.session();
    final p = r.v.pendingProof!;
    await r.app.startSession(minutes: 5, source: 'five_more', projectId: p['projectId'] as String?);
    r.clock.advance(const Duration(minutes: 5));
    await r.app.completeIfDue();
    expect(r.v.pendingProof!['minutes'], 7);
    expect(r.v.minutesToday, 7);
    expect(r.v.sessionsToday, 2);
  });

  test('sessions and proof belong to a project', () async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'DSA'});
    await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Two pointers', 'done': false});
    await r.app.startSession(projectId: p.id);
    r.clock.advance(const Duration(minutes: 2));
    await r.app.completeIfDue();
    await r.app.saveProof(type: 'link', value: 'https://example.com/commit/1');
    expect(r.v.proofs.single.str('projectId'), p.id);
    expect(r.v.type(Ev.sessionDone).single.payload['projectId'], p.id);
    expect(r.v.tasksOf(p.id).single.str('title'), 'Two pointers');
    // The next session defaults to the same project.
    await r.app.startSession();
    expect(r.v.active!.projectId, p.id);
  });

  test('habit streaks are separate, and a habit tick feeds the master streak', () async {
    final r = Rig();
    final a = await r.app.addRec(Kind.habit, {'name': 'Open the book'});
    final b = await r.app.addRec(Kind.habit, {'name': 'One commit'});
    await r.app.tickHabit(a.id);
    await r.app.tickHabit(a.id); // second tap on the same day is ignored
    expect(r.v.type(Ev.habitTick).length, 1);
    expect(r.v.habitStreak(a.id).current, 1);
    expect(r.v.habitStreak(b.id).current, 0);
    expect(r.v.master.current, 1);
    r.clock.advance(const Duration(days: 1));
    await r.app.tickHabit(b.id);
    expect(r.v.habitStreak(a.id).current, 1);
    expect(r.v.habitStreak(a.id).state, StreakState.pending);
    expect(r.v.habitStreak(b.id).current, 1);
    expect(r.v.master.current, 2);
  });

  test('never miss twice with freezes, end to end over real days', () async {
    final r = Rig();
    await r.session(); // 11 Nov
    r.clock.advance(const Duration(days: 3)); // miss 12, 13 (two freezes), now 14
    expect(r.v.master.current, 1);
    expect(r.v.master.freezesLeft, 0);
    expect(r.v.master.state, StreakState.pending);
    r.clock.advance(const Duration(days: 1)); // 14 missed with no freeze, now 15
    expect(r.v.master.state, StreakState.paused);
    expect(r.v.master.current, 1);
    await r.session();
    expect(r.v.master.current, 2);
    expect(r.v.master.comebacks, 1);
  });

  test('a session at 1 am counts for the previous day (day ends at 3 am)', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 12, 1)));
    await r.session();
    final day = r.v.today;
    r.clock.setWall(2026, 11, 12, 2, 59);
    expect(r.v.today, day);
    expect(r.v.workedToday, isTrue);
    r.clock.setWall(2026, 11, 12, 3, 0);
    expect(r.v.today, day + 1);
    expect(r.v.workedToday, isFalse);
  });

  test('bonus to lose: held, then kept by a session, gone after a zero day', () async {
    final r = Rig();
    await r.app.log(Ev.appOpen);
    expect(r.v.bonusAtRisk, isTrue);
    expect(r.v.xp.bonus, 100);
    expect(r.v.dayLeft, closeTo(17 / 24, 1e-6)); // 10:00, day ends 03:00
    r.clock.advance(const Duration(days: 1));
    expect(r.v.xp.bonus, 100, reason: "yesterday's bonus vanished, today's is held");
    await r.session();
    expect(r.v.bonusAtRisk, isFalse);
    r.clock.advance(const Duration(days: 1));
    expect(r.v.xp.bonus, 200, reason: 'kept one plus today');
  });

  test('locked first task: editable before 10 pm, locked after, shown next day', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 20)));
    expect(await r.app.setPlan('Open notebook to page 12', 7 * 60 + 30), isTrue);
    expect(await r.app.setPlan('Open notebook to page 13', 7 * 60), isTrue);
    expect(r.v.planLocked, isFalse);
    r.clock.setWall(2026, 11, 11, 22, 0);
    expect(r.v.planLocked, isTrue);
    expect(await r.app.setPlan('Sleep in', 11 * 60), isFalse);
    expect(r.v.tomorrowPlan!.task, 'Open notebook to page 13');
    r.clock.setWall(2026, 11, 12, 1, 0); // after midnight, same logical day
    expect(r.v.planLocked, isTrue);
    r.clock.setWall(2026, 11, 12, 7, 0);
    expect(r.v.todayPlan!.task, 'Open notebook to page 13');
    expect(r.v.nextStep, 'Open notebook to page 13');
    expect(r.native.lastSync['task'], isNotNull);
    await r.app.syncNative();
    expect(r.native.lastSync['task'], 'Open notebook to page 13');
    expect(r.native.lastSync['cueMinute'], 7 * 60);
  });

  test('with nothing planned by 10 pm, a plan can still be set once', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 23)));
    expect(r.v.planLocked, isFalse);
    expect(await r.app.setPlan('Open the PDF', 8 * 60), isTrue);
    expect(r.v.planLocked, isTrue);
    expect(await r.app.setPlan('Changed my mind', 8 * 60), isFalse);
  });

  test('delayed off switch: stays effective 24 hours, cancellable, then off', () async {
    final r = Rig();
    await r.app.switchOn(K.swBlock);
    expect(r.v.isOn(K.swBlock), isTrue);
    await r.app.switchRequestOff(K.swBlock);
    expect(r.v.isOn(K.swBlock), isTrue);
    expect(r.v.sw(K.swBlock).pendingOff(r.clock.ms), isTrue);
    expect((r.native.lastSync['block'] as Map)['offAt'], r.clock.ms + offDelayMs);
    await r.app.switchCancelOff(K.swBlock);
    r.clock.advance(const Duration(hours: 30));
    expect(r.v.isOn(K.swBlock), isTrue);
    await r.app.switchRequestOff(K.swBlock);
    r.clock.advance(const Duration(hours: 23, minutes: 59));
    expect(r.v.isOn(K.swBlock), isTrue);
    r.clock.advance(const Duration(minutes: 1));
    expect(r.v.isOn(K.swBlock), isFalse);
    // The lock on the plan obeys the same switch.
    await r.app.switchRequestOff(K.swLock);
    expect(r.v.isOn(K.swLock), isTrue);
  });

  test('native sync carries what alarms, blocker and report need', () async {
    final r = Rig();
    await r.app.setKv(K.name, 'Winzo');
    await r.app.setKv(K.buddyPhone, '+911234567890');
    await r.app.setSetting(K.blockedApps, jsonEncode(['com.example.reels']));
    await r.app.log(Ev.onboarded);
    await r.app.switchOn(K.swBlock);
    var s = r.native.lastSync;
    expect(s['blockedApps'], ['com.example.reels']);
    expect((s['block'] as Map)['on'], isTrue);
    expect((s['cue'] as Map)['on'], isTrue, reason: 'cue alarm is on by default');
    expect((s['rescue'] as Map)['on'], isTrue);
    expect((s['buddy'] as Map)['on'], isFalse);
    expect(s['lastSessionDay'], -1);
    expect(s['msgZero'], contains('Winzo did not start'));
    expect(s['onboarded'], isTrue);
    await r.session();
    s = r.native.lastSync;
    expect(s['lastSessionDay'], r.v.today, reason: 'unblocks apps for today');
    expect(s['msgDone'], contains('Winzo showed up today: 1 session'));
  });

  test('start from the notification: session starts at the native start time', () async {
    final r = Rig();
    await r.app.log(Ev.onboarded);
    final tapped = r.clock.ms;
    r.clock.advance(const Duration(seconds: 4)); // Flutter took a moment to wake
    r.native.launchAction = {'action': 'start2', 'source': 'cue', 'startMs': tapped};
    expect(await r.app.handleLaunchAction(), 'start2');
    final s = r.v.active!;
    expect(s.minutes, 2);
    expect(s.startMs, tapped);
    expect(s.source, 'cue');
    expect(r.native.calls.where((c) => c.startsWith('startTimer')), isEmpty,
        reason: 'the native side already started the timer service');
    expect(await r.app.handleLaunchAction(), isNull);
  });

  test('buddy report: SMS when allowed, otherwise falls back', () async {
    final r = Rig();
    await r.app.setKv(K.name, 'Winzo');
    await r.app.setKv(K.buddyPhone, '+911234567890');
    expect(await r.app.sendBuddySms(), isFalse, reason: 'no permission: caller uses the share sheet');
    r.native.permissions['sms'] = true;
    expect(await r.app.sendBuddySms(), isTrue);
    expect(r.native.sms.single, startsWith('+911234567890|Winzo did not start a session today'));
    expect(r.v.type(Ev.buddyReport).single.payload['channel'], 'sms');
  });

  test('export contains everything, delete removes everything', () async {
    final r = Rig();
    await r.app.setKv(K.name, 'Winzo');
    await r.app.addRec(Kind.habit, {'name': 'Open the book'});
    await r.session();
    final j = jsonDecode(r.app.exportJson()) as Map;
    expect(j['settings'][K.name], 'Winzo');
    expect((j['events'] as List).map((e) => e['type']), containsAll([Ev.sessionStart, Ev.sessionDone]));
    expect((j['records'] as List).single['data']['name'], 'Open the book');
    await r.app.wipe();
    expect(r.store.events, isEmpty);
    expect(r.store.recs, isEmpty);
    expect(r.store.kv, isEmpty);
    expect(r.v.onboarded, isFalse);
  });

  test('achievements unlock from metrics computed from events', () async {
    final r = Rig();
    expect(achievements.where((a) => a.earned(r.v.metrics)), isEmpty);
    await r.session();
    await r.app.saveProof(type: 'text', value: 'x');
    final got = achievements.where((a) => a.earned(r.v.metrics)).map((a) => a.id);
    expect(got, containsAll(['first_start', 'first_done', 'first_proof']));
    expect(got, isNot(contains('streak_3')));
  });
}
