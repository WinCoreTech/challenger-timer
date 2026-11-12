import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/streak_engine.dart';
import 'package:challenger_timer/ui/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

/// Runs sessions on [n] consecutive days and stops on the day after the last.
Future<void> run(Rig r, int n) async {
  for (var i = 0; i < n; i++) {
    await r.session();
    r.clock.advance(const Duration(days: 1));
  }
}

void main() {
  test('53 earned freeze after 7 days shows as an extra life', () async {
    final r = Rig();
    await run(r, 7);
    expect(r.v.master.freezesLeft, 3);
    await r.app.setKv('flag.53', '0');
    expect(r.v.master.freezesLeft, 2);
  });

  test('55 decay is opt-in: off keeps the Version 1 break, on keeps 80%', () async {
    final r = Rig();
    await r.app.setKv('flag.53', '0');
    await run(r, 10); // now on day 11 (index 10), nothing done
    r.clock.advance(const Duration(days: 4)); // 2 frozen, 2 uncovered: broken
    expect(r.v.master.current, 0);
    await r.app.setKv('decay', '1');
    expect(r.v.master.current, 8);
    expect(r.v.master.longest, 10);
  });

  test('57 comeback bonus doubles the first session after an uncovered miss', () async {
    final r = Rig();
    await r.app.setKv('flag.53', '0');
    await r.session();
    r.clock.advance(const Duration(days: 4)); // 2 frozen + 1 uncovered miss
    expect(r.v.xpExtras.where((e) => e.$1.startsWith('Comeback')), isEmpty);
    await r.session();
    expect(r.v.master.comebackDays, {r.v.today});
    expect(r.v.xpExtras, contains(('Comeback bonus (double XP)', 54)));
  });

  test('58 repair restores yesterday only after double the minimum today', () async {
    final r = Rig();
    await r.app.setKv('flag.53', '0');
    await run(r, 3);
    r.clock.advance(const Duration(days: 3)); // misses: 2 frozen, then yesterday uncovered
    expect(r.v.master.state, StreakState.paused);
    expect(canRepair(r.v), isFalse, reason: 'nothing done today yet');
    await r.session();
    expect(canRepair(r.v), isFalse, reason: '2 minutes is not double');
    await r.session();
    expect(canRepair(r.v), isTrue);
    await r.app.log(Ev.tool, {'n': 58, 'repairDay': r.v.today - 1});
    expect(r.v.master.missedDays, isEmpty);
    expect(r.v.master.current, 5);
    expect(canRepair(r.v), isFalse);
  });

  test('59 sick mode pauses streaks, 60 exam mode pauses habits outside the exam set', () async {
    final r = Rig();
    await r.session();
    await r.app.log(Ev.tool, {'n': 59, 'on': true, 'reason': 'fever'});
    r.clock.advance(const Duration(days: 6));
    expect(pauseOn(r.v), isTrue);
    expect(r.v.master.current, 1);
    expect(r.v.master.freezesLeft, 2, reason: 'paused days cost no freeze');
    await r.app.log(Ev.tool, {'n': 59, 'on': false});
    expect(pausedDays(r.v).length, 7);
    await r.session();
    expect(r.v.master.current, 2);

    final e = Rig();
    final normal = await e.app.addRec(Kind.habit, {'name': 'Gym'});
    final exam = await e.app.addRec(Kind.habit, {'name': 'Past paper', 'exam': true});
    await e.app.tickHabit(normal.id);
    await e.app.tickHabit(exam.id);
    await e.app.log(Ev.tool, {'n': 60, 'on': true});
    e.clock.advance(const Duration(days: 5));
    expect(examOn(e.v), isTrue);
    expect(e.v.habitStreak(normal.id).current, 1);
    expect(e.v.habitStreak(normal.id).frozenDays, isEmpty, reason: 'paused, no freezes spent');
    expect(e.v.habitStreak(exam.id).current, 0, reason: 'the exam habit still has to be done');
  });

  test('63 miss pattern names the weekday and the top reason', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 9, 10))); // Monday
    await r.session();
    r.clock.setWall(2026, 11, 12, 10); // Tue, Wed missed (frozen)
    await r.session();
    await r.app.log(Ev.tool, {'n': 62, 'choice': 'tired'});
    await r.app.log(Ev.tool, {'n': 62, 'choice': 'tired'});
    await r.app.log(Ev.tool, {'n': 62, 'choice': 'busy'});
    final lines = missPattern(r.v);
    expect(['Tuesday', 'Wednesday'], contains(lines.first));
    expect(lines.join(' '), contains('"tired" (2 times)'));
    expect(missPattern(Rig().v).first, 'No misses yet');
  });

  test('64 restart at tiny for three days after a habit breaks', () async {
    final r = Rig();
    await r.app.setKv('flag.53', '0');
    final h = await r.app.addRec(Kind.habit, {'name': 'Read', 'tiny': 'One line'});
    await r.app.tickHabit(h.id);
    r.clock.advance(const Duration(days: 5)); // 2 frozen, 2 uncovered: broke yesterday
    expect(r.v.habitStreak(h.id).lastBreakDay, r.v.today - 1);
    expect(restartAtTiny(r.v, h.id), isTrue);
    r.clock.advance(const Duration(days: 3));
    expect(restartAtTiny(r.v, h.id), isFalse);
  });

  test('65 fresh-start dates', () {
    expect(freshStart(dayOfDate(2026, 11, 9)), 'Monday');
    expect(freshStart(dayOfDate(2026, 12, 1)), 'the 1st');
    expect(freshStart(dayOfDate(2026, 8, 14), birthday: '14-08'), 'your birthday');
    expect(freshStart(dayOfDate(2026, 11, 11)), isNull);
  });

  test('66 slip guard and 72 lapse plan decide the Home line after a miss', () async {
    final r = Rig();
    await r.session();
    expect(homeLine(r.v), 'Done for today. Streak safe.');
    r.clock.advance(const Duration(days: 2)); // yesterday covered by a freeze
    expect(homeLine(r.v), 'The day is not lost. Two minutes saves it.');
    await r.app.setKv('t.72', '["I will do one minute before breakfast"]');
    expect(homeLine(r.v), contains('I will do one minute before breakfast'));
    for (final bad in ['fail', 'lazy', 'shame', 'again?', 'disappoint']) {
      expect(homeLine(r.v).toLowerCase(), isNot(contains(bad)));
    }
  });

  test('68 half-credit days and 75 gold days', () async {
    final r = Rig();
    await r.app.startSession(minutes: 25);
    r.clock.advance(const Duration(seconds: 30));
    await r.app.stopSession();
    expect(halfDays(r.v), {r.v.today});
    r.clock.advance(const Duration(days: 1));
    await r.app.log(Ev.tool, {'n': 276, 'value': 2});
    expect(goldDays(r.v), isEmpty, reason: 'low mood alone is not gold');
    await r.session();
    expect(goldDays(r.v), {r.v.today});
    expect(halfDays(r.v).length, 1);
  });

  test('70 gifted freeze (local honour version): one a month, covers later misses only', () async {
    final r = Rig();
    await r.app.setKv('flag.53', '0');
    await r.session();
    await r.app.log(Ev.tool, {'n': 70});
    await r.app.log(Ev.tool, {'n': 70}); // second in the same month is ignored
    expect(giftDays(r.v).length, 1);
    expect(r.v.master.freezesLeft, 3);
    r.clock.advance(const Duration(days: 4)); // three misses, all covered
    expect(r.v.master.missedDays, isEmpty);
    expect(r.v.master.freezesLeft, 0);
  });

  testWidgets('71 return screen: after 3 days away Home is one button and no stats', (t) async {
    final r = Rig();
    await r.app.log(Ev.onboarded);
    await r.session();
    r.clock.advance(const Duration(days: 4));
    expect(daysAway(r.v), 4);
    await pumpTool(t, r, const Scaffold(body: HomeScreen()));
    expect(find.text('START AGAIN'), findsOneWidget);
    expect(find.byKey(const Key('masterStreak')), findsNothing);
    expect(find.byKey(const Key('bonus')), findsNothing);
    await r.app.setKv(K.simpleMode, '1');
    await t.pump();
    expect(find.byKey(const Key('masterStreak')), findsOneWidget, reason: 'Simple mode shows the Version 1 Home');
  });
}
