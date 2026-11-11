import '../core/events.dart';

/// Storage boundary. The app talks to this interface only, so tests use
/// [MemoryStore] and the phone uses the Drift (SQLite) implementation.
abstract class Store {
  Future<List<Event>> allEvents();
  Future<Event> addEvent(Event e);
  Future<List<Rec>> allRecs();
  Future<void> putRec(Rec r);
  Future<void> deleteRec(String id);
  Future<Map<String, String>> allKv();
  Future<void> setKv(String key, String? value);
  Future<void> wipe();
}

class MemoryStore implements Store {
  final List<Event> events = [];
  final Map<String, Rec> recs = {};
  final Map<String, String> kv = {};
  int _next = 1;

  @override
  Future<Event> addEvent(Event e) async {
    final saved = e.withId(_next++);
    events.add(saved);
    return saved;
  }

  @override
  Future<List<Event>> allEvents() async => List.of(events);
  @override
  Future<List<Rec>> allRecs() async => recs.values.toList();
  @override
  Future<Map<String, String>> allKv() async => Map.of(kv);
  @override
  Future<void> deleteRec(String id) async => recs.remove(id);
  @override
  Future<void> putRec(Rec r) async => recs[r.id] = r;
  @override
  Future<void> setKv(String key, String? value) async =>
      value == null ? kv.remove(key) : kv[key] = value;
  @override
  Future<void> wipe() async {
    events.clear();
    recs.clear();
    kv.clear();
  }
}
