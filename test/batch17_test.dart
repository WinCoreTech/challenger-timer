import 'package:challenger_timer/core/analytics.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/core/study.dart';
import 'package:challenger_timer/ui/home.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('404 spaced repetition ladder: 1, 3, 7, 21 days; a miss returns tomorrow', () {
    var c = const Rec(id: 'c', kind: 'card', created: 0, data: {'step': 0, 'next': 10});
    final gaps = <int>[];
    var today = 10;
    for (var i = 0; i < 5; i++) {
      final r = reviewed(c, today, correct: true);
      gaps.add((r['next']! as int) - today);
      today = r['next']! as int;
      c = c.copy(r);
    }
    expect(gaps, [1, 3, 7, 21, 21]);
    final miss = reviewed(c, today, correct: false);
    expect([miss['step'], miss['next']], [0, today + 1]);
  });

  test('410 exam plan and 414 attendance maths', () {
    expect(examPlan(['U1', 'U2', 'U3', 'U4', 'U5'], 3), [['U1', 'U2'], ['U3', 'U4'], ['U5']]);
    expect(examPlan(['U1'], 3), [['U1'], <String>[], <String>[]]);
    expect(attendance(30, 40), (75, 0));
    expect(attendance(36, 40), (90, 8));
    expect(attendance(20, 40), (50, -40));
    expect(attendance(0, 0), (100, 0));
  });

  test('427 day score, 430 trend, 434 planned ratio, 445 timeline, 450 CSV', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 10, 20)));
    expect(dayScore(r.v, r.v.today), 0);
    await r.app.setPlan('Open notes', 9 * 60);
    r.clock.setWall(2026, 11, 11, 9);
    await r.session(minutes: 25);
    await r.app.saveProof(type: 'text', value: 'He said "done"');
    expect(dayScore(r.v, r.v.today), 85);
    expect(weeklyMinutes(r.v), [0, 0, 0, 25]);
    expect(plannedVsDone(r.v), (1, 1));
    expect(milestoneTimeline(r.v).map((m) => m.$2), ['First session finished', 'First proof saved']);
    final csv = eventsCsv(r.v);
    expect(csv.split('\n').first, 'id,type,utc_ms,offset_min,day,date,payload');
    expect(csv, contains('session_done'));
    expect(csv, contains('""kind"":""text""'), reason: 'quotes are escaped');
  });

  test('446 insights only say what the log supports', () async {
    final r = Rig();
    expect(insights(r.v).single, startsWith('Not enough sessions yet'));
    for (var i = 0; i < 3; i++) {
      r.clock.setWall(2026, 11, 12 + i, 9);
      await r.session(minutes: 50);
      r.clock.setWall(2026, 11, 12 + i, 16);
      await r.session(minutes: 10);
    }
    final lines = insights(r.v);
    expect(lines, contains('Your sessions run 400% longer before 11 am.'));
    expect(lines.any((l) => l.contains('strongest day')), isTrue);
  });

  test('453-459, 465, 468, 473 reminders', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 8)));
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('cueMinute', '${9 * 60}');
    await r.app.addRec('t465', {'text': 'You always feel better after starting.', 'done': false});
    var rem = {for (final x in buildReminders(r.v, tools)) x.id: x};
    expect(rem[453]!.minute, 9 * 60 + 30);
    expect(rem[453]!.skipIfWorked, isTrue);
    expect(rem.containsKey(456), isFalse, reason: 'no streak to protect yet');
    expect(rem[459]!.minute, 21 * 60);
    expect(rem[465]!.text, 'You always feel better after starting.');
    expect(rem[473]!.days, '0000001');
    await r.session();
    await r.app.setPlan('Open page 3', 9 * 60);
    final wd = DateTime.utc(2026, 11, 11).weekday;
    await r.app.addRec('class', {'name': 'OS', 'wd': wd, 'from': 15 * 60, 'to': 19 * 60});
    rem = {for (final x in buildReminders(r.v, tools)) x.id: x};
    expect(rem.containsKey(459), isFalse, reason: 'tomorrow is planned');
    expect(rem.containsKey(456), isFalse, reason: '6 pm falls inside a lecture today');
    expect(rem.containsKey(465), isFalse, reason: '4 pm falls inside a lecture today');
    expect(rem.containsKey(453), isTrue);
  });

  test('462 tone picker never blames; 475 core words translate', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    for (final line in toneLines.values) {
      for (final bad in ['lazy', 'fail', 'pathetic', 'shame', 'useless', 'again?']) {
        expect(line.toLowerCase(), isNot(contains(bad)));
      }
    }
    await r.app.setKv('toneN', '3');
    expect(homeLine(r.v), toneLines['sergeant']);
    expect(tr(r.v, 'START'), 'START');
    await r.app.setKv('langN', '2');
    expect(tr(r.v, 'START'), 'शुरू करें');
    await r.app.setKv('langN', '3');
    expect(tr(r.v, 'START'), 'सुरू करा');
  });
}
