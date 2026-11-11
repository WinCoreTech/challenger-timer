import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/streak_engine.dart';
import 'package:flutter_test/flutter_test.dart';

int d(int y, int m, int day) => dayOfDate(y, m, day);
Set<int> range(int from, int n) => {for (var i = 0; i < n; i++) from + i};

void main() {
  group('day boundary', () {
    const ist = 330;
    int ts(int y, int mo, int da, int h, int mi, int off) =>
        DateTime.utc(y, mo, da, h, mi).millisecondsSinceEpoch - off * msPerMinute;

    test('02:59 belongs to the previous day, 03:00 to the new one', () {
      expect(dayOf(ts(2026, 11, 12, 2, 59, ist), ist, 3), d(2026, 11, 11));
      expect(dayOf(ts(2026, 11, 12, 3, 0, ist), ist, 3), d(2026, 11, 12));
    });
    test('day-end setting moves the boundary', () {
      expect(dayOf(ts(2026, 11, 12, 0, 30, ist), ist, 0), d(2026, 11, 12));
      expect(dayOf(ts(2026, 11, 12, 4, 30, ist), ist, 5), d(2026, 11, 11));
    });
    test('negative offsets and pre-epoch instants floor correctly', () {
      expect(dayOf(ts(2026, 3, 1, 2, 0, -480), -480, 3), d(2026, 2, 28));
      expect(dayOf(-1, 0, 0), -1);
    });
    test('spring-forward: 23-hour day still yields consecutive day numbers', () {
      // US Pacific 2026-03-08: 02:00 PST (-480) jumps to 03:00 PDT (-420).
      final before = dayOf(ts(2026, 3, 7, 22, 0, -480), -480, 3);
      final after = dayOf(ts(2026, 3, 8, 22, 0, -420), -420, 3);
      expect(after - before, 1);
      // 03:00 PDT, the first instant after the jump, opens the new day.
      expect(dayOf(ts(2026, 3, 8, 3, 0, -420), -420, 3), d(2026, 3, 8));
      // 01:59 PST, one minute before the jump, is still the 7th.
      expect(dayOf(ts(2026, 3, 8, 1, 59, -480), -480, 3), d(2026, 3, 7));
    });
    test('fall-back: the repeated hour stays in one day', () {
      // 2026-11-01 01:30 happens twice in US Pacific. Both are before 3 am.
      final first = dayOf(ts(2026, 11, 1, 1, 30, -420), -420, 3);
      final second = dayOf(ts(2026, 11, 1, 1, 30, -480), -480, 3);
      expect(first, d(2026, 10, 31));
      expect(second, d(2026, 10, 31));
    });
    test('time-zone travel: the same instant can be different local days', () {
      // 2026-06-10 20:00 UTC is 01:30 on the 11th in India (before 3 am, so
      // still the 10th) and 13:00 on the 10th in California.
      final inst = DateTime.utc(2026, 6, 10, 20, 0).millisecondsSinceEpoch;
      expect(dayOf(inst, 330, 3), d(2026, 6, 10));
      expect(dayOf(inst, -420, 3), d(2026, 6, 10));
      // Flying east: a session at 23:00 IST and one 10 hours later in Tokyo
      // (+540) land on consecutive days, no gap and no double count.
      final a = ts(2026, 6, 10, 23, 0, 330);
      final b = a + 10 * msPerHour;
      expect(dayOf(b, 540, 3) - dayOf(a, 330, 3), 1);
    });
    test('fraction of day left', () {
      final m = Moment(ts(2026, 1, 5, 15, 0, ist), ist);
      expect(dayFractionLeft(m, 3), closeTo(0.5, 1e-9));
      expect(m.minuteOfDay, 15 * 60);
    });
    test('month keys and weekdays', () {
      expect(monthKey(d(2026, 12, 31)) + 1, monthKey(d(2027, 1, 1)));
      expect(weekdayOf(d(2026, 11, 11)), DateTime.wednesday);
    });
  });

  group('streak engine', () {
    test('empty', () {
      final r = computeStreak({}, 100);
      expect(r.current, 0);
      expect(r.state, StreakState.none);
      expect(r.freezesLeft, 2);
    });
    test('consecutive days count, today pending until done', () {
      final s = d(2026, 5, 1);
      var r = computeStreak(range(s, 5), s + 4);
      expect([r.current, r.longest, r.totalDays], [5, 5, 5]);
      expect(r.state, StreakState.active);
      r = computeStreak(range(s, 5), s + 5);
      expect(r.current, 5);
      expect(r.state, StreakState.pending);
      expect(r.freezesLeft, 2);
    });
    test('one miss is covered by a freeze automatically', () {
      final s = d(2026, 5, 1);
      final r = computeStreak({s, s + 1, s + 3}, s + 3);
      expect(r.current, 3);
      expect(r.frozenDays, {s + 2});
      expect(r.freezesLeft, 1);
      expect(r.missedDays, isEmpty);
      expect(r.comebacks, 0);
    });
    test('two freezes per month, then pause, then break', () {
      final s = d(2026, 5, 1);
      final days = range(s, 3); // 1,2,3 May active; then nothing
      var r = computeStreak(days, s + 4); // 4th missed (frozen), today = 5th
      expect([r.current, r.freezesLeft, r.state], [3, 1, StreakState.pending]);
      r = computeStreak(days, s + 5); // 4th, 5th frozen
      expect([r.current, r.freezesLeft, r.state], [3, 0, StreakState.pending]);
      r = computeStreak(days, s + 6); // 6th missed, no freeze: paused
      expect([r.current, r.state], [3, StreakState.paused]);
      expect(r.missedDays, {s + 5});
      r = computeStreak(days, s + 7); // 6th and 7th missed: broken
      expect([r.current, r.longest, r.state, r.breaks], [0, 3, StreakState.none, 1]);
    });
    test('never miss twice: acting on the paused day keeps the count', () {
      final s = d(2026, 5, 1);
      // freezes burnt on the 4th and 5th, miss on the 6th, back on the 7th.
      final r = computeStreak({...range(s, 3), s + 6}, s + 6);
      expect(r.current, 4);
      expect(r.state, StreakState.active);
      expect(r.comebacks, 1);
      expect(r.breaks, 0);
    });
    test('freezes do not roll over and reset on the 1st', () {
      final s = d(2026, 5, 28);
      // Active 28, 29 May. Miss 30, 31 May (2 freezes). Miss 1 June: June freeze.
      var r = computeStreak({s, s + 1}, d(2026, 6, 2));
      expect(r.frozenDays, {d(2026, 5, 30), d(2026, 5, 31), d(2026, 6, 1)});
      expect(r.current, 2);
      expect(r.freezesLeft, 1);
      // An unused May allowance does not add to June.
      r = computeStreak(range(d(2026, 5, 1), 31), d(2026, 6, 1));
      expect(r.freezesLeft, 2);
    });
    test('year boundary uses the new month allowance', () {
      final r = computeStreak({d(2026, 12, 28)}, d(2027, 1, 3));
      // 29, 30 Dec frozen; 31 Dec uncovered miss; 1, 2 Jan frozen by January.
      expect(r.frozenDays,
          {d(2026, 12, 29), d(2026, 12, 30), d(2027, 1, 1), d(2027, 1, 2)});
      expect(r.missedDays, {d(2026, 12, 31)});
      expect(r.state, StreakState.paused);
      expect(r.current, 1);
    });
    test('no freezes are spent when there is no streak to protect', () {
      final s = d(2026, 5, 1);
      final r = computeStreak({s, s + 20}, s + 20);
      // s+1, s+2 frozen, s+3 pause, s+4 break. Nothing spent after that.
      expect(r.frozenDays.length, 2);
      expect(r.current, 1);
      expect(r.longest, 1);
      expect(r.comebacks, 1);
    });
    test('future days are ignored', () {
      final r = computeStreak({10, 11, 50}, 11);
      expect(r.current, 2);
      expect(r.totalDays, 2);
    });
    test('feature 55: decay keeps a share of the streak on a break', () {
      final s = d(2026, 5, 1);
      final r = computeStreak(range(s, 10), s + 14,
          rules: const StreakRules(decayKeepPercent: 80));
      expect(r.current, 8);
      expect(r.longest, 10);
    });
    test('feature 53: a 7-day run earns a freeze', () {
      final s = d(2026, 5, 1);
      final r = computeStreak(range(s, 7), s + 7,
          rules: const StreakRules(earnFreezeEvery: 7));
      expect(r.freezesLeft, 3);
    });
    test('feature 48 and 59: rest weekdays and paused days are not misses', () {
      final mon = d(2026, 11, 9);
      final days = {mon, mon + 1, mon + 2, mon + 3, mon + 4, mon + 5, mon + 7};
      var r = computeStreak(days, mon + 7,
          rules: const StreakRules(freezesPerMonth: 0, restWeekdays: {7}));
      expect(r.current, 7);
      expect(r.missedDays, isEmpty);
      r = computeStreak({mon, mon + 3}, mon + 3,
          rules: StreakRules(freezesPerMonth: 0, pausedDays: {mon + 1, mon + 2}));
      expect(r.current, 2);
    });
  });
}
