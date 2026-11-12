import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/projects.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('155, 162, 173: next action prefers the frog and skips blocked tasks', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    final p = await r.app.addRec(Kind.project, {'name': 'P'});
    Future<Rec> t(String title, [Map<String, Object?> x = const {}]) =>
        r.app.addRec(Kind.task, {'projectId': p.id, 'title': title, 'done': false, 'est': 50, ...x});
    final a = await t('Read the brief');
    r.clock.advance(const Duration(seconds: 1));
    final b = await t('Write the intro', {'after': a.id});
    r.clock.advance(const Duration(seconds: 1));
    final c = await t('Machine learning', {'frog': true});
    expect(blocked(r.v, r.v.rec(b.id)!), isTrue);
    expect(nextAction(r.v, p.id)!.id, c.id);
    expect(vague(r.v.rec(c.id)!), isTrue);
    expect(vague(r.v.rec(a.id)!), isFalse);
    expect(headStart(r.v, p.id), closeTo(0.1, 1e-9));
    expect(projectSessionsLeft(r.v, p.id), 6);
    await r.app.toggleTask(r.v.rec(a.id)!);
    expect(blocked(r.v, r.v.rec(b.id)!), isFalse);
    expect(headStart(r.v, p.id), closeTo(0.4, 1e-9));
  });

  test('157 estimate ratio, 166 dread bonus, 172 open loops, 174 recurring', () async {
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    final p = await r.app.addRec(Kind.project, {'name': 'P'});
    final t = await r.app.addRec(Kind.task, {'projectId': p.id, 'title': 'Solve set 1', 'done': false, 'est': 25, 'dread': 5, 'every': 7, 'due': r.v.today + 1});
    await r.app.startSession(minutes: 50, taskId: t.id);
    r.clock.advance(const Duration(minutes: 50));
    await r.app.completeIfDue();
    expect(openLoops(r.v).single.id, t.id);
    await r.app.toggleTask(r.v.rec(t.id)!);
    expect(estimateRatio(r.v), 2);
    expect(correctedEstimate(r.v, 50), 100);
    expect(r.v.xpExtras, contains(('Dreaded tasks done', 30)));
    final next = r.v.tasksOf(p.id).where((x) => !x.flag('done')).single;
    expect(next.integer('due'), r.v.today + 8);
    expect(openLoops(r.v), isEmpty);
  });

  test('159 quadrants, 163 WIP limit, 154 splitter, 168 templates', () async {
    expect(quadrant(const Rec(id: 'a', kind: Kind.task, created: 0, data: {'urgent': true, 'important': true})), 0);
    expect(quadrant(const Rec(id: 'a', kind: Kind.task, created: 0, data: {'important': true})), 1);
    expect(quadrant(const Rec(id: 'a', kind: Kind.task, created: 0)), 3);
    final r = Rig();
    await r.app.setKv('unlockAll', '1');
    for (final n in ['A', 'B', 'C']) {
      expect(wipFull(r.v), isFalse);
      await r.app.addRec(Kind.project, {'name': n});
    }
    expect(wipFull(r.v), isTrue);
    expect(splitAssignment('1. Read chapter 4. 2) Solve Q1 to Q5\n- Draw the ER diagram; submit by Friday'),
        ['Read chapter 4.', 'Solve Q1 to Q5', 'Draw the ER diagram;', 'submit by Friday']);
    expect(templates.keys, containsAll(['Lab record', 'Assignment', 'Exam prep', 'Hackathon']));
  });
}
