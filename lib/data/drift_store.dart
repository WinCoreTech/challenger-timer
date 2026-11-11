import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/events.dart';
import 'store.dart';

part 'drift_store.g.dart';

@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  IntColumn get ts => integer()();
  IntColumn get offsetMin => integer()();
  IntColumn get day => integer()();
  TextColumn get payload => text()();
}

@DataClassName('RecRow')
class Recs extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get created => integer()();
  TextColumn get data => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KvRow')
class Kvs extends Table {
  TextColumn get k => text()();
  TextColumn get v => text()();
  @override
  Set<Column> get primaryKey => {k};
}

@DriftDatabase(tables: [Events, Recs, Kvs])
class AppDb extends _$AppDb {
  AppDb(super.e);
  @override
  int get schemaVersion => 1;
}

class DriftStore implements Store {
  DriftStore(this.db);
  factory DriftStore.memory() => DriftStore(AppDb(NativeDatabase.memory()));
  static Future<DriftStore> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return DriftStore(AppDb(NativeDatabase.createInBackground(File(p.join(dir.path, 'pct.sqlite')))));
  }

  final AppDb db;

  @override
  Future<Event> addEvent(Event e) async {
    final id = await db.into(db.events).insert(EventsCompanion.insert(
        type: e.type, ts: e.ts, offsetMin: e.offsetMin, day: e.day, payload: e.payloadJson));
    return e.withId(id);
  }

  @override
  Future<List<Event>> allEvents() async {
    final rows = await (db.select(db.events)..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
    return [
      for (final r in rows)
        Event(
            id: r.id,
            type: r.type,
            ts: r.ts,
            offsetMin: r.offsetMin,
            day: r.day,
            payload: (jsonDecode(r.payload) as Map).cast<String, Object?>())
    ];
  }

  @override
  Future<List<Rec>> allRecs() async {
    final rows = await db.select(db.recs).get();
    return [
      for (final r in rows)
        Rec(
            id: r.id,
            kind: r.kind,
            created: r.created,
            data: (jsonDecode(r.data) as Map).cast<String, Object?>())
    ];
  }

  @override
  Future<void> putRec(Rec r) => db.into(db.recs).insertOnConflictUpdate(
      RecsCompanion.insert(id: r.id, kind: r.kind, created: r.created, data: jsonEncode(r.data)));

  @override
  Future<void> deleteRec(String id) => (db.delete(db.recs)..where((t) => t.id.equals(id))).go();

  @override
  Future<Map<String, String>> allKv() async =>
      {for (final r in await db.select(db.kvs).get()) r.k: r.v};

  @override
  Future<void> setKv(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.kvs)..where((t) => t.k.equals(key))).go();
    } else {
      await db.into(db.kvs).insertOnConflictUpdate(KvsCompanion.insert(k: key, v: value));
    }
  }

  @override
  Future<void> wipe() => db.transaction(() async {
        await db.delete(db.events).go();
        await db.delete(db.recs).go();
        await db.delete(db.kvs).go();
      });
}
