/// Event log model. Every user action is one immutable row. Streaks, XP, rank,
/// bonus and stats are all computed from these rows and never stored.
library;

import 'dart:convert';
import 'day.dart';

/// Event type names. Kept as strings so old logs stay readable.
abstract final class Ev {
  static const sessionStart = 'session_start'; // sid, minutes, projectId, taskId, source
  static const sessionDone = 'session_done'; // sid, minutes
  static const sessionAbandon = 'session_abandon'; // sid, elapsedSec
  static const sessionExtend = 'session_extend'; // sid, minutes
  static const proof = 'proof'; // sid, recId, kind
  static const habitTick = 'habit_tick'; // habitId
  static const parkingNote = 'parking_note'; // text, projectId
  static const planSet = 'plan_set'; // forDay, task, cueMinute
  static const taskDone = 'task_done'; // taskId
  static const appOpen = 'app_open';
  static const onboarded = 'onboarded';
  static const setting = 'setting'; // key, value
  static const buddyReport = 'buddy_report'; // channel
  static const tool = 'tool'; // feature, plus free fields
}

class Event {
  const Event({
    this.id = 0,
    required this.type,
    required this.ts,
    required this.offsetMin,
    required this.day,
    this.payload = const {},
  });

  factory Event.at(Moment m, int dayEndHour, String type, [Map<String, Object?> payload = const {}]) =>
      Event(type: type, ts: m.ms, offsetMin: m.offsetMin, day: m.day(dayEndHour), payload: payload);

  factory Event.fromJson(Map<String, Object?> j) => Event(
      id: j['id'] as int? ?? 0,
      type: j['type'] as String,
      ts: j['ts'] as int,
      offsetMin: j['offsetMin'] as int,
      day: j['day'] as int,
      payload: (j['payload'] as Map?)?.cast<String, Object?>() ?? const {});

  final int id;
  final String type;

  /// UTC milliseconds since epoch.
  final int ts;

  /// Local UTC offset in minutes when the event happened.
  final int offsetMin;

  /// Logical day number, frozen at write time (see day.dart).
  final int day;
  final Map<String, Object?> payload;

  Moment get moment => Moment(ts, offsetMin);
  String get payloadJson => jsonEncode(payload);
  T? get<T>(String k) => payload[k] is T ? payload[k] as T : null;
  Event withId(int id) =>
      Event(id: id, type: type, ts: ts, offsetMin: offsetMin, day: day, payload: payload);

  Map<String, Object?> toJson() =>
      {'id': id, 'type': type, 'ts': ts, 'offsetMin': offsetMin, 'day': day, 'payload': payload};
}

/// A stored thing the user made: habit, project, task, proof, list entry...
/// [kind] names the collection, [data] is free-form JSON.
class Rec {
  const Rec({required this.id, required this.kind, required this.created, this.data = const {}});
  factory Rec.fromJson(Map<String, Object?> j) => Rec(
      id: j['id'] as String,
      kind: j['kind'] as String,
      created: j['created'] as int,
      data: (j['data'] as Map?)?.cast<String, Object?>() ?? const {});
  final String id;
  final String kind;
  final int created;
  final Map<String, Object?> data;

  String str(String k, [String or = '']) => data[k] is String ? data[k] as String : or;
  int integer(String k, [int or = 0]) => data[k] is num ? (data[k] as num).toInt() : or;
  bool flag(String k) => data[k] == true;
  Rec copy(Map<String, Object?> patch) =>
      Rec(id: id, kind: kind, created: created, data: {...data, ...patch});
  Map<String, Object?> toJson() => {'id': id, 'kind': kind, 'created': created, 'data': data};
}

abstract final class Kind {
  static const habit = 'habit'; // name, tiny, archived
  static const project = 'project'; // name, why, archived
  static const task = 'task'; // projectId, title, done
  static const proof = 'proof'; // sid, projectId, type(photo|link|text), value, day
}
