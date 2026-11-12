import 'package:challenger_timer/core/extras.dart';
import 'package:challenger_timer/core/reminders.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('220 focus score, 221/222 deep work minutes and capped target', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.startSession(minutes: 25, meta: {'deep': true, 'place': 'library'});
    final sid = r.v.active!.sid;
    await r.app.pauseSession('door');
    await r.app.resumeSession();
    await r.app.log('tool', {'n': 92, 'sid': sid});
    r.clock.advance(const Duration(minutes: 25));
    await r.app.completeIfDue();
    expect(focusScore(r.v, sid), 80);
    expect(averageFocus(r.v), 80);
    expect(deepMinutes(r.v, day: r.v.today), 25);
    expect(r.v.type('session_done').single.payload['place'], 'library');
    await r.app.setKv('deepTarget', '999');
    expect(deepTarget(r.v), 240);
  });

  test('204 auto DND, 201/211/212 sync flags, 224/225 reminders', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    for (final k in ['autoDnd', 'blockInSession', 'unlockFriction', 'rem.224', 'rem.225']) {
      await r.app.setKv(k, '1');
    }
    await r.app.setKv('scrollHour', '19');
    await r.app.setKv('nightHour', '22');
    await r.session();
    expect(r.native.calls, containsAllInOrder(['dnd:true', 'dnd:false']));
    final s = r.native.lastSync;
    expect([s['blockInSession'], s['unlockFriction'], s['scrollFrom']], [true, true, 19 * 60]);
    final rem = fixedReminders(r.v);
    expect(rem.where((x) => x.title == 'Message check').map((x) => x.minute), [13 * 60, 19 * 60]);
    expect(rem.singleWhere((x) => x.id == 225).minute, 22 * 60);
  });

  testWidgets('203 strict lock hides STOP at first; 208 breathing counts down; 207 pickups show', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await r.app.setKv('strictMinutes', '5');
    await r.app.startSession(minutes: 25);
    await pumpTool(t, r, const TimerScreen());
    expect(find.byKey(const Key('strict')), findsOneWidget);
    expect(find.byKey(const Key('stop')), findsNothing);
    r.clock.advance(const Duration(minutes: 6));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('stop')), findsOneWidget);
    await pumpTool(t, r, const Scaffold(body: BreathTool(90)));
    await t.tap(find.byKey(const Key('breathStart')));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('88'), findsOneWidget);
    await t.pump(const Duration(seconds: 90));
    r.native.usageData = {'granted': true, 'pickups': 41, 'total': 200, 'apps': [{'label': 'Reels', 'minutes': 90}]};
    await pumpTool(t, r, const Scaffold(body: UsageTool(207)));
    await t.pump();
    expect(find.text('41'), findsOneWidget);
    await pumpTool(t, r, const SizedBox());
  });
}
