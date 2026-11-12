import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/flags.dart';
import 'package:challenger_timer/core/game.dart';
import 'package:challenger_timer/core/pressure.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/rules.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

Future<Rig> rig(int level) async {
  final r = Rig();
  await r.app.setKv('unlockAll', '1');
  await r.app.setKv('pressure', Dial(level).encode());
  return r;
}

void main() {
  group('701 pressure dial', () {
    test('defaults to Gentle; nothing Firm or Relentless is on by default', () {
      final r = Rig();
      expect(dialOf(r.v).effective(r.clock.ms), Pressure.gentle.index);
      for (final n in [...firmFeatures, ...relentlessFeatures]) {
        expect(r.v.flagOn(n), isFalse, reason: 'feature $n needs the dial raised');
      }
      expect(relentlessFeatures, containsAll([633, 637, 641]));
    });
    test('raising is instant, lowering takes 24 hours and can be cancelled', () async {
      final r = Rig();
      await r.app.setKv('unlockAll', '1');
      await r.app.setPressure(2);
      expect(r.v.on(633), isTrue);
      await r.app.setPressure(0);
      expect(dialOf(r.v).pending(r.clock.ms), isTrue);
      expect(r.v.on(633), isTrue, reason: 'still Relentless during the wait');
      r.clock.advance(const Duration(hours: 23, minutes: 59));
      expect(r.v.on(634), isTrue);
      r.clock.advance(const Duration(minutes: 1));
      expect(r.v.on(633), isFalse);
      expect(r.v.on(634), isFalse);
      expect(r.v.on(602), isTrue, reason: 'Gentle features stay');
      await r.app.setPressure(1);
      await r.app.setPressure(0);
      await r.app.cancelPressureChange();
      r.clock.advance(const Duration(days: 2));
      expect(dialOf(r.v).effective(r.clock.ms), 1);
    });
    test('Version 1 is untouched by the dial: the bonus stays a flat 100 on Gentle', () async {
      final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 15)));
      await r.session();
      r.clock.advance(const Duration(days: 1));
      expect(r.v.xpExtras.any((e) => e.$1.startsWith('Deposit')), isFalse);
      expect(r.v.xp.bonus, 200);
    });
  });

  test('601 daily deposit drains until the first start (Firm)', () async {
    final r = await rig(1);
    r.clock.setWall(2026, 11, 11, 15); // half the day is gone (3 am to 3 am)
    await r.session();
    expect(depositKept(r.v, r.v.today), 50);
    r.clock.advance(const Duration(days: 1));
    expect(r.v.xpExtras, contains(('Deposit drained before first start', -50)));
  });

  test('616 falling multiplier, 682 double hour, 684 five-minute offer', () async {
    final r = await rig(1);
    await r.app.setKv('wakeHour', '7');
    expect(fallingMultiplier(r.v, Moment(DateTime.utc(2026, 1, 1, 7).millisecondsSinceEpoch, 0)), 3);
    expect(fallingMultiplier(r.v, Moment(DateTime.utc(2026, 1, 1, 11).millisecondsSinceEpoch, 0)), 2);
    expect(fallingMultiplier(r.v, Moment(DateTime.utc(2026, 1, 1, 20).millisecondsSinceEpoch, 0)), 1);
    final h = doubleHour(r.v.today);
    expect(h, inInclusiveRange(8, 21));
    r.clock.setWall(2026, 11, 11, h, 5);
    await r.app.log(Ev.appOpen);
    await r.session();
    final x = {for (final e in r.v.xpExtras) e.$1: e.$2};
    expect(x['Double hour'], xpStart);
    expect(x['Started within five minutes of opening'], 10);
    expect(x.containsKey('Early-in-the-day multiplier'), h < 15);
    expect(buildReminders(r.v, tools).any((m) => m.id == 682 && m.minute == h * 60), isTrue);
  });

  test('603 rank trial, 624 insurance, 615 expiring coins', () async {
    final r = await rig(1);
    await r.session();
    await r.app.log(Ev.tool, {'n': 603});
    expect(rankTrialLive(r.v), isTrue);
    expect(shownRank(r.v).index, r.v.rank.index + 1);
    r.clock.advance(const Duration(days: 1));
    await r.session();
    r.clock.advance(const Duration(days: 1));
    await r.session();
    r.clock.advance(const Duration(days: 1));
    expect(r.v.xpExtras, contains(('Rank trial kept', 100)));
    await r.app.log(Ev.tool, {'n': 0, 'xp': 0});
    final before = r.v.master.freezesLeft;
    for (var i = 0; i < 20; i++) {
      await r.session();
    }
    expect(coins(r.v), greaterThanOrEqualTo(20));
    final c = coins(r.v);
    await r.app.log(Ev.tool, {'n': 624, 'coins': 20});
    expect(coins(r.v), c - 20);
    expect(r.v.master.freezesLeft, before + 1);
  });

  test('605 streak hours, 606 loss preview, 608 plant, 622 diary, 623 golden, 685 jackpot', () async {
    final r = await rig(0);
    for (var i = 0; i < 3; i++) {
      await r.session(minutes: 20);
    }
    expect(goldenDays(r.v), {r.v.today});
    expect(streakMinutes(r.v), 60);
    expect(jackpot(r.v), 10);
    expect(plantState(r.v), 0);
    expect(lossPreview(r.v).single, contains('Nothing is at risk'));
    r.clock.advance(const Duration(days: 1));
    expect(plantState(r.v), 1);
    final loss = lossPreview(r.v).join(' ');
    expect(loss, contains('100 XP bonus'));
    expect(loss, contains('freezes'));
    expect(loss, contains('jackpot pool of 10 XP'));
    r.clock.advance(const Duration(days: 2));
    expect(plantState(r.v), 2);
    expect(jackpot(r.v), 0);
    expect(pressureStats['diary']!(r.v).where((l) => l.contains('(blank page)')).length, 13);
  });

  test('627/644/650 promises, 640 no-shows, 645 on-cue label, 646 days since zero', () async {
    final r = await rig(0);
    await r.app.setKv('cueMinute', '${10 * 60}');
    await r.app.addRec('t627', {'a': ['7 pm'], 'day': r.v.today});
    await r.app.addRec('t639', {'a': ['DSA'], 'day': r.v.today, 'minute': 600});
    await r.session();
    r.clock.advance(const Duration(days: 1));
    await r.session();
    r.clock.advance(const Duration(days: 1));
    expect(promises(r.v), (1, 1));
    expect(nextPromiseMinutes(r.v), 3);
    expect(attendanceRecord(r.v), (1, 1));
    expect(onCueStarts(r.v), 2);
    expect(daysSinceZero(r.v), 2);
  });

  test('676-681, 687-691 curiosity hooks open only by working', () async {
    final r = await rig(0);
    expect(storySoFar(r.v), isEmpty);
    expect(piecesRevealed(r.v, 30), 0);
    expect(toFifthChest(r.v), 5);
    for (var i = 0; i < 5; i++) {
      await r.session();
      await r.app.saveProof(type: 'text', value: 'x');
    }
    expect(storySoFar(r.v).length, 5);
    expect(piecesRevealed(r.v, 30), 5);
    final x = {for (final e in r.v.xpExtras) e.$1: e.$2};
    expect(x['Fifth-session chests'], 20);
    expect(x['Reward spins'], inInclusiveRange(25, 125));
    expect(hiddenLines, contains(hiddenLine('abc')));
    expect(hiddenLine('abc'), hiddenLine('abc'));
    expect(spinFor('abc'), inInclusiveRange(5, 25));
    final rare = [for (var i = 0; i < 3000; i++) 's$i'].where(legendary).length;
    expect(rare, inInclusiveRange(10, 60));
    expect(weekdaySet(r.v).length, 1);
    final ladder = pressureStats['ladder']!(r.v);
    expect(ladder.last, endsWith('???'), reason: 'far ranks stay secret');
    expect(story.length, 12);
  });

  test('633 auto-start is never synced inside the sleep window; 637/641/697 sync', () async {
    final r = await rig(2);
    await r.app.setKv('autoStart', '1');
    await r.app.setKv('sticky', '1');
    await r.app.setKv('cueMinute', '${9 * 60}');
    await r.app.switchOn('sw.ulysses');
    await r.app.setKv('vaultUntil', '${r.clock.ms + 3 * msPerDay}');
    await r.app.syncNative();
    var s = r.native.lastSync;
    expect([s['autoStart'], s['sticky'], s['lockFrom'], s['lockTo'], s['vaultUntil']],
        [true, true, 22 * 60, 6 * 60, r.clock.ms + 3 * msPerDay]);
    await r.app.setKv('bedHour', '23');
    await r.app.setKv('wakeHour', '10');
    await r.app.syncNative();
    expect(r.native.lastSync['autoStart'], isFalse, reason: 'the 9:00 cue is inside the sleep window');
    await r.app.switchRequestOff('sw.ulysses');
    await r.app.syncNative();
    expect(r.native.lastSync['lockFrom'], 22 * 60, reason: 'the lock stays for 24 hours');
    await r.app.setPressure(0);
    r.clock.advance(const Duration(hours: 25));
    await r.app.syncNative();
    s = r.native.lastSync;
    expect([s['autoStart'], s['lockFrom'], s['vaultUntil'], s['sticky']], [false, null, 0, false]);
  });

  test('638 permission guard texts the buddy once when a permission disappears', () async {
    final r = await rig(0);
    await r.app.setKv('name', 'Winzo');
    await r.app.setKv('buddyPhone', '+911');
    r.native.permissions.addAll({'sms': true, 'usage': true, 'overlay': true, 'notifications': true});
    await r.app.permissionGuard();
    expect(r.native.sms, isEmpty);
    r.native.permissions['usage'] = false;
    await r.app.permissionGuard();
    await r.app.permissionGuard();
    expect(r.native.sms.single, contains('Winzo switched off a permission'));
  });

  testWidgets('634/635/636 early stop on Firm: honest label, 30-second wait, typed sentence', (t) async {
    final r = await rig(1);
    await r.app.startSession(minutes: 25);
    await pumpTool(t, r, const TimerScreen());
    await t.tap(find.byKey(const Key('stop')));
    await t.pumpAndSettle();
    expect(find.text('I CHOOSE TO DELAY MY GOAL'), findsOneWidget);
    await t.tap(find.text('I CHOOSE TO DELAY MY GOAL'));
    await t.pump(const Duration(seconds: 1));
    expect(t.widget<FilledButton>(find.byKey(const Key('skipConfirm'))).onPressed, isNull);
    await t.pump(const Duration(seconds: 31));
    await t.tap(find.byKey(const Key('skipConfirm')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'whatever');
    await t.tap(find.text('STOP').last);
    await t.pumpAndSettle();
    expect(r.v.active, isNotNull, reason: 'wrong sentence: the session keeps running');
    await pumpTool(t, r, const SizedBox());
  });

  testWidgets('on Gentle an early stop is a plain STOP; dial tool shows the pending change', (t) async {
    final r = await rig(0);
    await r.app.startSession(minutes: 25);
    await pumpTool(t, r, const TimerScreen());
    await t.tap(find.byKey(const Key('stop')));
    await t.pumpAndSettle();
    expect(find.text('I CHOOSE TO DELAY MY GOAL'), findsNothing);
    await t.tap(find.text('STOP').last);
    await t.pumpAndSettle();
    expect(r.v.active, isNull);
    await r.app.setPressure(1);
    await r.app.setPressure(0);
    await pumpTool(t, r, const Scaffold(body: SingleChildScrollView(child: PressureTool(701))));
    expect(find.byKey(const Key('dialPending')), findsOneWidget);
    expect(find.textContaining('Lowering to GENTLE in 24h 00m'), findsOneWidget);
    await pumpTool(t, r, const SizedBox());
  });
}
