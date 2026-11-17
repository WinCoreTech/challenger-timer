import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/streak_engine.dart';
import 'package:challenger_timer/core/v2_day.dart';
import 'package:challenger_timer/ui/v2/shutdown_screen.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  recoveryTests();
  group('6.5 streak rule (plan v2)', () {
    test('a day counts only with one session of 25 minutes or more', () async {
      final r = Rig(streakMin: 25);
      await r.session(minutes: 2);
      await r.session(minutes: 15);
      final h = await r.app.addRec(Kind.habit, {'name': 'Read'});
      await r.app.tickHabit(h.id);
      expect(r.v.master.current, 0, reason: 'two short sessions and a habit tick do not make a streak day');
      await r.session(minutes: 25);
      expect(r.v.master.current, 1);
    });
    test('3 freezes a month and one rest day a week', () async {
      final r = Rig(streakMin: 25, clock: TestClock(DateTime.utc(2026, 11, 2, 10))); // Monday
      await r.session(minutes: 25);
      r.clock.setWall(2026, 11, 4, 10); // Tuesday missed: this week's rest day
      expect(r.v.master.restDays.length, 1);
      expect(r.v.master.freezesLeft, 3);
      r.clock.setWall(2026, 11, 7, 10); // Wed, Thu, Fri missed: three freezes
      expect(r.v.master.freezesLeft, 0);
      expect(r.v.master.current, 1);
      expect(r.v.master.state, StreakState.pending);
      r.clock.setWall(2026, 11, 8, 10); // Saturday missed, nothing left: paused
      expect(r.v.master.state, StreakState.paused);
    });
    test('engine: the weekly rest day resets each Monday', () {
      const rules = StreakRules(freezesPerMonth: 0, restPerWeek: 1);
      final mon = dayOfDate(2026, 11, 9); // a Monday
      // Active Mon; miss Tue (rest); active Wed..Sun; miss next Mon (new week's rest); active Tue.
      final days = {mon, mon + 2, mon + 3, mon + 4, mon + 5, mon + 6, mon + 8};
      final s = computeStreak(days, mon + 8, rules: rules);
      expect(s.missedDays, isEmpty);
      expect(s.restDays, {mon + 1, mon + 7});
      expect(s.current, 7);
      // Two misses in one week: the second is a real miss.
      final t = computeStreak({mon, mon + 3}, mon + 3, rules: rules);
      expect(t.restDays, {mon + 1});
      expect(t.missedDays, {mon + 2});
    });
    test('milestone titles', () async {
      final r = Rig(streakMin: 25);
      for (var i = 0; i < 7; i++) {
        await r.session(minutes: 25);
        r.clock.advance(const Duration(days: 1));
      }
      final m = milestones(r.v);
      expect(m.unlocked, ['One-Week Regular']);
      expect(m.next, 14);
      expect(streakMilestones.last, 365);
    });
  });

  group('6.4 the 2-minute door', () {
    test('door days, door streak, random bonus, and double XP for staying', () async {
      final r = Rig(streakMin: 25);
      await r.app.startSession(minutes: 2, source: 'door');
      final sid = r.v.active!.sid;
      r.clock.advance(const Duration(minutes: 2));
      await r.app.completeIfDue();
      expect(doorDays(r.v), {r.v.today});
      expect(doorStreak(r.v).current, 1);
      expect(r.v.master.current, 0, reason: 'a door day is not a streak day');
      expect(stayOffer(r.v), isTrue);
      expect([5, 10, 15], contains(doorBonus(sid)));
      expect(r.v.xpExtras.any((e) => e.$1.startsWith('Door bonus')), isTrue);
      await r.app.startSession(minutes: 25, source: 'work', meta: {'mode': 'normal', 'stay': true});
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      expect(r.v.xpExtras, contains(('Stayed after the door (double XP)', 100)));
      expect(r.v.master.current, 1);
      expect(stayOffer(r.v), isFalse);
      r.clock.advance(const Duration(days: 3));
      expect(doorStreak(r.v).current, 0, reason: 'no freezes: two missed days in a row break it');
    });
    test('a start from the alarm counts as a door', () async {
      final r = Rig();
      await r.app.log(Ev.onboarded);
      r.native.launchAction = {'action': 'start2', 'source': 'cue', 'startMs': r.clock.ms};
      await r.app.handleLaunchAction();
      r.clock.advance(const Duration(minutes: 2));
      await r.app.completeIfDue();
      expect(doorDays(r.v).length, 1);
    });
  });

  group('6.6 reminders', () {
    test('60 original lines in three tiers, none of them shaming', () {
      expect(lines.count, 60);
      expect(lines.tiers.keys, ['gentle', 'firm', 'relentless']);
      for (final l in lines.tiers.values.expand((x) => x)) {
        for (final bad in ['lazy', 'loser', 'pathetic', 'useless', 'shame', 'stupid', 'failure', 'disappoint', 'worthless']) {
          expect(l.toLowerCase(), isNot(contains(bad)), reason: l);
        }
      }
    });
    test('line follows the dial; 7 pm streak alert only while at risk; cap is 5 at most', () async {
      final r = Rig(streakMin: 25);
      expect(lines.tiers['firm'], contains(lines.pick(r.v, r.v.today)));
      await r.app.setPressure(0);
      r.clock.advance(const Duration(days: 2));
      expect(lines.tiers['gentle'], contains(lines.pick(r.v, r.v.today)));
      expect(buildReminders(r.v, tools, lines: lines).where((x) => x.id == 456), isEmpty, reason: 'no streak yet');
      await r.session(minutes: 25);
      r.clock.advance(const Duration(days: 1));
      final alert = buildReminders(r.v, tools, lines: lines).singleWhere((x) => x.id == 456);
      expect([alert.minute, alert.start], [19 * 60, true]);
      expect(alert.text, contains('25-minute rescue session'));
      await r.session(minutes: 25);
      expect(buildReminders(r.v, tools, lines: lines).where((x) => x.id == 456), isEmpty);
      await r.app.syncNative();
      expect(r.native.lastSync['remCap'], 5);
      await r.app.setSetting('remindersPerDay', '2');
      expect(r.native.lastSync['remCap'], 2);
      await r.app.setSetting('casualMode', '1');
      expect(r.native.lastSync['remCap'], 0, reason: 'casual mode: no nagging');
    });
  });

  group('6.7 daily rhythm', () {
    test('daily score: minutes 50, streak 20, plan 15, focus 15', () async {
      final r = Rig(streakMin: 25, clock: TestClock(DateTime.utc(2026, 11, 10, 20)));
      expect(dailyScore(r.v, r.v.today), 0);
      await r.app.setPlan('Open notes', 9 * 60);
      r.clock.setWall(2026, 11, 11, 9);
      await r.session(minutes: 25);
      expect(dailyScore(r.v, r.v.today), 25 + 20 + 15 + 15);
      await r.session(minutes: 25);
      expect(dailyScore(r.v, r.v.today), 100);
      await r.app.setKv('dailyTargetMinutes', '100');
      expect(dailyScore(r.v, r.v.today), 75);
    });
    test('tomorrow by rules: top task, never a time inside the sleep window; goal progress', () async {
      final r = Rig();
      expect(suggestTomorrow(r.v).task, r.v.nextStep);
      final p = await r.app.addRec(Kind.project, {'name': 'P'});
      await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Solve sheet 3', 'done': false, 'due': r.v.today + 2});
      await r.app.setKv('cueMinute', '120');
      final s = suggestTomorrow(r.v);
      expect([s.task, s.minute], ['Solve sheet 3', 7 * 60]);
      expect(goal(r.v), isNull);
      await r.app.setKv('goalText', 'Placements');
      await r.app.setKv('goalHours', '10');
      await r.session(minutes: 60);
      expect(goal(r.v)!.progress, closeTo(0.1, 1e-9));
    });
  });

  testWidgets('work screen: the door, then "stay" for double XP', (t) async {
    final r = Rig(streakMin: 25);
    await pumpTool(t, r, const WorkScreen());
    await t.ensureVisible(find.byKey(const Key('workDoor')));
    await t.tap(find.byKey(const Key('workDoor')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'the worst opening sentence ever');
    await t.tap(find.text('OPEN THE DOOR'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('02:00'), findsOneWidget);
    r.clock.advance(const Duration(minutes: 2));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('workStay')), findsOneWidget);
    await t.tap(find.byKey(const Key('workStay')));
    await t.pump(const Duration(milliseconds: 600));
    expect(r.v.active!.meta['stay'], isTrue);
    expect(r.v.active!.minutes, 25);
    await pumpTool(t, r, const SizedBox());
  });

  testWidgets('shutdown: score, three lines, tomorrow is set', (t) async {
    final r = Rig(streakMin: 25, clock: TestClock(DateTime.utc(2026, 11, 11, 20)));
    await r.session(minutes: 25);
    await pumpTool(t, r, const ShutdownScreen());
    expect(find.byKey(const Key('dayScore')), findsOneWidget);
    await t.enterText(find.byKey(const Key('shut-0')), 'Two sessions');
    await t.enterText(find.byKey(const Key('shut-2')), 'Open the DBMS file');
    await t.ensureVisible(find.byKey(const Key('shutSave')));
    await t.tap(find.byKey(const Key('shutSave')));
    await t.pump(const Duration(milliseconds: 300));
    expect(shutdownDone(r.v), isTrue);
    expect(r.v.tomorrowPlan!.task, 'Open the DBMS file');
    expect(find.byKey(const Key('shutdownDone')), findsOneWidget);
  });
}

