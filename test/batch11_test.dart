import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/wellbeing.dart';
import 'package:challenger_timer/ui/home.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

Future<void> rate(Rig r, int tool, int value) => r.app.log('tool', {'n': tool, 'value': value});

void main() {
  test('252 votes, 269 change timeline, 290 discomfort reps', () async {
    final r = Rig();
    await rate(r, 276, 1);
    await r.session(minutes: 15);
    await r.app.saveProof(type: 'text', value: 'x', anyway: 'tired');
    expect(votes(r.v), 2);
    expect(discomfortReps(r.v), 2);
    expect(changeTimeline(r.v), (15, 15));
  });

  test('299 support prompt after two weeks of low mood; never blames', () async {
    final r = Rig();
    expect(lowMoodTwoWeeks(r.v), isFalse);
    for (var i = 0; i < 6; i++) {
      await rate(r, 276, 2);
      r.clock.advance(const Duration(days: 2));
    }
    expect(lowMoodTwoWeeks(r.v), isTrue);
    final text = stats['wellbeing']!(r.v).join(' ');
    expect(text, contains('talk to someone you trust'));
    expect(text, contains('counsellor'));
    for (final bad in ['lazy', 'weak ', 'fault', 'should have']) {
      expect(text.toLowerCase(), isNot(contains(bad)));
    }
  });

  test('296 high stress, 297 burnout risk, 320 recovery score', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 2, 10))); // Monday
    await rate(r, 276, 4);
    await r.session(minutes: 90);
    r.clock.setWall(2026, 11, 9, 10);
    await rate(r, 276, 2);
    for (var i = 0; i < 4; i++) {
      await r.session(minutes: 90);
    }
    expect(burnoutRisk(r.v), isTrue);
    await rate(r, 296, 5);
    expect(highStress(r.v), isTrue);
    await rate(r, 301, 8);
    expect(recoveryScore(r.v), 80, reason: '8 hours of sleep (60) and a rest day this week (20)');
  });

  test('303 sleep window: no reminder is ever scheduled inside it', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('bedHour', '23');
    await r.app.setKv('wakeHour', '7');
    await r.app.addRec('t6', {'a': ['Midnight', 'study'], 'minute': 30, 'day': r.v.today});
    await r.app.addRec('t6', {'a': ['Evening', 'study'], 'minute': 20 * 60, 'day': r.v.today});
    await r.app.setKv('rem.302', '1');
    final rem = buildReminders(r.v, tools);
    expect(rem.map((x) => x.minute), containsAll([20 * 60, 22 * 60 + 15]));
    expect(rem.map((x) => x.minute), isNot(contains(30)), reason: 'the 00:30 if-then plan is inside the sleep window');
    expect(rem.any((x) => inSleepWindow(r.v, x.minute)), isFalse);
  });

  test('304 sleep versus focus, 287 forgive, 280 avoidance', () async {
    final r = Rig();
    await rate(r, 301, 8);
    await r.session(minutes: 50);
    r.clock.advance(const Duration(days: 1));
    await rate(r, 301, 5);
    await r.session(minutes: 10);
    expect(sleepVsFocus(r.v), (50.0, 10.0));
    expect(forgaveYesterday(r.v), isFalse);
    await r.app.log('tool', {'n': 287});
    expect(forgaveYesterday(r.v), isTrue);
    final p = await r.app.addRec('project', {'name': 'P'});
    final t = await r.app.addRec('task', {'projectId': p.id, 'title': 'Viva prep', 'done': false, 'due': r.v.today + 3});
    await r.app.postponeTask(t, 2, 'later');
    expect(mostPostponed(r.v).single.str('title'), 'Viva prep');
  });

  test('310/316/317 body prompts and 266 name talk', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    expect(bodyPrompt(r.v, 19), isNull);
    expect(bodyPrompt(r.v, 20), contains('Eye rest'));
    expect(bodyPrompt(r.v, 30), contains('Posture'));
    expect(bodyPrompt(r.v, 50), contains('move'));
    await r.app.setKv('name', 'Winzo');
    expect(homeLine(r.v), 'Winzo, start the timer. Two minutes.');
  });

  testWidgets('277/278 feeling picks a matching fix; 288 overwhelm mode shows one thing', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.log('onboarded');
    await pumpTool(t, r, const Scaffold(body: FeelingTool(277, ['bored', 'anxious', 'overwhelmed', 'confused'])));
    await t.tap(find.byKey(const Key('feel-overwhelmed')));
    await t.pump();
    expect(find.textContaining('Shrink it'), findsOneWidget);
    expect(r.v.type('tool').last.payload['choice'], 'overwhelmed');
    await r.app.setKv('overwhelm', '1');
    await pumpTool(t, r, const Scaffold(body: HomeScreen()));
    expect(find.text('ONE THING.'), findsOneWidget);
    expect(find.byKey(const Key('bonus')), findsNothing);
  });
}
