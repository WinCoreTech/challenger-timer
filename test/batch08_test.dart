import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/planning.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('179/180 timetable and free slots', () async {
    final r = Rig();
    final wd = weekdayOf(r.v.today);
    await r.app.addRec('class', {'name': 'OS', 'wd': wd, 'from': 9 * 60, 'to': 10 * 60});
    await r.app.addRec('class', {'name': 'DBMS', 'wd': wd, 'from': 10 * 60 + 10, 'to': 12 * 60});
    await r.app.addRec('class', {'name': 'Lab', 'wd': wd % 7 + 1, 'from': 14 * 60, 'to': 16 * 60});
    expect(freeSlots(r.v, wd), [(8 * 60, 9 * 60), (12 * 60, 21 * 60)], reason: 'the 10-minute gap is too short');
    expect(inClass(r.v, r.clock()), isFalse);
    r.clock.advance(const Duration(minutes: 30)); // 10:30
    expect(inClass(r.v, r.clock()), isTrue);
  });

  test('185 weekly targets, 195 peak hour, 200 scoreboard, 191 plan vs actual', () async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'DSA', 'weekly': 3});
    expect(peakHour(r.v), isNull);
    await r.app.startSession(minutes: 25, projectId: p.id);
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(weeklyTargets(r.v), [('DSA', 1, 3)]);
    expect(peakHour(r.v), 10);
    final s = scoreboard(r.v);
    expect([s['Starts'], s['Sessions finished'], s['Minutes'], s['Days shown up']], [1, 1, 25, 1]);
    final pa = planVsActual(r.v).last;
    expect([pa.$2, pa.$3], [null, 10 * 60]);
    expect(stats['capacity']!(r.v).first, '25 min a day');
  });

  test('192/193 move to tomorrow is counted', () async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'P'});
    final t = await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Print form', 'done': false});
    for (var i = 0; i < 3; i++) {
      await r.app.moveToTomorrow(r.v.rec(t.id)!);
    }
    expect(r.v.rec(t.id)!.integer('moved'), 3);
    expect(r.v.rec(t.id)!.integer('due'), r.v.today + 1);
  });
}
