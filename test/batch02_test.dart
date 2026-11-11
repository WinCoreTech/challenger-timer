import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/core/rules.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('29 weekly streak: weeks that reach the target, open week never breaks it', () {
    final mon = dayOfDate(2026, 11, 9); // a Monday
    expect(weekdayOf(mon), 1);
    expect(weekOf(mon - 1), weekOf(mon) - 1);
    expect(weekOf(mon + 6), weekOf(mon));
    final days = {mon - 7, mon - 6, mon - 5, mon - 4, mon, mon + 1}; // last week 4, this week 2
    expect(weeklyStreak(days, mon + 1, 4), 1, reason: 'last week counted, this one still open');
    expect(doneThisWeek(days, mon + 1), 2);
    expect(weeklyStreak({...days, mon + 2, mon + 3}, mon + 3, 4), 2);
    expect(weeklyStreak(days, mon + 8, 4), 0, reason: 'a whole week missed the target');
  });

  test('30 in-day chain', () async {
    final r = Rig();
    await r.session();
    r.clock.advance(const Duration(minutes: 5));
    await r.session();
    expect(inDayChain(r.v), 2);
    r.clock.advance(const Duration(minutes: 40));
    await r.session();
    expect(inDayChain(r.v), 2, reason: 'the gap was too long, a new chain of 1 started');
  });

  test('33 flame level steps', () {
    expect(flameLevel(0), 0);
    expect(flameLevel(3), closeTo(1 / 6, 1e-9));
    expect(flameLevel(29), closeTo(3 / 6, 1e-9));
    expect(flameLevel(100), 1);
  });

  test('35 before-noon, 37 plan-kept, 41 upload streak sources', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 20)));
    await r.app.setPlan('Open notebook', 9 * 60);
    r.clock.setWall(2026, 11, 12, 9, 15);
    await r.session();
    await r.app.saveProof(type: 'text', value: 'x');
    expect(beforeNoonDays(r.v), {r.v.today});
    expect(planKeptDays(r.v), {r.v.today});
    expect(stats['upload']!(r.v).first, '1');
    r.clock.setWall(2026, 11, 13, 15);
    await r.session();
    expect(beforeNoonDays(r.v).length, 1);
    expect(planKeptDays(r.v).length, 1);
  });

  test('36 early submission needs a full day of margin', () async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'Lab'});
    final early = await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Record', 'done': false, 'due': r.v.today + 3});
    final late = await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Viva', 'done': false, 'due': r.v.today});
    await r.app.toggleTask(early);
    await r.app.toggleTask(late);
    expect(earlySubmissions(r.v).map((t) => t.str('title')), ['Record']);
  });

  test('38 wake-time streak counts taps within 30 minutes of target', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 7, 20)));
    await r.app.log(Ev.tool, {'n': 38});
    r.clock.setWall(2026, 11, 12, 8, 10);
    await r.app.log(Ev.tool, {'n': 38}); // too late for a 7:00 target
    expect(wakeOnTimeDays(r.v).length, 1);
    await r.app.setKv('wakeTarget', '8');
    expect(wakeOnTimeDays(r.v).length, 2);
  });

  test('43 stacking bonus pays once per qualifying day', () async {
    final r = Rig();
    final a = await r.app.addRec(Kind.habit, {'name': 'A'});
    final b = await r.app.addRec(Kind.habit, {'name': 'B'});
    await r.app.tickHabit(a.id);
    await r.app.tickHabit(b.id);
    expect(r.v.xp.extra, 0, reason: 'two streaks is not three');
    await r.session();
    expect(r.v.xp.extra, xpStackBonus);
    await r.app.setKv('flag.43', '0');
    expect(r.v.xp.extra, 0);
  });

  test('46 odd milestones pay hidden XP once the streak has reached them', () async {
    final r = Rig();
    for (var i = 0; i < 11; i++) {
      await r.session();
      r.clock.advance(const Duration(days: 1));
    }
    expect(r.v.master.longest, 11);
    expect(r.v.xpExtras, contains(('Surprise at 11 days', 111)));
    expect(r.v.xpExtras.any((e) => e.$1.contains('23')), isFalse);
    expect(achievements.where((a) => a.id == 'odd_11').single.earned(r.v.metrics), isTrue);
  });

  test('47 streak wager: won after 7 clean days, lost on an uncovered miss', () async {
    final r = Rig();
    await r.session();
    await r.app.log(Ev.tool, {'n': 47, 'amount': 100});
    expect(wagers(r.v).single.state, 'open');
    for (var i = 0; i < 6; i++) {
      r.clock.advance(const Duration(days: 1));
      await r.session();
    }
    expect(wagers(r.v).single.state, 'won');
    expect(r.v.xpExtras, contains(('Streak wager won', 100)));

    final l = Rig();
    await l.session();
    await l.app.log(Ev.tool, {'n': 47, 'amount': 100});
    l.clock.advance(const Duration(days: 3)); // two misses: both frozen
    expect(wagers(l.v).single.state, 'open', reason: 'freezes protect the wager');
    l.clock.advance(const Duration(days: 1)); // third miss, no freeze left
    expect(wagers(l.v).single.state, 'lost');
    expect(l.v.xpTotal, greaterThanOrEqualTo(0));
  });

  test('48 rest days never count as a miss', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 14, 10))); // Saturday
    await r.session();
    await r.app.setKv('restDays', '7');
    r.clock.setWall(2026, 11, 16, 10); // Monday; Sunday skipped
    expect(r.v.master.current, 1);
    expect(r.v.master.freezesLeft, 2, reason: 'no freeze spent on a rest day');
  });

  test('49 time window', () {
    const h = Rec(id: 'h', kind: Kind.habit, created: 0, data: {'from': 360, 'to': 540});
    expect(inWindow(h, 400), isTrue);
    expect(inWindow(h, 600), isFalse);
    const night = Rec(id: 'n', kind: Kind.habit, created: 0, data: {'from': 1320, 'to': 60});
    expect(inWindow(night, 1400), isTrue);
    expect(inWindow(night, 30), isTrue);
    expect(inWindow(night, 720), isFalse);
    expect(inWindow(const Rec(id: 'x', kind: Kind.habit, created: 0), 5), isTrue);
  });

  testWidgets('28 tiny version button keeps the streak; 50 graduation moves the habit', (t) async {
    final r = Rig();
    await r.app.log(Ev.onboarded);
    final h = await r.app.addRec(Kind.habit, {'name': 'Read', 'tiny': 'Read one line'});
    await pumpTool(t, r, const StreaksScreen());
    await t.ensureVisible(find.byKey(Key('tiny-${h.id}')));
    await t.tap(find.byKey(Key('tiny-${h.id}')));
    await t.pump();
    expect(r.v.habitStreak(h.id).current, 1);
    expect(r.v.type(Ev.habitTick).single.payload['tiny'], isTrue);
    expect(find.byKey(const Key('track66')), findsOneWidget);

    await pumpTool(t, r, HabitScreen(h.id));
    await t.tap(find.byKey(const Key('weekly-4')));
    await t.pump();
    expect(r.v.rec(h.id)!.integer('weekly'), 4);
    await t.ensureVisible(find.byKey(const Key('graduate')));
    await t.tap(find.byKey(const Key('graduate')));
    await t.pump();
    expect(r.v.habits, isEmpty);
    expect(r.v.maintained.single.id, h.id);
  });
}
