import 'package:challenger_timer/core/backend.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/vault.dart';
import 'package:challenger_timer/ui/special.dart';
import 'package:challenger_timer/ui/tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

Future<void> proof(Rig r, String type, String value, {String? project, int units = 0, String unit = ''}) async {
  await r.app.startSession(projectId: project);
  r.clock.advance(const Duration(minutes: 2));
  await r.app.completeIfDue();
  await r.app.saveProof(type: type, value: value, units: units, unit: unit, parkingNote: 'Open the next page');
}

void main() {
  test('140 search, 139 pin, 141/142 unit counters', () async {
    final r = Rig();
    final dsa = await r.app.addRec(Kind.project, {'name': 'DSA'});
    await proof(r, 'text', 'Solved two-sum', project: dsa.id, units: 3, unit: 'problems');
    await proof(r, 'text', 'Wrote the abstract', units: 120, unit: 'words');
    await proof(r, 'text', 'Three more graph problems', project: dsa.id, units: 3, unit: 'problems');
    expect(searchProofs(r.v, 'abstract').single.str('value'), 'Wrote the abstract');
    expect(searchProofs(r.v, 'dsa').length, 3, reason: 'last project sticks, and project name is searchable');
    expect(searchProofs(r.v, '', projectId: dsa.id).length, 3);
    expect(searchProofs(r.v, 'zzz'), isEmpty);
    expect(unitTotals(r.v), {'problems': 6, 'words': 120});
    await r.app.putRec(r.v.proofs.first.copy({'pinned': true}));
    expect(pinned(r.v).single.str('value'), 'Three more graph problems');
    expect(portfolioExport(r.v), contains('Three more graph problems'));
    expect(portfolioExport(r.v), startsWith('# Work I can show'));
  });

  test('135 daily page, 136 weekly digest, 138 done list', () async {
    final r = Rig();
    await r.app.setKv('name', 'Winzo');
    final h = await r.app.addRec(Kind.habit, {'name': 'Open the book'});
    await r.app.tickHabit(h.id);
    await proof(r, 'text', 'Read chapter 3');
    final page = dailyPage(r.v, r.v.today);
    expect(page[1], '1 sessions, 2 minutes');
    expect(page.join('\n'), contains('• Read chapter 3'));
    expect(page.join('\n'), contains('Habits: Open the book'));
    expect(page.join('\n'), contains('Next step left: Open the next page'));
    final digest = weeklyDigest(r.v);
    expect(digest, contains("Winzo's week"));
    expect(digest, contains('1 of 7 days shown up'));
    expect(digest, contains('1 sessions, 2 minutes'));
    final p = await r.app.addRec(Kind.project, {'name': 'P'});
    final t = await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Submit form', 'done': false});
    await r.app.toggleTask(t);
    expect(doneList(r.v).map((e) => e.$2), containsAll(['Task: Submit form', 'Read chapter 3']));
  });

  test('137 proof-required habit only counts with a line of proof', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    final h = await r.app.addRec(Kind.habit, {'name': 'One commit', 'proofRequired': true});
    await r.app.tickHabit(h.id);
    expect(r.v.tickedToday(h.id), isFalse);
    await r.app.tickHabit(h.id, proof: 'Fixed the login bug');
    expect(r.v.tickedToday(h.id), isTrue);
    expect(r.v.type(Ev.habitTick).single.payload['proof'], 'Fixed the login bug');
  });

  test('147 backup status and 148 on this day', () async {
    final r = Rig(clock: TestClock(DateTime.utc(2026, 10, 11, 10)));
    expect(backupStale(r.v), isFalse, reason: 'nothing to back up yet');
    await proof(r, 'text', 'October work');
    expect(backupStale(r.v), isTrue);
    await r.app.markExported();
    expect(backupStale(r.v), isFalse);
    r.clock.setWall(2026, 11, 11, 10);
    expect(backupStale(r.v), isTrue, reason: 'more than 7 days since the export');
    final mem = onThisDay(r.v);
    expect(mem.single.$1, 'A month ago');
    expect(mem.single.$2.str('value'), 'October work');
  });

  test('134 before and after needs two photos in one project', () async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'Robot'});
    await proof(r, 'photo', '/a.jpg', project: p.id);
    expect(beforeAfter(r.v), isEmpty);
    r.clock.advance(const Duration(days: 3));
    await proof(r, 'photo', '/b.jpg', project: p.id);
    final pair = beforeAfter(r.v).single;
    expect([pair.$1, pair.$2.str('value'), pair.$3.str('value')], ['Robot', '/a.jpg', '/b.jpg']);
  });

  test('backend is honest: the local one is not connected and invents nothing', () async {
    const b = LocalBackend();
    expect(b.connected, isFalse);
    expect(() => b.githubCommits('someone', DateTime(2026)), throwsA(isA<BackendUnavailable>()));
    expect(() => b.backup('{}'), throwsA(isA<BackendUnavailable>()));
    expect(() => b.signIn(), throwsA(isA<BackendUnavailable>()));
  });

  testWidgets('vault tab: search narrows the list, pin works, backup warning shows', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await proof(r, 'text', 'Alpha notes');
    await proof(r, 'text', 'Beta notes');
    await pumpTool(t, r, const VaultScreen());
    expect(find.byKey(const Key('backupWarning')), findsOneWidget);
    await t.enterText(find.byKey(const Key('vaultSearch')), 'alpha');
    await t.pump();
    expect(find.text('Alpha notes'), findsOneWidget);
    expect(find.text('Beta notes'), findsNothing);
    final id = r.v.proofs.firstWhere((p) => p.str('value') == 'Alpha notes').id;
    await t.tap(find.byKey(Key('pin-$id')));
    await t.pump();
    expect(pinned(r.v).single.id, id);
  });

  testWidgets('share card and digest tools render', (t) async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    await proof(r, 'text', 'x');
    await pumpTool(t, r, const Scaffold(body: SingleChildScrollView(child: ShareCardTool())));
    expect(find.byKey(const Key('shareCard')), findsOneWidget);
    expect(find.text('DAYS IN A ROW'), findsOneWidget);
    final shared = <String>[];
    await pumpTool(t, r, const Scaffold(body: SingleChildScrollView(child: VaultTool(136))));
    expect(find.byKey(const Key('digest')), findsOneWidget);
    expect(shared, isEmpty);
  });
}
