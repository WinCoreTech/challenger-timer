import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/tools.dart';
import 'package:challenger_timer/ui/toolbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('share templates fill in real numbers only', () async {
    final r = Rig();
    await r.app.setKv('name', 'Winzo');
    await r.session();
    final text = fillTemplate(tools[343]!.body, r.v, ['Linked lists']);
    expect(text, startsWith('Day 1: Linked lists. 1 sessions, 2 minutes.'));
    expect(fillTemplate(tools[336]!.body, r.v, ['finish unit 3', 'Friday', 'buy samosas']),
        'Commitment from Winzo: I promise to finish unit 3 by Friday. If I miss, I will buy samosas. Please hold me to it.');
  });

  test('needs-backend tools say they are not connected and show no numbers', () {
    for (final n in [328, 329, 330, 332, 333, 334, 335, 344, 383]) {
      expect(catalog[n]!.status, 'needs-backend');
      expect(tools[n]!.body, startsWith('Not connected.'));
      expect(RegExp(r'\d').hasMatch(tools[n]!.body), isFalse, reason: 'no invented figures in tool $n');
    }
  });

  test('359 early session badge, 365 pareto, 395 compounding', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 11, 11, 6, 30)));
    final p = await r.app.addRec('project', {'name': 'DSA'});
    await r.app.startSession(minutes: 60, projectId: p.id);
    r.clock.advance(const Duration(minutes: 60));
    await r.app.completeIfDue();
    await r.app.saveProof(type: 'text', value: 'x');
    expect(achievements.singleWhere((a) => a.id == 'early_bird').earned(r.v.metrics), isTrue);
    expect(stats['pareto']!(r.v).first, 'DSA');
    await r.app.setKv('gradYear', '2027');
    final c = stats['compound']!(r.v);
    expect(c.first, endsWith('hours'));
    expect(int.parse(c.first.split(' ').first), greaterThan(100), reason: '1 hour a day until June 2027');
  });

  testWidgets('share tool sends the filled text through the share sheet', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await pumpTool(t, r, const ToolScreen(342));
    await t.enterText(find.byKey(const Key('tool-field-0')), 'two minutes every day');
    await t.pump();
    expect(find.textContaining('I pledge: two minutes every day.'), findsOneWidget);
  });
}