void recoveryTests() {
  test('recovery challenge: three full days within five after a break, 100 XP once', () async {
    final r = Rig(streakMin: 25);
    await r.app.setKv('flag.53', '0');
    await r.session(minutes: 25);
    expect(recoveryChallenge(r.v), isNull);
    r.clock.advance(const Duration(days: 10)); // rest days and 3 freezes run out, then two misses break it
    expect(r.v.master.lastBreakDay, isNotNull);
    final c = recoveryChallenge(r.v)!;
    expect([c.have, c.need], [0, 3]);
    for (var i = 0; i < 3; i++) {
      await r.session(minutes: 25);
      r.clock.advance(const Duration(days: 1));
    }
    expect(recoveryChallenge(r.v)?.done, isTrue);
    expect(r.v.xpExtras, contains(('Recovery challenge done', 100)));
  });

  test('adaptive nudge: cue + 30 min at first, your best hour after 14 days, never before 04:00', () async {
    final r = Rig(streakMin: 25);
    await r.app.setKv('cueMinute', '${9 * 60}');
    expect(nudgeMinute(r.v), 9 * 60 + 30);
    await r.session(minutes: 25); // 10:00 session
    r.clock.advance(const Duration(days: 15));
    expect(nudgeMinute(r.v), 10 * 60);
  });
}
