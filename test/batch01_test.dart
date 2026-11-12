import 'dart:math';

import 'package:challenger_timer/core/analytics.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/tools.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/toolbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Future<void> pumpTool(WidgetTester t, Rig r, Widget child) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  await t.pumpWidget(UncontrolledProviderScope(container: r.container, child: MaterialApp(home: child)));
  await t.pump();
}

void main() {
  group('feature flags', () {
    test('Version 1 is always on; extras obey flag, rank and Simple mode', () async {
      final r = Rig();
      expect(r.v.on(1), isTrue);
      expect(r.v.on(23), isTrue, reason: 'built, rank 0, on by default');
      await r.app.setKv('flag.23', '0');
      expect(r.v.on(23), isFalse);
      await r.app.setKv('flag.23', null);
      await r.app.setKv(K.simpleMode, '1');
      expect(r.v.on(23), isFalse, reason: 'Simple mode hides everything outside Version 1');
      expect(r.v.on(1), isTrue);
      expect(r.v.on(702 + 1), isFalse, reason: 'unknown feature');
    });
    test('every feature has a flag entry and every built one a note', () {
      expect(catalog.all.length, 702);
      expect(catalog.all.every((f) => f.on), isTrue);
      expect(catalog.all.where((f) => f.v1).length, 19);
    });
    test('every tool definition is valid and points at a built feature', () {
      for (final t in tools.values) {
        expect(toolKinds, contains(t.kind), reason: 'tool ${t.n}');
        expect(catalog[t.n]!.built, isTrue, reason: 'tool ${t.n} has no status line');
        expect(t.title, isNotEmpty);
        if (t.kind == 'stat') {
          expect(stats.containsKey(t.stat) || analyticsStats.containsKey(t.stat), isTrue, reason: 'stat ${t.stat}');
        }
        if (t.kind == 'check') expect(t.items, isNotEmpty);
        if (t.kind == 'toggle' || t.kind == 'dayflag') expect(t.setKey, isNotEmpty);
      }
    });
  });

  testWidgets('every tool screen renders without errors', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.session();
    for (final def in tools.values) {
      await pumpTool(t, r, ToolScreen(def.n));
      expect(find.text(def.title.toUpperCase()), findsOneWidget, reason: 'tool ${def.n}');
      expect(t.takeException(), isNull, reason: 'tool ${def.n}');
    }
  });

  test('3 just-open streak counts days opened before the chosen hour', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 8)));
    await r.app.log(Ev.appOpen);
    r.clock.setWall(2026, 11, 12, 9, 30);
    await r.app.log(Ev.appOpen);
    r.clock.setWall(2026, 11, 13, 14);
    await r.app.log(Ev.appOpen); // too late
    expect(openedEarlyDays(r.v).length, 2);
    expect(stats['openStreak']!(r.v).first, '2', reason: 'today still open, streak pending');
    await r.app.setKv('openBy', '9');
    expect(openedEarlyDays(r.v).length, 1);
  });

  test('15 bad-day bar: the door becomes 1 minute for today only', () async {
    final r = Rig();
    expect(r.v.doorMinutes, 2);
    await r.app.setKv('badDay', '${r.v.today}');
    expect(r.v.doorMinutes, 1);
    await r.app.startSession();
    r.clock.advance(const Duration(minutes: 1));
    expect(await r.app.completeIfDue(), isTrue);
    expect(r.v.master.current, 1, reason: 'one minute is a full win on a bad day');
    r.clock.advance(const Duration(days: 1));
    expect(r.v.doorMinutes, 2);
  });

  test('18 voice start parser', () {
    final projects = [
      const Rec(id: 'p1', kind: Kind.project, created: 1, data: {'name': 'DSA'}),
      const Rec(id: 'p2', kind: Kind.project, created: 2, data: {'name': 'OS notes'}),
    ];
    var c = parseVoice('Start five minutes on DSA', projects)!;
    expect([c.minutes, c.projectId], [5, 'p1']);
    c = parseVoice('start 25 minutes for os', projects)!;
    expect([c.minutes, c.projectId], [25, 'p2']);
    c = parseVoice('begin', projects)!;
    expect([c.minutes, c.projectId], [2, null]);
    expect(parseVoice('start one hour', projects)!.minutes, 60);
    expect(parseVoice('start twenty five minutes', projects)!.minutes, 25);
    expect(parseVoice('what is the weather', projects), isNull);
  });

  test('14 dice start picks only among real tasks', () async {
    final r = Rig();
    expect(diceOptions(r.v).single, r.v.nextStep);
    final p = await r.app.addRec(Kind.project, {'name': 'DSA'});
    for (final t in ['Solve problem 1', 'Read chapter 2', 'Draw the graph', 'Fourth task']) {
      await r.app.addRec(Kind.task, {'projectId': p.id, 'title': t, 'done': false});
      r.clock.advance(const Duration(seconds: 1));
    }
    final options = diceOptions(r.v);
    expect(options, ['Solve problem 1', 'Read chapter 2', 'Draw the graph']);
    expect(options, contains(rollDice(options, Random(7))));
  });

  test('24 starting-delay meter and 25 no-zero day', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 9, 40)));
    await r.app.setKv(K.cueMinute, '${9 * 60}');
    expect(startDelay(r.v), isNull);
    expect(nonZeroDays(r.v), isEmpty);
    await r.session(); // started 40 min after the 09:00 cue
    expect(startDelay(r.v), 40);
    r.clock.setWall(2026, 11, 12, 8, 30); // early start counts as zero delay
    await r.session();
    expect(startDelay(r.v), 20);
    expect(nonZeroDays(r.v).length, 2);
    expect(stats['noZero']!(r.v).first, 'Not a zero');
    expect(consistency(r.v), 7); // 2 of 30 days
  });

  test('6 if-then plans become reminders with a start button, only while the flag is on', () async {
    final r = Rig();
    await r.app.addRec('t6', {'a': ['I finish dinner', 'I open the app'], 'minute': 20 * 60 + 30, 'day': r.v.today});
    var rem = buildReminders(r.v, tools);
    expect(rem.single.minute, 20 * 60 + 30);
    expect(rem.single.text, 'I finish dinner → I open the app');
    expect(rem.single.start, isTrue);
    await r.app.syncNative();
    expect((r.native.lastSync['reminders'] as List).single['minute'], 20 * 60 + 30);
    await r.app.setKv('flag.6', '0');
    rem = buildReminders(r.v, tools);
    expect(rem, isEmpty);
  });

  testWidgets('4 five-second launch counts down and then starts', (t) async {
    final r = Rig();
    late BuildContext ctx;
    bool? result;
    await pumpTool(t, r, Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    fiveSecondLaunch(ctx).then((v) => result = v);
    await t.pump();
    expect(find.text('5'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('3'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('9 start ritual: the start button unlocks after one breath', (t) async {
    final r = Rig();
    await pumpTool(t, r, const RitualScreen());
    expect(r.native.calls, contains('tone'));
    expect(t.widget<FilledButton>(find.byKey(const Key('ritualStart'))).onPressed, isNull);
    await t.pump(const Duration(seconds: 9));
    expect(t.widget<FilledButton>(find.byKey(const Key('ritualStart'))).onPressed, isNotNull);
    await t.tap(find.byKey(const Key('ritualToggle')));
    await t.pump();
    expect(r.v.kv['ritual'], '1');
  });

  testWidgets('generic tools: log, toggle and dayflag write what they should', (t) async {
    final r = Rig();
    await pumpTool(t, r, const ToolScreen(7));
    await t.enterText(find.byKey(const Key('tool-field-0')), 'brushing teeth');
    await t.enterText(find.byKey(const Key('tool-field-1')), 'open the book');
    await t.tap(find.byKey(const Key('tool-add')));
    await t.pumpAndSettle();
    expect(r.v.toolRecs(tools[7]!).single.data['a'], ['brushing teeth', 'open the book']);
    expect(find.textContaining('brushing teeth'), findsOneWidget, reason: 'in the history; the field is cleared');

    await pumpTool(t, r, const ToolScreen(21));
    await t.tap(find.byKey(const Key('tool-toggle')));
    await t.pump();
    expect(r.native.lastSync['chargeCue'], isTrue);

    await pumpTool(t, r, const ToolScreen(15));
    await t.tap(find.byKey(const Key('tool-toggle')));
    await t.pump();
    expect(r.v.badDay, isTrue);
  });
}
