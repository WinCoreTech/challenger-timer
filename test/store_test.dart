import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/data/drift_store.dart';
import 'package:challenger_timer/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, Store Function()>{
    'memory': MemoryStore.new,
    'drift (SQLite)': DriftStore.memory,
  }.entries) {
    test('${entry.key} store round-trips events, records and settings', () async {
      final s = entry.value();
      final a = await s.addEvent(const Event(
          type: Ev.sessionStart, ts: 1000, offsetMin: 330, day: 7, payload: {'sid': 'x', 'minutes': 2}));
      final b = await s.addEvent(const Event(type: Ev.habitTick, ts: 2000, offsetMin: -60, day: 8));
      expect(b.id, greaterThan(a.id));
      final ev = await s.allEvents();
      expect(ev.map((e) => e.type), [Ev.sessionStart, Ev.habitTick]);
      expect(ev.first.payload['minutes'], 2);
      expect(ev.last.offsetMin, -60);

      await s.putRec(const Rec(id: 'r1', kind: Kind.habit, created: 5, data: {'name': 'Open book'}));
      await s.putRec(const Rec(id: 'r1', kind: Kind.habit, created: 5, data: {'name': 'Open notebook'}));
      await s.putRec(const Rec(id: 'r2', kind: Kind.project, created: 6));
      expect((await s.allRecs()).length, 2);
      expect((await s.allRecs()).firstWhere((r) => r.id == 'r1').str('name'), 'Open notebook');
      await s.deleteRec('r2');
      expect((await s.allRecs()).length, 1);

      await s.setKv('a', '1');
      await s.setKv('a', '2');
      await s.setKv('b', 'x');
      await s.setKv('b', null);
      expect(await s.allKv(), {'a': '2'});

      await s.wipe();
      expect(await s.allEvents(), isEmpty);
      expect(await s.allRecs(), isEmpty);
      expect(await s.allKv(), isEmpty);
    });
  }
}
