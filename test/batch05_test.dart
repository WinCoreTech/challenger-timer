import 'package:challenger_timer/core/deadlines.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/tools.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

Future<Rec> task(Rig r, String title, {int? dueIn, int est = 0}) async {
  final p = r.v.projects.isEmpty ? await r.app.addRec(Kind.project, {'name': 'Sem 5'}) : r.v.projects.first;
  return r.app.addRec(Kind.task,
      {'projectId': p.id, 'title': title, 'done': false, if (dueIn != null) 'due': r.v.today + dueIn, 'est': est});
}

void main() {
  test('101, 102, 117, 125: personal due date, sessions left, quota, start-by', () async {
    final r = Rig();
    final t = await task(r, 'OS assignment', dueIn: 12, est: 200);
    var m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.fakeDue, r.v.today + 10);
    expect(m.sessionsLeft, 8);
    expect(m.quota, 20);
    expect(m.startBy, r.v.today + 10 - 8, reason: '200 min at 25 a day needs 8 days');
    // Work on it: 50 minutes logged against the task.
    await r.app.startSession(minutes: 50, taskId: t.id);
    r.clock.advance(const Duration(minutes: 50));
    await r.app.completeIfDue();
    m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.done, 50);
    expect(m.sessionsLeft, 6);
    expect(m.quota, 15);
  });

  test('106 panic simulator and 118 visible rollover', () async {
    final r = Rig();
    final t = await task(r, 'Lab record', dueIn: 12, est: 300);
    var m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.panic().$1, 30);
    expect(m.panic().$2, 60, reason: 'waiting 5 of the 10 days doubles the daily load');
    r.clock.advance(const Duration(days: 5));
    m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.firstQuota, 30);
    expect(m.quota, 60, reason: 'the missed quota is spread over the days left');
  });

  test('107 pace, 108 neck level, 119 delay debt', () async {
    final r = Rig();
    final t = await task(r, 'Project report', dueIn: 12, est: 400);
    r.clock.advance(const Duration(days: 5));
    var m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.pace.$1, 0);
    expect(m.pace.$2, 0.5);
    expect(m.debt, 200);
    expect(m.neckLevel, isTrue, reason: '400 min left, 5 days at 25 min a day');
    expect(stats['debt']!(r.v).first, '200 min');
    expect(stats['neck']!(r.v).first, '1 at neck level');
    final rem = fixedReminders(r.v).where((x) => x.id == 108);
    expect(rem, isEmpty, reason: 'rank-gated until unlocked');
    await r.app.setKv('unlockAll', '1');
    expect(fixedReminders(r.v).where((x) => x.id == 108).single.start, isTrue);
    await r.app.putRec(r.v.rec(t.id)!.copy({'est': 100}));
    m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.neckLevel, isFalse);
  });

  test('103 and 113: backward plan with a draft-zero milestone at halfway', () async {
    final r = Rig();
    final t = await task(r, 'Seminar', dueIn: 22, est: 300);
    final ms = TaskMath(r.v, r.v.rec(t.id)!).milestones;
    expect(ms.map((m) => m.$1), [r.v.today + 5, r.v.today + 10, r.v.today + 15, r.v.today + 20, r.v.today + 22]);
    expect(ms[1].$2, startsWith('Draft zero'));
  });

  test('104 first touch and 105 day one', () async {
    final r = Rig();
    final t = await task(r, 'New assignment', dueIn: 10, est: 100);
    expect(TaskMath(r.v, r.v.rec(t.id)!).firstTouchOpen, isTrue);
    expect(stats['firstTouch']!(r.v).first, '1');
    await r.app.startSession(minutes: 5, taskId: t.id);
    r.clock.advance(const Duration(minutes: 5));
    await r.app.completeIfDue();
    final m = TaskMath(r.v, r.v.rec(t.id)!);
    expect(m.firstTouched, isTrue);
    expect(m.dayOne, isTrue);
    expect(stats['dayOne']!(r.v).first, '1 of 1');
    final late = await task(r, 'Ignored', dueIn: 10, est: 100);
    r.clock.advance(const Duration(days: 2));
    expect(TaskMath(r.v, r.v.rec(late.id)!).firstTouchOpen, isFalse, reason: 'the 24 hours passed');
  });

  test('111 decaying bonus and 112 early-bird multiplier', () async {
    expect(decayingBonus(0), 0);
    expect(decayingBonus(3), 45);
    expect(decayingBonus(30), 150);
    expect(earlyMultiplier(7), 3);
    expect(earlyMultiplier(0), 1);
    expect(earlyMultiplier(14), 3);
    final r = Rig();
    final t = await task(r, 'Early bird', dueIn: 7, est: 50);
    await r.app.startSession(minutes: 25, taskId: t.id);
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(r.v.xpExtras, contains(('Early-bird multiplier', 100)), reason: '25 min x 2 XP x (3 - 1)');
    await r.app.toggleTask(r.v.rec(t.id)!);
    expect(r.v.xpExtras, contains(('Early-finish bonus', 105)));
  });

  test('114 submission buffer, 115 load calendar, 116 collision warning', () async {
    final r = Rig();
    final a = await task(r, 'A', dueIn: 3, est: 50);
    await r.app.toggleTask(a);
    expect(submissionBuffer(r.v), (1, 1));
    for (final n in ['B', 'C', 'D']) {
      await task(r, n, dueIn: 15, est: 100);
    }
    final cal = loadCalendar(r.v);
    final busy = cal.where((w) => w.count > 0).single;
    expect(busy.count, 3);
    expect(busy.minutes, 300);
    expect(busy.collision, isTrue);
    expect(stats['load']!(r.v).join(' '), contains('Three or more land together'));
  });

  test('120 to 122: postponing records the reason and the count', () async {
    final r = Rig();
    final t = await task(r, 'Push me', dueIn: 5, est: 50);
    await r.app.postponeTask(r.v.rec(t.id)!, 2, 'fest week');
    final after = r.v.rec(t.id)!;
    expect(after.integer('due'), r.v.today + 7);
    expect(after.integer('postponed'), 1);
    expect(after.data['reasons'], ['fest week']);
    expect(r.v.toolEvents(120).single.payload['reason'], 'fest week');
  });

  testWidgets('task screen: maths panel, postpone needs a reason, third postpone forces a choice', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('t.109', '["Two all-nighters and a headache"]');
    final rec = await task(r, 'DBMS mini project', dueIn: 12, est: 200);
    await pumpTool(t, r, TaskScreen(rec.id));
    expect(find.byKey(const Key('taskMath')), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('FIRST TOUCH: START 5 MIN'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('postpone')), 300, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('postpone')));
    await t.pumpAndSettle();
    expect(find.textContaining('Two all-nighters'), findsOneWidget, reason: 'cost-of-delay note reappears');
    await t.tap(find.text('PUSH 2 DAYS'));
    await t.pumpAndSettle();
    expect(r.v.rec(rec.id)!.integer('postponed'), 0, reason: 'an empty reason is refused');
    await t.ensureVisible(find.byKey(const Key('postpone')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('postpone')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'fest week');
    await t.tap(find.text('PUSH 2 DAYS'));
    await t.pumpAndSettle();
    expect(r.v.rec(rec.id)!.integer('postponed'), 1);
    await r.app.postponeTask(r.v.rec(rec.id)!, 2, 'again');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('postpone')), 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const Key('postpone')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('postpone')));
    await t.pumpAndSettle();
    expect(find.text('SPLIT IT IN TWO SMALLER TASKS'), findsOneWidget);
    await t.tap(find.text('SPLIT IT IN TWO SMALLER TASKS'));
    await t.pumpAndSettle();
    expect(r.v.of(Kind.task).map((x) => x.str('title')), ['DBMS mini project (part 1)', 'DBMS mini project (part 2)']);
  });
}
