import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/data/drift_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Records and events are JSON documents, so rows written by an older build
/// (fewer fields) must keep loading and computing after new fields are added.
void main() {
  test('rows in the oldest shape survive and still compute on real SQLite', () async {
    final store = DriftStore.memory();
    // Shapes exactly as release build-2 wrote them.
    await store.putRec(const Rec(id: 'p1', kind: Kind.project, created: 1, data: {'name': 'DSA'}));
    await store.putRec(const Rec(id: 't1', kind: Kind.task, created: 2, data: {'projectId': 'p1', 'title': 'Arrays', 'done': false}));
    await store.addEvent(const Event(type: Ev.sessionStart, ts: 1000, offsetMin: 330, day: 20000, payload: {'sid': 's', 'minutes': 2}));
    await store.addEvent(const Event(type: Ev.sessionDone, ts: 2000, offsetMin: 330, day: 20000, payload: {'sid': 's', 'minutes': 2}));
    await store.setKv('name', 'Winzo');

    final recs = await store.allRecs();
    final events = await store.allEvents();
    expect(recs.length, 2);
    expect(events.length, 2);
    final p = recs.firstWhere((r) => r.id == 'p1');
    // Fields added later read as their defaults.
    expect(p.str('parentId'), '');
    expect(p.integer('workMin'), 0);
    expect(p.flag('archived'), isFalse);
    expect(events.last.get<String>('mode'), isNull);

    // A new build writes extra fields into the same row without a migration.
    await store.putRec(p.copy({'parentId': '', 'workMin': 50}));
    expect((await store.allRecs()).firstWhere((r) => r.id == 'p1').integer('workMin'), 50);
    expect((await store.allRecs()).firstWhere((r) => r.id == 'p1').str('name'), 'DSA');
    expect(store.db.schemaVersion, 1);
  });

  test('an export from an old build loads into the engine', () async {
    final r = Rig();
    await r.session();
    expect(r.v.metrics['sessions'], 1);
    expect(r.v.projects, isEmpty);
  });
}
