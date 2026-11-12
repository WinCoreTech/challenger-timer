import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('229 levels follow a slow curve', () {
    expect([levelFor(0), levelFor(99), levelFor(100), levelFor(399), levelFor(400), levelFor(10000)], [1, 1, 2, 2, 3, 11]);
    expect(xpForLevel(3), 400);
  });

  test('230 shown rank slips after idle weeks but unlocks stay; 247 prestige', () async {
    final r = Rig();
    await r.session();
    await r.app.log(Ev.tool, {'n': 0, 'xp': 5000});
    final real = r.v.rank.index;
    expect(shownRank(r.v).index, real);
    r.clock.advance(const Duration(days: 15));
    expect(idleSteps(r.v), 2);
    expect(shownRank(r.v).index, real - 2);
    expect(r.v.rank.index, real, reason: 'feature gating uses the real rank');
    await r.session();
    expect(shownRank(r.v).index, r.v.rank.index);
    await r.app.log(Ev.tool, {'n': 0, 'xp': 60000});
    expect(prestige(r.v), 1);
    expect(shownRank(r.v).index, lessThan(r.v.ranks.length - 1));
  });

  test('236 chests are fixed per session and about one in four', () {
    final ids = [for (var i = 0; i < 400; i++) 'sid-$i'];
    final hits = ids.where((s) => chestFor(s) > 0).length;
    expect(hits, inInclusiveRange(60, 140));
    expect(chestFor('sid-7'), chestFor('sid-7'));
    expect(ids.map(chestFor).every((x) => x == 0 || (x >= 10 && x <= 50)), isTrue);
  });

  test('237 quests, 238/239 coins and the reward shop, 240 savings jar', () async {
    final r = Rig();
    expect(dailyQuests(r.v, r.v.today).where((q) => q.$2), isEmpty);
    await r.session();
    await r.app.saveProof(type: 'text', value: 'x', parkingNote: 'Open page 2');
    expect(dailyQuests(r.v, r.v.today).every((q) => q.$2), isTrue);
    expect(r.v.xpExtras, contains(('Daily quests', 30)));
    expect(coins(r.v), 6);
    await r.app.log(Ev.tool, {'n': 239, 'coins': 4, 'reward': 'Chai'});
    expect(coins(r.v), 2);
    await r.app.setKv('jarAmount', '20');
    expect(savingsJar(r.v), 20);
  });

  test('244 seasons and 245 records', () async {
    final r = Rig();
    await r.session(minutes: 25);
    await r.session(minutes: 15);
    r.clock.advance(const Duration(days: 1));
    await r.session(minutes: 5);
    final rec = records(r.v);
    expect([rec.bestDayMinutes, rec.bestWeekMinutes, rec.longestStreak, rec.longestSession], [40, 45, 2, 25]);
    expect(seasons(r.v).now, 45);
    expect(combo(r.v), 1);
  });
}
