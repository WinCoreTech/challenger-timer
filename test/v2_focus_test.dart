import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/focus.dart';
import 'package:challenger_timer/core/pressure.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/wellbeing.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

Future<void> start(Rig r, String mode, {int minutes = 25}) =>
    r.app.startSession(minutes: minutes, source: 'work', meta: {'mode': mode});

void main() {
  test('R3 sleep window: 00:00 to 04:00 is always protected, whatever the settings say', () async {
    final r = Rig();
    await r.app.setKv('flag.303', '0');
    expect(inSleepWindow(r.v, 0), isTrue);
    expect(inSleepWindow(r.v, 3 * 60 + 59), isTrue);
    expect(inSleepWindow(r.v, 4 * 60), isFalse);
    await r.app.addRec('t6', {'a': ['2 am', 'study'], 'minute': 2 * 60, 'day': r.v.today});
    await r.app.addRec('block', {'wd': weekdayOf(r.v.today), 'minute': 60, 'len': 25, 'projectId': '', 'remind': true});
    expect(buildReminders(r.v, tools).where((x) => x.minute < 240), isEmpty);
    await r.app.log(Ev.onboarded);
    await r.app.setSetting('cueMinute', '${3 * 60}');
    expect((r.native.lastSync['cue'] as Map)['on'], isFalse, reason: 'a 3 am cue alarm is never armed');
    await r.app.setSetting('cueMinute', '${7 * 60}');
    expect((r.native.lastSync['cue'] as Map)['on'], isTrue);
  });

  test('R5 burnout check eases the dial one step after 3 days over the daily limit', () async {
    final r = Rig();
    await r.app.setKv('dailyLimitHours', '2');
    expect(pressureLevel(r.v), 1);
    for (var i = 0; i < 3; i++) {
      await r.session(minutes: 90);
      await r.session(minutes: 90);
      r.clock.advance(const Duration(days: 1));
    }
    expect(burnoutEase(r.v), isTrue);
    expect(pressureLevel(r.v), 0);
    await r.session(minutes: 25);
    r.clock.advance(const Duration(days: 1));
    expect(pressureLevel(r.v), 1, reason: 'one day under the limit ends the easing');
  });

  test('modes: pauses allowed, grace, XP multiplier', () async {
    expect([modeOf('normal').pauses, modeOf('hyper').pauses, modeOf('beast').pauses], [2, 0, 0]);
    expect([modeOf('normal').graceMs, modeOf('hyper').graceMs, modeOf('beast').graceMs], [10000, 10000, 0]);
    expect(modeOf(null).id, 'normal');
    final r = Rig();
    await start(r, 'hyper');
    expect(r.native.calls, contains('dnd:true'));
    expect(await r.app.pauseSession('water'), isFalse, reason: 'Hyper has no pauses');
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.native.calls, contains('dnd:false'));
    expect(r.v.xpExtras, contains(('Focus mode bonus', 50)), reason: '0.5 x (50 + 25 x 2)');
    await start(r, 'beast');
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.v.xpExtras, contains(('Focus mode bonus', 150)));
    await start(r, 'normal');
    expect(await r.app.pauseSession('door'), isTrue);
    await r.app.resumeSession();
    expect(await r.app.pauseSession('call'), isTrue);
    await r.app.resumeSession();
    expect(await r.app.pauseSession('third'), isFalse);
  });

  test('leaving: Normal has 10 s grace, Beast none; screen-off and calls never fail', () async {
    final r = Rig();
    await start(r, 'normal');
    expect(await r.app.hardModeCheck(9000, leftWithScreenOn: true), isFalse);
    expect(await r.app.hardModeCheck(60000, leftWithScreenOn: false), isFalse, reason: 'screen off or a phone call');
    expect(await r.app.hardModeCheck(11000, leftWithScreenOn: true), isTrue);
    expect(r.v.active, isNull);
    await start(r, 'beast');
    expect(await r.app.hardModeCheck(2000, leftWithScreenOn: true), isTrue, reason: 'no grace in Beast');
    expect(r.v.type(Ev.sessionAbandon).last.payload['mode'], 'beast');
  });

  test('a failed Beast session costs 10 minutes of rank score, never below zero', () async {
    final r = Rig();
    await r.session(minutes: 25);
    final before = r.v.ladder.score;
    await start(r, 'beast');
    await r.app.hardModeCheck(5000, leftWithScreenOn: true);
    expect(r.v.ladder.score, closeTo(before - beastPenaltyMinutes, 1e-6));
    final z = Rig();
    await start(z, 'beast');
    await z.app.hardModeCheck(5000, leftWithScreenOn: true);
    expect(z.v.ladder.score, 0);
  });

  test('R6 emergency pause: any mode, once a day, never fails, ends itself after 10 minutes', () async {
    final r = Rig();
    await start(r, 'beast');
    final end = r.v.active!.endMs;
    expect(await r.app.emergencyPause(), isTrue);
    expect(await r.app.hardModeCheck(120000, leftWithScreenOn: true), isFalse, reason: 'paused sessions cannot fail');
    r.clock.advance(const Duration(minutes: 10));
    await r.app.completeIfDue();
    expect(r.v.active!.paused, isFalse);
    expect(r.v.active!.endMs, end + 10 * msPerMinute);
    expect(await r.app.emergencyPause(), isFalse, reason: 'one a day');
    expect(emergencyUsedToday(r.v), isTrue);
  });

  test('drift causes and drifts by hour', () async {
    final r = Rig();
    await start(r, 'normal');
    final sid = r.v.active!.sid;
    for (final c in ['phone', 'phone', 'tired']) {
      await r.app.log(Ev.tool, {'n': 92, 'sid': sid});
      await r.app.log(Ev.tool, {'n': driftCauseTool, 'sid': sid, 'cause': c});
    }
    expect(topDriftCauses(r.v), [('phone', 2), ('tired', 1)]);
    expect(driftsByHour(r.v)[10], 3);
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(lastFocusScore(r.v), 85);
  });

  testWidgets('work screen: mode chips, lost-focus button with cause, emergency pause', (t) async {
    final r = Rig();
    await pumpTool(t, r, const WorkScreen());
    await t.ensureVisible(find.byKey(const Key('mode-beast')));
    await t.tap(find.byKey(const Key('mode-beast')));
    await t.pump();
    expect(r.v.kv['focusMode'], 'beast');
    await t.ensureVisible(find.byKey(const Key('workStart')));
    await t.tap(find.byKey(const Key('workStart')));
    await t.pumpAndSettle();
    expect(find.text('GOAL FOR THIS SESSION'), findsOneWidget);
    await t.tap(find.text('START'));
    await t.pumpAndSettle();
    expect(r.v.active, isNull, reason: 'Beast needs a goal');
    await t.tap(find.byKey(const Key('workStart')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Finish question 3');
    await t.tap(find.text('START'));
    await t.pump(const Duration(milliseconds: 600));
    expect(r.v.active!.title, 'Finish question 3');
    expect(find.byKey(const Key('workPause')), findsNothing);
    await t.tap(find.byKey(const Key('workDrift')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('cause-phone')));
    await t.pump(const Duration(milliseconds: 300));
    expect(topDriftCauses(r.v), [('phone', 1)]);
    await t.tap(find.byKey(const Key('workEmergency')));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.v.active!.paused, isTrue);
    expect(find.text('PAUSED'), findsOneWidget);
    await pumpTool(t, r, const SizedBox());
  });
}
