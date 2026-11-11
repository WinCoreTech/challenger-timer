import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Event ev(String type, int day, [Map<String, Object?> p = const {}]) =>
    Event(type: type, ts: day * msPerDay, offsetMin: 0, day: day, payload: p);

void main() {
  group('XP', () {
    test('starting pays more than any other single action', () {
      expect(xpStart, greaterThan(xpProof));
      expect(xpStart, greaterThan(xpHabitTick));
      expect(xpStart, greaterThan(2 * xpPerMinute)); // more than the 2 minutes themselves
    });
    test('computed from events, with the bonus held for today', () {
      final events = [
        ev(Ev.sessionStart, 10),
        ev(Ev.sessionDone, 10, {'minutes': 2}),
        ev(Ev.proof, 10),
        ev(Ev.habitTick, 10),
      ];
      final x = computeXp(events, 10);
      expect(x.starts, 50);
      expect(x.minutes, 4);
      expect(x.proof, 20);
      expect(x.habits, 10);
      expect(x.bonus, 100); // today's, already granted
      expect(x.total, 184);
    });
    test('bonus is removed for a past day with no session, kept for one with', () {
      final worked = [ev(Ev.sessionStart, 10), ev(Ev.sessionDone, 10, {'minutes': 2})];
      // Day 11 is today: day 10 bonus kept + today's held.
      expect(computeXp(worked, 11).bonus, 200);
      // Day 12: day 11 had no session, its bonus is gone.
      expect(computeXp(worked, 12).bonus, 200);
      final idle = [ev(Ev.appOpen, 10)];
      expect(computeXp(idle, 10).bonus, 100);
      expect(computeXp(idle, 11).bonus, 100); // yesterday's vanished, today's held
      expect(computeXp(idle, 11, bonusOn: false).bonus, 0);
    });
    test('start XP is capped per day', () {
      final events = [for (var i = 0; i < 9; i++) ev(Ev.sessionStart, 10)];
      expect(computeXp(events, 10).starts, paidStartsPerDay * xpStart);
    });
  });

  group('ranks from JSON', () {
    test('at least 10 ranks, from Professional Postponer to Momentum Machine', () {
      expect(ranks.length, greaterThanOrEqualTo(10));
      expect(ranks.first.name, 'Professional Postponer');
      expect(ranks.first.xp, 0);
      expect(ranks.last.name, 'Momentum Machine');
      expect(ranks.map((r) => r.name), containsAll(['Reluctant Starter', 'Daily Shower-Upper']));
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i].xp, greaterThan(ranks[i - 1].xp));
      }
    });
    test('rank lookup and progress', () {
      expect(rankFor(0, ranks).index, 0);
      expect(rankFor(ranks[1].xp - 1, ranks).index, 0);
      expect(rankFor(ranks[1].xp, ranks).index, 1);
      final mid = rankFor((ranks[1].xp + ranks[2].xp) ~/ 2, ranks);
      expect(mid.progress, closeTo(0.5, 0.01));
      final top = rankFor(1 << 30, ranks);
      expect(top.rank.name, 'Momentum Machine');
      expect(top.next, isNull);
    });
    test('30 achievements defined in JSON with unique ids', () {
      expect(achievements.length, 30);
      expect(achievements.map((a) => a.id).toSet().length, 30);
      expect(achievements.first.earned({'starts': 1}), isTrue);
      expect(achievements.first.earned({}), isFalse);
    });
  });

  group('delayed off switch', () {
    const hour = msPerHour;
    test('on is instant, off takes 24 hours and can be cancelled', () {
      var s = const DelayedSwitch().turnOn();
      expect(s.effective(0), isTrue);
      s = s.requestOff(1000);
      expect(s.effective(1000), isTrue);
      expect(s.pendingOff(1000), isTrue);
      expect(s.msUntilOff(1000), 24 * hour);
      expect(s.effective(1000 + 24 * hour - 1), isTrue);
      expect(s.effective(1000 + 24 * hour), isFalse);
      final kept = s.cancelOff();
      expect(kept.effective(1000 + 48 * hour), isTrue);
      expect(kept.pendingOff(2000), isFalse);
    });
    test('asking again does not restart or shorten the countdown', () {
      final s = const DelayedSwitch(on: true).requestOff(0).requestOff(5 * hour);
      expect(s.offAt, 24 * hour);
    });
    test('round-trips through its stored form and settles when elapsed', () {
      final s = DelayedSwitch.parse(const DelayedSwitch(on: true, offAt: 99).encode());
      expect(s.on, isTrue);
      expect(s.offAt, 99);
      expect(s.settle(100).on, isFalse);
      expect(DelayedSwitch.parse(null, or: true).on, isTrue);
    });
    test('countdown text', () {
      expect(countdown(24 * hour), '24h 00m');
      expect(countdown(90 * 1000), '01:30');
    });
  });

  group('first-task lock window', () {
    Moment at(int h, int m) => Moment(DateTime.utc(2026, 11, 11, h, m).millisecondsSinceEpoch, 0);
    test('open before 10 pm, locked from 10 pm until the day ends at 3 am', () {
      expect(inLockWindow(at(21, 59), 3), isFalse);
      expect(inLockWindow(at(22, 0), 3), isTrue);
      expect(inLockWindow(at(23, 30), 3), isTrue);
      expect(inLockWindow(at(2, 59), 3), isTrue);
      expect(inLockWindow(at(3, 0), 3), isFalse);
      expect(inLockWindow(at(9, 0), 3), isFalse);
    });
  });

  group('buddy message', () {
    test('zero day is reported without blame', () {
      final m = buddyMessage(name: 'Winzo', sessions: 0, minutes: 0, streak: 4);
      expect(m, contains('Winzo did not start a session today'));
      expect(m, contains('4 days'));
      for (final bad in ['lazy', 'failed', 'shame', 'again', 'pathetic', 'useless']) {
        expect(m.toLowerCase(), isNot(contains(bad)));
      }
    });
    test('worked day lists sessions and minutes', () {
      final m = buddyMessage(name: '', sessions: 2, minutes: 27, streak: 1);
      expect(m, contains('2 sessions'));
      expect(m, contains('27 min'));
      expect(m, contains('1 day.'));
    });
  });

  test('verb check for tiny steps', () {
    expect(startsWithVerb('Open notebook to page 12'), isTrue);
    expect(startsWithVerb('Machine learning'), isFalse);
    expect(startsWithVerb(defaultStep), isTrue);
  });
}
