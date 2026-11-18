import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/social.dart';
import 'package:challenger_timer/data/fake_social.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Future<(FakeSocial, FakeSocial, FakeServer)> pair() async {
  final s = FakeServer();
  final a = s.client('uid-asha');
  final b = s.client('uid-ben');
  await a.signIn('Asha');
  await b.signIn('Ben');
  return (a, b, s);
}

Future<void> befriend(FakeSocial a, FakeSocial b, FakeServer s) async {
  await a.requestFriend(inviteCodeFor('uid-ben'));
  await b.respond('uid-asha', accept: true);
}

void main() {
  group('what is shared (R7)', () {
    test('a day row holds only numbers: no project names, notes or photos', () async {
      final r = Rig(streakMin: 25);
      final p = await r.app.addRec(Kind.project, {'name': 'Secret thesis'});
      await r.app.startSession(minutes: 25, projectId: p.id, title: 'private title');
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      await r.app.saveProof(type: 'text', value: 'private proof', parkingNote: 'private note');
      final row = dayRowOf(r.v, 'uid-1', r.v.today);
      expect(row.toJson().keys.toSet(), {'uid', 'day', 'minutes', 'sessions', 'streak', 'rank'});
      expect([row.minutes, row.sessions, row.streak], [25, 1, 1]);
      expect('${row.toJson()}', isNot(anyOf(contains('Secret'), contains('private'))));
      expect(DayRow.fromJson(row.toJson()).minutes, 25);
    });
    test('the default backend refuses everything and invents nothing', () async {
      const u = UnavailableSocial();
      expect(u.live, isFalse);
      expect(await u.friends(), isEmpty);
      expect(await u.duels(), isEmpty);
      expect(await u.daysOf('x', 0, 9), isEmpty);
      expect(() => u.signIn('A'), throwsA(isA<SocialUnavailable>()));
      expect(() => u.requestFriend('ABCDEFGH'), throwsA(isA<SocialUnavailable>()));
      expect('${const SocialUnavailable()}', contains('Nothing is shared'));
    });
  });

  group('invite codes', () {
    test('8 characters, stable, no look-alikes, validated', () {
      final c = inviteCodeFor('uid-asha');
      expect(c.length, 8);
      expect(inviteCodeFor('uid-asha'), c);
      expect(inviteCodeFor('uid-ben'), isNot(c));
      for (final ch in ['0', 'O', '1', 'I']) {
        expect(c.contains(ch), isFalse);
      }
      expect(validInviteCode(c), isTrue);
      expect(validInviteCode(c.toLowerCase()), isTrue);
      expect(validInviteCode('ABC'), isFalse);
      expect(validInviteCode('ABCDEFG0'), isFalse);
    });
  });

  group('friends', () {
    test('a request stays pending until the other person accepts; strangers see nothing', () async {
      final (a, b, s) = await pair();
      final c = s.client('uid-cara');
      await c.signIn('Cara');
      await a.publishDay(const DayRow('uid-asha', 10, 50, 2, 3, 1));
      await a.requestFriend(inviteCodeFor('uid-ben'));
      expect((await a.friends()).single.state, LinkState.pending);
      expect((await b.friends()).single.state, LinkState.pending);
      expect(() => b.daysOf('uid-asha', 0, 99), throwsA(isA<SocialError>()), reason: 'not accepted yet');
      await b.respond('uid-asha', accept: true);
      expect((await a.friends()).single.state, LinkState.accepted);
      expect((await b.daysOf('uid-asha', 0, 99)).single.minutes, 50);
      expect(() => c.daysOf('uid-asha', 0, 99), throwsA(isA<SocialError>()), reason: 'a stranger cannot read');
    });
    test('wrong code, own code, decline, unfriend and block', () async {
      final (a, b, s) = await pair();
      expect(() => a.requestFriend('ZZZZZZZZ'), throwsA(predicate((e) => '$e'.contains('No one has that code'))));
      expect(() => a.requestFriend(inviteCodeFor('uid-asha')), throwsA(predicate((e) => '$e'.contains('your own'))));
      await a.requestFriend(inviteCodeFor('uid-ben'));
      await b.respond('uid-asha', accept: false);
      expect(await a.friends(), isEmpty);
      await befriend(a, b, s);
      await a.unfriend('uid-ben');
      expect(await b.friends(), isEmpty);
      await befriend(a, b, s);
      await b.setLink('uid-asha', LinkState.blocked);
      expect(await b.friends(), isEmpty, reason: 'a blocked person disappears');
      expect(() => a.requestFriend(inviteCodeFor('uid-ben')), throwsA(predicate((e) => '$e'.contains('No one has that code'))), reason: 'and cannot tell they are blocked');
    });
    test('only your own days can be published', () async {
      final (a, _, _) = await pair();
      expect(() => a.publishDay(const DayRow('uid-ben', 1, 1, 1, 1, 0)), throwsA(isA<SocialError>()));
    });
  });

  group('shared streak', () {
    test('counts days in a row where both reached 25 minutes', () {
      List<DayRow> rows(String u, Map<int, int> m) => [for (final e in m.entries) DayRow(u, e.key, e.value, 1, 1, 0)];
      final a = rows('a', {7: 30, 8: 30, 9: 30, 10: 30});
      final b = rows('b', {7: 30, 8: 10, 9: 30, 10: 30});
      expect(sharedStreak(a, b, 10), 2);
      expect(sharedStreak(a, b, 11), 2, reason: 'today not over: yesterday still counts');
      expect(sharedStreak(a, rows('b', {}), 10), 0);
    });
  });

  group('nudges', () {
    test('one per friend per day, friends only, fixed lines', () async {
      final (a, b, s) = await pair();
      expect(() => a.nudge('uid-ben', 10), throwsA(predicate((e) => '$e'.contains('only nudge friends'))));
      await befriend(a, b, s);
      await a.nudge('uid-ben', 10);
      expect(() => a.nudge('uid-ben', 10), throwsA(predicate((e) => '$e'.contains('One nudge per friend per day'))));
      await a.nudge('uid-ben', 11);
      expect(canNudge(sentDays: [10], today: 10, link: LinkState.accepted), isFalse);
      expect(canNudge(sentDays: [], today: 10, link: LinkState.muted), isFalse);
      expect(nudgeLines.length, greaterThanOrEqualTo(3));
      for (final l in nudgeLines) {
        expect(l.toLowerCase(), isNot(anyOf(contains('lazy'), contains('failed'), contains('shame'))));
      }
    });
  });

  group('duels', () {
    test('invite, accept, play one day, settle after midnight, winner by minutes', () async {
      final (a, b, s) = await pair();
      await befriend(a, b, s);
      final d = await a.challenge('uid-ben', 10);
      expect(() => a.answerDuel(d.id, accept: true), throwsA(isA<SocialError>()), reason: 'only the invited person answers');
      await b.answerDuel(d.id, accept: true);
      await a.publishDay(const DayRow('uid-asha', 10, 75, 3, 4, 1));
      await b.publishDay(const DayRow('uid-ben', 10, 50, 2, 9, 2));
      await a.settleDuels(10);
      expect((await a.duels()).single.state, DuelState.active, reason: 'the day is not over');
      await a.settleDuels(11);
      final done = (await a.duels()).single;
      expect([done.state, done.fromMinutes, done.toMinutes, done.winner], [DuelState.finished, 75, 50, 'uid-asha']);
      expect(done.finish(30, 30).winner, isNull);
    });
    test('friends only, one duel per friend per day, decline ends it', () async {
      final (a, b, s) = await pair();
      expect(() => a.challenge('uid-ben', 10), throwsA(predicate((e) => '$e'.contains('only challenge friends'))));
      await befriend(a, b, s);
      final d = await a.challenge('uid-ben', 10);
      expect(() => b.challenge('uid-asha', 10), throwsA(predicate((e) => '$e'.contains('already a duel'))));
      await b.answerDuel(d.id, accept: false);
      expect((await b.duels()).single.state, DuelState.declined);
      await b.challenge('uid-asha', 10);
    });
  });

  group('weekly board', () {
    test('ranks by days shown up, then minutes; top third up, bottom third down', () {
      final names = {'a': 'Asha', 'b': 'Ben', 'c': 'Cara', 'd': 'Dev', 'e': 'Esha', 'f': 'Farhan'};
      List<DayRow> r(String u, List<int> mins) => [for (final (i, m) in mins.indexed) DayRow(u, 10 + i, m, 1, 1, 0)];
      final rows = {
        'a': r('a', [30, 30, 30, 30, 30]),
        'b': r('b', [200, 10, 10]),
        'c': r('c', [60, 60, 60]),
        'd': r('d', [30, 30, 30, 30]),
        'e': r('e', [40, 40]),
        'f': <DayRow>[],
      };
      final board = weeklyBoard(names, rows, 10, 16);
      expect(board.map((x) => x.uid), ['a', 'd', 'c', 'e', 'b', 'f']);
      expect(board.map((x) => x.move), [1, 1, 0, 0, -1, -1]);
      expect(board.first.days, 5);
      expect(board[4].minutes, 220);
      expect(weeklyBoard({'a': 'A', 'b': 'B'}, rows, 10, 16).every((x) => x.move == 0), isTrue, reason: 'small boards never move');
    });
  });

  test('deleting the account removes the profile, days, links, nudges and duels', () async {
    final (a, b, s) = await pair();
    await befriend(a, b, s);
    await a.publishDay(const DayRow('uid-asha', 10, 50, 2, 3, 1));
    await a.nudge('uid-ben', 10);
    await a.challenge('uid-ben', 10);
    await a.deleteAccount();
    expect(s.profiles.containsKey('uid-asha'), isFalse);
    expect(s.byCode.containsKey(inviteCodeFor('uid-asha')), isFalse);
    expect(s.days.containsKey('uid-asha'), isFalse);
    expect(s.links['uid-ben']!.containsKey('uid-asha'), isFalse);
    expect(s.nudges, isEmpty);
    expect(s.duels, isEmpty);
    expect(await b.friends(), isEmpty);
  });
}
