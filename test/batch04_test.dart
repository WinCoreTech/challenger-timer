import 'package:challenger_timer/core/challenges.dart';
import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/ui/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('77 pomodoro: work, break and next round advance while the app is open', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25, cycleWork: 25, cycleRest: 5, cycleLeft: 1, source: 'cycle');
    r.clock.advance(const Duration(minutes: 25));
    expect(await r.app.completeIfDue(), isTrue);
    expect(r.v.active!.isBreak, isTrue);
    expect(r.v.active!.minutes, 5);
    r.clock.advance(const Duration(minutes: 5));
    await r.app.completeIfDue();
    expect(r.v.active!.isBreak, isFalse);
    expect(r.v.active!.cycleLeft, 0);
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.v.active, isNull, reason: 'cycle is over');
    expect(r.v.sessionsToday, 2);
    expect(r.v.pendingProof!['minutes'], 50, reason: 'both rounds share one proof');
    expect(r.v.type(Ev.breakStart).length, 1);
  });

  test('77 a cycle never runs on by itself while the app is closed', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25, cycleWork: 25, cycleRest: 5, cycleLeft: 3, source: 'cycle');
    r.clock.advance(const Duration(hours: 3));
    await r.app.completeIfDue();
    expect(r.v.sessionsToday, 1, reason: 'only the round that really ran is credited');
    expect(r.v.active, isNull);
  });

  test('78 flowtime counts up and sizes the break to the work', () async {
    final r = Rig();
    await r.app.startSession(flow: true, source: 'flow');
    expect(r.v.active!.flow, isTrue);
    r.clock.advance(const Duration(minutes: 40));
    expect(r.v.active!.elapsedMs(r.clock.ms), 40 * msPerMinute);
    await r.app.stopSession();
    expect(r.v.minutesToday, 40);
    expect(r.v.pendingProof!['break'], 8);
    await r.app.startBreak(8);
    expect(r.v.active!.isBreak, isTrue);
    await r.app.stopSession();
    expect(r.v.active, isNull);
    expect(r.v.sessionsToday, 1, reason: 'a break is not a session');
  });

  test('80 ramp ladder grows one minute per worked day, opt-in', () async {
    final r = Rig();
    expect(r.v.doorMinutes, 2);
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('ramp', '1');
    await r.app.setKv('rampFrom', '${r.v.today}');
    expect(r.v.doorMinutes, 2);
    await r.session(minutes: 2);
    r.clock.advance(const Duration(days: 1));
    expect(r.v.doorMinutes, 3);
    r.clock.advance(const Duration(days: 1)); // skipped a day: no growth
    expect(r.v.doorMinutes, 3);
    expect(rampMinutes(r.v), 3);
  });

  test('84-87 challenges are deterministic and pay XP when met', () async {
    final r = Rig();
    final d = r.v.today;
    final c = dailyChallenge(r.v, d);
    expect(c.done, isFalse);
    expect(dailyChallenge(r.v, d).title, c.title, reason: 'same day, same challenge');
    for (var i = 0; i < 3; i++) {
      await r.session(minutes: 15);
      await r.app.saveProof(type: 'text', value: 'x', parkingNote: 'Open page $i');
    }
    expect(dailyChallenge(r.v, d).done, isTrue, reason: '3 sessions, 45 minutes, 3 proofs satisfy every daily type');
    expect(r.v.xpExtras.any((e) => e.$1 == 'Daily challenges' && e.$2 == 40), isTrue);
    final boss = weeklyBoss(r.v, weekOf(d));
    expect(boss.need, 5);
    expect(boss.have, 3);
    expect(monthlyCampaign(r.v, monthKey(d)).have, 1);
    // A mission exists on some days and not on others.
    final withMission = [for (var x = d; x < d + 30; x++) x].where((x) => missionCard(r.v, x) != null).length;
    expect(withMission, inInclusiveRange(5, 15));
  });

  test('88 beat yesterday and 89 ghost race', () async {
    final r = Rig();
    await r.session(minutes: 15);
    r.clock.advance(const Duration(minutes: 60));
    await r.session(minutes: 25);
    r.clock.setWall(2026, 11, 12, 10, 20);
    expect(beatYesterday(r.v).need, 41);
    final g = ghostRace(r.v);
    expect(g.bestTotal, 40);
    expect(g.ghostNow, 15, reason: 'by 10:20 the best day only had its first session');
    expect(g.youNow, 0);
  });

  test('90 hard mode: leaving with the screen on ends the session, screen-off does not', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25, hard: true);
    expect(r.native.calls, contains('keepOn:true'));
    expect(await r.app.hardModeCheck(5000, leftWithScreenOn: true), isFalse, reason: 'under 10 seconds');
    expect(await r.app.hardModeCheck(60000, leftWithScreenOn: false), isFalse, reason: 'screen was off');
    expect(r.v.active, isNotNull);
    r.clock.advance(const Duration(minutes: 5));
    expect(await r.app.hardModeCheck(60000, leftWithScreenOn: true), isTrue);
    expect(r.v.active, isNull);
    expect(r.v.workedToday, isFalse, reason: 'no credit, even past two minutes');
    expect(r.v.type(Ev.sessionAbandon).single.payload['reason'], 'left');
    expect(r.native.calls, contains('keepOn:false'));
  });

  test('91 soft mode: two pauses with reasons, the end time shifts', () async {
    final r = Rig();
    await r.app.startSession(minutes: 10);
    final end = r.v.active!.endMs;
    r.clock.advance(const Duration(minutes: 3));
    expect(await r.app.pauseSession('door'), isTrue);
    r.clock.advance(const Duration(minutes: 4));
    expect(await r.app.completeIfDue(), isFalse);
    expect(r.v.active!.remainingMs(r.clock.ms), 7 * msPerMinute, reason: 'frozen while paused');
    await r.app.resumeSession();
    expect(r.v.active!.endMs, end + 4 * msPerMinute);
    expect(await r.app.pauseSession('call'), isTrue);
    await r.app.resumeSession();
    expect(await r.app.pauseSession('third'), isFalse);
    expect(r.v.type(Ev.sessionPause).map((e) => e.payload['reason']), ['door', 'call']);
  });

  test('93 strict breaks count a late return, 94 break ideas never mention a screen', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.startBreak(5);
    r.clock.advance(const Duration(minutes: 9));
    await r.app.completeIfDue();
    expect(breakOverruns(r.v), 1);
    expect(r.v.toolEvents93, 4);
    for (final idea in breakIdeas) {
      for (final bad in ['phone', 'instagram', 'reel', 'scroll', 'video', 'social']) {
        expect(idea.toLowerCase(), isNot(contains(bad)));
      }
    }
  });

  test('98 difficulty bonus and 83 outcome are stored with the proof', () async {
    final r = Rig();
    await r.session();
    await r.app.saveProof(type: 'text', value: 'x', outcome: 'partly', difficulty: 3);
    expect(r.v.proofs.single.str('outcome'), 'partly');
    expect(r.v.xpExtras, contains(('Difficulty bonus', 20)));
  });

  testWidgets('timer modes: break screen uses the REST theme and shows a break idea; receipt after proof', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.startSession(minutes: 25, cycleWork: 25, cycleRest: 5, cycleLeft: 1, source: 'cycle');
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    await pumpTool(t, r, const TimerScreen());
    expect(find.text('REST'), findsOneWidget);
    expect(find.byKey(const Key('breakIdea')), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    await t.tap(find.byKey(const Key('endBreak')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('DONE.'), findsOneWidget);
    await pumpTool(t, r, const SizedBox());

    await r.app.saveProof(type: 'text', value: 'Wrote the intro', outcome: 'done');
    await pumpTool(t, r, const ReceiptScreen());
    expect(find.byKey(const Key('receipt')), findsOneWidget);
    expect(find.text('25 minutes'), findsOneWidget);
    expect(find.text('Wrote the intro'), findsOneWidget);
  });

  testWidgets('wander tally, pause and hidden clock on the running timer', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('hideClock', '1');
    await r.app.startSession(minutes: 10);
    await pumpTool(t, r, const TimerScreen());
    expect(find.text('••:••'), findsOneWidget);
    await t.tap(find.byKey(const Key('wander')));
    await t.pump(const Duration(milliseconds: 300));
    expect(wanderCount(r.v), 1);
    await t.tap(find.byKey(const Key('pause')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'water');
    await t.tap(find.text('PAUSE'));
    await t.pumpAndSettle();
    expect(r.v.active!.paused, isTrue);
    expect(find.byKey(const Key('resume')), findsOneWidget);
    await pumpTool(t, r, const SizedBox());
  });
}

extension on DayView {
  /// Minutes of overrun recorded by feature 93.
  int get toolEvents93 =>
      type(Ev.tool).where((e) => e.get<int>('n') == 93).fold(0, (a, e) => a + (e.get<int>('over') ?? 0));
}
