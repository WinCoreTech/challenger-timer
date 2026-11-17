import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/settings.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('status line follows state and never blames', () async {
    final r = Rig();
    expect(workStatus(r.v), contains('Nothing started yet today'));
    await r.app.startSession(minutes: 25, source: 'work');
    await r.app.stopSession(reason: 'cancel');
    expect(workStatus(r.v), contains('canceled'));
    await r.session(minutes: 25);
    expect(workStatus(r.v), contains('finished'));
    await r.app.saveProof(type: 'text', value: 'x');
    expect(workStatus(r.v), contains('on the board'));
    for (final bad in ['lazy', 'fail', 'shame', 'again?']) {
      expect(workStatus(r.v).toLowerCase(), isNot(contains(bad)));
    }
  });

  test('cancel logs a canceled session with no time, even past two minutes', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25, source: 'work');
    r.clock.advance(const Duration(minutes: 10));
    await r.app.stopSession(reason: 'cancel');
    expect(r.v.workedToday, isFalse);
    expect(r.v.minutesToday, 0);
    expect(r.v.type(Ev.sessionAbandon).single.payload['reason'], 'cancel');
  });

  test('continuous mode loops work, break, work with short and long breaks', () async {
    final r = Rig();
    await r.app.setKv(S.loop, '1');
    await r.app.setKv(S.longBreakEvery, '2');
    await r.app.startSession(minutes: 25, source: 'work');
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.v.active!.isBreak, isTrue);
    expect(r.v.active!.minutes, 5);
    r.clock.advance(const Duration(minutes: 5));
    await r.app.completeIfDue();
    expect(r.v.active!.isBreak, isFalse);
    expect(r.v.active!.minutes, 25);
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.v.active!.minutes, 15, reason: 'every second session earns the long break');
    await r.app.setKv(S.loop, '0');
    r.clock.advance(const Duration(minutes: 15));
    await r.app.completeIfDue();
    expect(r.v.active, isNull, reason: 'loop switched off: nothing starts by itself');
    expect(r.v.sessionsToday, 2);
  });

  test('late finish is recorded, warns, and can be hidden until the next one', () async {
    final r = Rig();
    await r.app.noteLateFinish();
    expect(r.v.lateWarning, isFalse);
    r.native.lateFinishMs = 4000;
    await r.app.noteLateFinish();
    expect(r.v.lateWarning, isFalse, reason: 'under 5 seconds is on time');
    r.native.lateFinishMs = 42000;
    await r.app.noteLateFinish();
    expect(r.v.lateWarning, isTrue);
    await r.app.setKv(S.hideLateWarning, '1');
    expect(r.v.lateWarning, isFalse);
    r.native.lateFinishMs = 9000;
    await r.app.noteLateFinish();
    expect(r.v.lateWarning, isTrue);
  });

  test('mute silences the tone but keeps the haptic; robust setting is synced', () async {
    final r = Rig();
    await r.app.setKv(S.muted, '1');
    await r.session();
    expect(r.native.calls, isNot(contains('tone')));
    expect(r.native.calls, contains('haptic:heavy'));
    expect(r.native.lastSync['robust'], isFalse);
    await r.app.setSetting(S.robustCountdown, '1');
    expect(r.native.lastSync['robust'], isTrue);
  });

  testWidgets('idle: rows, toggle to session count, rank banner, start uses the project length', (t) async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'Thesis', 'workMin': 50});
    await r.app.setKv(K.lastProject, p.id);
    await r.session(minutes: 25);
    await r.app.saveProof(type: 'text', value: 'x');
    await pumpTool(t, r, const WorkScreen());
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('Thesis'), findsOneWidget);
    expect(find.text('25m'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('workRank')), matching: find.text(r.v.ladderRank.name)), findsOneWidget);
    expect(find.byKey(const Key('celebration')), findsOneWidget, reason: 'the first rank-up is celebrated');
    expect(find.textContaining('more minutes today to advance in rank'), findsOneWidget);
    await t.tap(find.byKey(const Key('workToday')));
    await t.pump();
    expect(find.text('WORK SESSIONS COMPLETED TODAY'), findsOneWidget);
    expect(find.textContaining('sessions'), findsWidgets);
    await t.tap(find.byKey(const Key('workStart')));
    await t.pumpAndSettle();
    expect(find.text('WHAT IS THIS SESSION FOR?'), findsOneWidget);
    await t.tap(find.text('START'));
    await t.pump(const Duration(milliseconds: 600));
    expect(r.v.active!.minutes, 50);
    expect(r.v.active!.meta['mode'], 'normal');
    expect(find.text('WORKING'), findsOneWidget);
    expect(find.text('50:00'), findsOneWidget);
    await t.tap(find.byKey(const Key('workLoop')));
    await t.pump();
    expect(r.v.prefOn(S.loop), isTrue);
    await t.tap(find.byKey(const Key('workCancel')));
    await t.pumpAndSettle();
    await t.tap(find.text('CANCEL IT'));
    await t.pumpAndSettle();
    expect(r.v.active, isNull);
    expect(find.textContaining('canceled'), findsOneWidget);
    await pumpTool(t, r, const SizedBox());
  });

  testWidgets('late warning icon opens the fix dialog; tablet and large text render', (t) async {
    final r = Rig();
    r.native.lateFinishMs = 30000;
    await r.app.noteLateFinish();
    await pumpTool(t, r, const WorkScreen());
    await t.tap(find.byKey(const Key('lateWarning')));
    await t.pumpAndSettle();
    expect(find.textContaining('30 seconds after'), findsOneWidget);
    await t.tap(find.byKey(const Key('lateFix')));
    await t.pumpAndSettle();
    expect(r.native.calls, contains('settings:battery'));
    t.view.physicalSize = const Size(2560, 1600);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(const SizedBox());
    await pumpTool(t, r, const MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2)), child: WorkScreen()));
    t.view.physicalSize = const Size(2560, 1600);
    t.view.devicePixelRatio = 2.0;
    await t.pump();
    expect(t.takeException(), isNull);
    await pumpTool(t, r, const SizedBox());
  });
}
