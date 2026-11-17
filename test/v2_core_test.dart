import 'package:challenger_timer/core/backup.dart';
import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/ladder.dart';
import 'package:challenger_timer/core/ranges.dart';
import 'package:challenger_timer/core/settings.dart';
import 'package:challenger_timer/core/tree.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const th = [0, 20, 45, 80, 120, 170, 230, 300, 380, 470, 570, 680];

void main() {
  group('rank ladder (5.9)', () {
    test('thresholds come from ranks.json and rise', () {
      expect([for (final r in ranks) r.score], th);
    });
    test('score decays with a 5-day half-life', () {
      expect(scoreAt({10: 100}, 10), 100);
      expect(scoreAt({10: 100}, 15), closeTo(50, 1e-9));
      expect(scoreAt({10: 100}, 20), closeTo(25, 1e-9));
      expect(scoreAt({10: 100}, 9), 0);
    });
    test('promotion is immediate and can skip several ranks', () {
      final l = computeLadder({100: 25}, th, 100);
      expect(l.index, 1);
      expect(l.minutesToAdvance, 20, reason: '45 needed, 25 held');
      expect(computeLadder({100: 130}, th, 100).index, 4);
      expect(computeLadder({}, th, 100).index, 0);
    });
    test('minutes to advance counts today at full weight', () {
      final l = computeLadder({100: 25, 101: 10}, th, 101);
      final s = 25 * 0.8705505632961241 + 10;
      expect(l.score, closeTo(s, 1e-6));
      expect(l.minutesToAdvance, (45 - s).ceil());
      expect(computeLadder({100: 5000}, th, 100).minutesToAdvance, isNull);
    });
    test('demotion needs 3 counted days under the floor, one step at a time', () {
      // 130 minutes on day 100 gives rank 4 (floor 120). It drops under 120
      // on day 101, so days 101, 102, 103 are below: demoted at the end of 103.
      expect(computeLadder({100: 130}, th, 103).index, 4);
      final l = computeLadder({100: 130}, th, 104);
      expect(l.index, 3);
      expect(l.changes.last.promotion, isFalse);
      expect(l.changes.last.day, 103);
      expect(l.peak, 4);
    });
    test('rest, sick, exam and freeze days never count toward demotion', () {
      final l = computeLadder({100: 130}, th, 110, exempt: {for (var d = 101; d <= 109; d++) d});
      expect(l.index, 4);
      final r = computeLadder({100: 130}, th, 105, exemptDay: (d) => d == 102);
      expect(r.changes.where((c) => !c.promotion).single.day, 104, reason: 'one exempt day delays it by a day');
    });
    test('working again resets the below count and can regain a lost rank', () {
      final l = computeLadder({100: 130, 104: 200}, th, 104);
      expect(l.index, greaterThanOrEqualTo(4));
      expect(l.regained, isTrue);
      expect(computeLadder({100: 130}, th, 102).regained, isFalse);
    });
    test('engine wires it: banner minutes, exempt freeze days, achievements', () async {
      final r = Rig();
      await r.session(minutes: 25);
      expect(r.v.ladder.index, 1);
      expect(r.v.ladderRank.name, ranks[1].name);
      expect(r.v.ladder.minutesToAdvance, 20);
      r.clock.advance(const Duration(days: 3)); // two freeze days: exempt
      expect(r.v.ladder.index, 1);
      await r.app.startSession(minutes: 25);
      await r.app.stopSession();
      expect(achievements.singleWhere((a) => a.id == 'cancel_1').earned(r.v.metrics), isTrue);
      expect(achievements.length, greaterThanOrEqualTo(30));
    });
  });

  group('settings (5.11)', () {
    test('defaults and project overrides, child inherits parent', () async {
      final r = Rig();
      expect([r.v.workMinutes(), r.v.shortBreakMinutes(), r.v.longBreakMinutes(), r.v.prefInt(S.longBreakEvery)], [25, 5, 15, 5]);
      expect(r.v.prefOn(S.keepScreenOn), isTrue);
      expect(r.v.prefOn(S.casualMode), isFalse);
      final p = await r.app.addRec(Kind.project, {'name': 'Thesis', 'workMin': 50});
      final c = await r.app.addRec(Kind.project, {'name': 'Chapter 1', 'parentId': p.id, 'shortBreakMin': 10});
      expect(r.v.workMinutes(c.id), 50, reason: 'inherits the parent override');
      expect(r.v.shortBreakMinutes(c.id), 10);
      expect(r.v.longBreakMinutes(c.id), 15, reason: 'falls back to the global setting');
      await r.app.setKv(S.workMin, '30');
      expect(r.v.workMinutes(), 30);
      expect(r.v.workMinutes(p.id), 50);
    });
    test('long break every 5 sessions; the counter resets after 3 hours idle', () async {
      final r = Rig();
      for (var i = 0; i < 4; i++) {
        await r.session(minutes: 25);
      }
      expect(r.v.nextBreakIsLong(), isFalse);
      await r.session(minutes: 25);
      expect(r.v.sessionsSinceLongGap(), 5);
      expect(r.v.nextBreakIsLong(), isTrue);
      r.clock.advance(const Duration(hours: 3, minutes: 1));
      expect(r.v.sessionsSinceLongGap(), 0);
      await r.session(minutes: 25);
      expect(r.v.sessionsSinceLongGap(), 1);
    });
  });

  group('project tree (5.4 to 5.6)', () {
    test('nesting, totals including children, colours, cycles, filter and sort', () async {
      final r = Rig();
      final a = await r.app.addRec(Kind.project, {'name': 'Sem 5'});
      r.clock.advance(const Duration(seconds: 1));
      final b = await r.app.addRec(Kind.project, {'name': 'DBMS', 'parentId': a.id});
      r.clock.advance(const Duration(seconds: 1));
      final c = await r.app.addRec(Kind.project, {'name': 'Zebra'});
      await r.app.startSession(minutes: 30, projectId: b.id);
      r.clock.advance(const Duration(minutes: 30));
      await r.app.completeIfDue();
      var rows = projectRows(r.v);
      expect(rows.map((x) => '${x.depth}:${x.project.str('name')}'), ['0:Sem 5', '1:DBMS', '0:Zebra']);
      expect(rows.first.minutes, 30, reason: 'parent total includes the child');
      expect(rows.first.activeOn(r.v.today), isTrue);
      expect(rows.last.activeOn(r.v.today), isFalse);
      expect(projectRows(r.v, sort: 'name').first.project.str('name'), 'Sem 5');
      expect(projectRows(r.v, filter: 'dbms').map((x) => x.project.str('name')), ['Sem 5', 'DBMS']);
      expect(canSetParent(r.v, a.id, b.id), isFalse, reason: 'would make a cycle');
      expect(canSetParent(r.v, a.id, a.id), isFalse);
      expect(canSetParent(r.v, c.id, b.id), isTrue);
      expect(hm(750), '12h 30m');
      r.clock.advance(const Duration(days: 8));
      expect(projectRows(r.v).first.activeOn(r.v.today), isFalse);
    });
  });

  group('stats ranges (5.8)', () {
    test('period bounds and stepping', () async {
      final r = Rig(); // Wed 11 Nov 2026
      final t = r.v.today;
      expect(rangeDays(r.v, RangeKind.last7), (t - 6, t));
      expect(rangeDays(r.v, RangeKind.day, step: -1), (t - 1, t - 1));
      expect(rangeDays(r.v, RangeKind.week), (dayOfDate(2026, 11, 9), dayOfDate(2026, 11, 15)));
      expect(rangeDays(r.v, RangeKind.week, step: -1), (dayOfDate(2026, 11, 2), dayOfDate(2026, 11, 8)));
      expect(rangeDays(r.v, RangeKind.month), (dayOfDate(2026, 11, 1), dayOfDate(2026, 11, 30)));
      expect(rangeDays(r.v, RangeKind.month, step: -10), (dayOfDate(2026, 1, 1), dayOfDate(2026, 1, 31)));
      expect(rangeDays(r.v, RangeKind.year, step: -1), (dayOfDate(2025, 1, 1), dayOfDate(2025, 12, 31)));
      expect(rangeDays(r.v, RangeKind.custom, customFrom: t, customTo: t - 3), (t - 3, t));
      await r.app.setKv(S.weekStartsOn, '7');
      expect(rangeDays(r.v, RangeKind.week).$1, dayOfDate(2026, 11, 8));
      expect(steppable(RangeKind.last30), isFalse);
      expect(rangeNames.length, 8);
    });
    test('figures: consistency excludes rest days and the future', () async {
      final r = Rig();
      final p = await r.app.addRec(Kind.project, {'name': 'DSA'});
      await r.app.startSession(minutes: 25, projectId: p.id);
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      r.clock.advance(const Duration(days: 1));
      await r.session(minutes: 50);
      final (from, to) = rangeDays(r.v, RangeKind.week);
      final s = rangeStats(r.v, from, to);
      expect([s.minutes, s.sessions, s.activeDays, s.countedDays], [75, 2, 2, 4], reason: 'Mon to Thu so far');
      expect(s.consistency, 50);
      expect(s.byProject.first, ('DSA', 75));
      expect(s.averageSession, 38);
      expect(s.longestDayMinutes, 50);
      expect(rangeStats(r.v, from - 7, to - 7).empty, isTrue);
      await r.app.setKv('restDays', '12');
      expect(rangeStats(r.v, from, to).countedDays, 2);
    });
  });

  group('backup (5.12)', () {
    test('round trip restores everything and rebuilds rank from events', () async {
      final r = Rig();
      await r.app.setKv('name', 'Winzo');
      final p = await r.app.addRec(Kind.project, {'name': 'Secret project', 'why': 'private reason'});
      await r.app.startSession(minutes: 25, projectId: p.id);
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      await r.app.saveProof(type: 'text', value: 'my private proof');
      final text = r.app.exportJson();
      final b = decodeBackup(text);
      expect(b.format, backupFormat);
      expect(b.summary, contains('events'));
      final fresh = Rig(clock: r.clock);
      await fresh.app.loadBackup(b);
      expect(fresh.v.name, 'Winzo');
      expect(fresh.v.projects.single.str('name'), 'Secret project');
      expect(fresh.v.ladder.index, r.v.ladder.index);
      expect(fresh.v.master.current, 1);
      expect(fresh.v.xpTotal, r.v.xpTotal);
    });
    test('redacted backup keeps numbers and removes names, notes and proof text', () async {
      final r = Rig();
      await r.app.setKv('name', 'Winzo');
      await r.app.setKv('buddyPhone', '+911234');
      final p = await r.app.addRec(Kind.project, {'name': 'Secret project'});
      await r.app.startSession(minutes: 25, projectId: p.id, title: 'private title');
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      await r.app.saveProof(type: 'text', value: 'my private proof', parkingNote: 'private note');
      final text = r.app.exportJson(redacted: true);
      for (final secret in ['Secret project', 'private', 'Winzo', '+911234']) {
        expect(text, isNot(contains(secret)));
      }
      final b = decodeBackup(text);
      expect(b.redacted, isTrue);
      expect(b.events.where((e) => e.type == Ev.sessionDone).single.payload['minutes'], 25);
      expect(b.recs.firstWhere((x) => x.kind == Kind.project).str('name'), startsWith('project'));
    });
    test('old format 1 files load; wrong, newer and damaged files are refused plainly', () {
      const old = '{"app":"Productivity Challenger Timer","exportedAt":5,"settings":{"name":"W"},'
          '"events":[{"id":1,"type":"session_done","ts":1,"offsetMin":0,"day":3,"payload":{"minutes":2}}],"records":[]}';
      final b = decodeBackup(old);
      expect([b.format, b.events.length, b.settings['name']], [1, 1, 'W']);
      expect(() => decodeBackup('hello'), throwsA(isA<BackupError>()));
      expect(() => decodeBackup('{"app":"Other","events":[],"records":[]}'), throwsA(isA<BackupError>()));
      expect(() => decodeBackup('{"app":"Productivity Challenger Timer","format":99,"events":[],"records":[]}'),
          throwsA(predicate((e) => '$e'.contains('newer version'))));
      expect(() => decodeBackup('{"app":"Productivity Challenger Timer","events":[{"x":1}],"records":[]}'),
          throwsA(predicate((e) => '$e'.contains('damaged'))));
    });
  });
}
