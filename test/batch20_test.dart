import 'package:challenger_timer/core/coach.dart';
import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/ui/home.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('505-512 week-one missions tick from the log and earn the Starter badge', () async {
    final r = Rig();
    await r.app.log(Ev.onboarded);
    expect(weekOne(r.v).where((m) => m.$2), isEmpty);
    await r.session(minutes: 15);
    await r.app.saveProof(type: 'text', value: 'x', parkingNote: 'Open page 2');
    await r.app.setPlan('Open page 2', 540);
    await r.app.setKv(K.buddyPhone, '+911');
    expect(weekOne(r.v).where((m) => m.$2).length, 6);
    await r.app.log(Ev.tool, {'n': 184});
    await r.app.log(Ev.tool, {'n': 0, 'xp': 400});
    expect(weekOne(r.v).every((m) => m.$2), isTrue);
    expect(achievements.singleWhere((a) => a.id == 'starter').earned(r.v.metrics), isTrue);
  });

  test('521 fading support, 522 day-3 dip, 600 graduation test', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.log(Ev.onboarded);
    expect(defaultReminderCap(r.v), 3);
    r.clock.advance(const Duration(days: 2));
    expect(dayThreeDip(r.v), isTrue);
    expect(homeLine(r.v), contains('That is normal'));
    r.clock.advance(const Duration(days: 6));
    expect(defaultReminderCap(r.v), 2);
    await r.app.syncNative();
    expect(r.native.lastSync['remCap'], 2);
    expect(r.native.lastSync['reminders'], isNotEmpty);
    await r.app.setKv('gradTestFrom', '${r.v.today}');
    await r.app.setKv('gradTest', '1');
    await r.app.syncNative();
    expect(r.native.lastSync['reminders'], isEmpty);
    r.clock.advance(const Duration(days: 7));
    expect(graduationTestRunning(r.v), isFalse);
  });

  test('543 deadline extraction', () {
    final today = dayOfDate(2026, 11, 11); // Wednesday
    expect(extractDeadline('Submit the lab record by 14 Nov', today), dayOfDate(2026, 11, 14));
    expect(extractDeadline('Due 20/11', today), dayOfDate(2026, 11, 20));
    expect(extractDeadline('due 05-01-2027 sharp', today), dayOfDate(2027, 1, 5));
    expect(extractDeadline('viva on 3rd Jan', today), dayOfDate(2027, 1, 3));
    expect(extractDeadline('bring it tomorrow', today), today + 1);
    expect(extractDeadline('test on Friday', today), today + 2);
    expect(extractDeadline('no date here', today), isNull);
  });

  test('529 task rewriter, 531 excuse responder, 528 auto-priority, 582 auto difficulty', () async {
    expect(rewriteTask('study ML'), 'Open the ML notes and read the first page');
    expect(rewriteTask('Open notebook'), 'Open notebook');
    expect(excuseReply('I am too tired'), contains('tired version'));
    expect(excuseReply('I will do it tomorrow'), contains('Tomorrow-you'));
    for (final e in ['tired', 'no time', 'not in the mood', 'later', 'xyz']) {
      for (final bad in ['lazy', 'excuse', 'pathetic', 'shame']) {
        expect(excuseReply(e).toLowerCase(), isNot(contains(bad)));
      }
    }
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'P'});
    await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'No date', 'done': false});
    await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Later big', 'done': false, 'due': r.v.today + 9, 'est': 200});
    await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Soon', 'done': false, 'due': r.v.today + 2, 'est': 50});
    expect(autoPriority(r.v).map((t) => t.str('title')), ['Soon', 'Later big', 'No date']);
    expect(morningPlan(r.v).first, contains('Soon'));
    expect(autoDifficulty(5, 4, 5), 6);
    expect(autoDifficulty(5, 2, 5), 4);
    expect(autoDifficulty(5, 3, 5), 5);
    expect(autoDifficulty(1, 0, 5), 1);
    expect(autoDifficulty(5, 1, 2), 5, reason: 'too few tries to judge');
  });

  test('540 slump forecast, 541 learned cue, 596 minimum upgrade', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 2, 10))); // Monday
    await r.app.setKv('flag.53', '0');
    await r.session();
    r.clock.setWall(2026, 11, 4, 10); // Tuesday missed
    await r.session();
    r.clock.setWall(2026, 11, 9, 10);
    await r.session();
    r.clock.setWall(2026, 11, 11, 10); // Tuesday missed again
    await r.session();
    r.clock.setWall(2026, 11, 17, 10); // a Tuesday
    expect(slumpWarning(r.v), contains('most often miss'));
    r.clock.setWall(2026, 11, 18, 10);
    expect(slumpWarning(r.v), isNull);
    expect(learnedCue(r.v), isNull);
    expect(minimumFeelsEasy(r.v), isFalse);
  });

  testWidgets('551/571/572 routine: build, run step by step, time it', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await pumpTool(t, r, const Scaffold(body: SingleChildScrollView(child: RoutineTool(551))));
    for (final s in ['Drink water', 'Make the bed']) {
      await t.enterText(find.byKey(const Key('routineField')), s);
      await t.tap(find.byKey(const Key('routineAdd')));
      await t.pump();
    }
    await t.tap(find.byKey(const Key('routineRun')));
    await t.pump();
    expect(find.text('Drink water'), findsOneWidget);
    r.clock.advance(const Duration(seconds: 95));
    await t.tap(find.byKey(const Key('routineNext')));
    await t.pump();
    expect(find.text('Make the bed'), findsOneWidget);
    await t.tap(find.byKey(const Key('routineNext')));
    await t.pump();
    expect(r.v.type(Ev.tool).last.payload['seconds'], 95);
    expect(find.textContaining('Best time: 1 min 35 s'), findsOneWidget);
  });
}
