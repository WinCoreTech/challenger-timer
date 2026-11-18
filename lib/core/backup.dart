/// Versioned backup (reference spec 5.12). Pure Dart.
library;

import '../brand.dart';
import 'dart:convert';

import 'events.dart';

const int backupFormat = 2;
const String backupApp = appName;

class BackupError implements Exception {
  const BackupError(this.message);
  final String message;
  @override
  String toString() => message;
}

class Backup {
  const Backup(this.format, this.exportedAt, this.settings, this.events, this.recs, this.redacted);
  final int format, exportedAt;
  final Map<String, String> settings;
  final List<Event> events;
  final List<Rec> recs;
  final bool redacted;

  String get summary => '${events.length} events, ${recs.length} records, ${settings.length} settings'
      '${redacted ? ' (redacted: names and notes are placeholders)' : ''}';
}

String encodeBackup({required int nowMs, required Map<String, String> settings, required List<Event> events, required List<Rec> recs, bool redacted = false}) =>
    const JsonEncoder.withIndent(' ').convert({
      'app': backupApp,
      'format': backupFormat,
      'redacted': redacted,
      'exportedAt': nowMs,
      'settings': redacted ? _redactSettings(settings) : settings,
      'events': [for (final e in events) (redacted ? _redactEvent(e) : e).toJson()],
      'records': [for (final (i, r) in recs.indexed) (redacted ? _redactRec(r, i) : r).toJson()],
    });

const _textFields = {'name', 'title', 'value', 'text', 'why', 'tiny', 'front', 'back', 'enough', 'task', 'reason', 'proof'};
const _privateSettings = {'name', 'buddyName', 'buddyPhone', 'alarmImage', 'alarmVoice'};

Map<String, String> _redactSettings(Map<String, String> s) =>
    {for (final e in s.entries) if (!_privateSettings.contains(e.key) && !e.key.startsWith('t.')) e.key: e.value};

Map<String, Object?> _scrub(Map<String, Object?> data, String placeholder) => {
      for (final e in data.entries)
        e.key: _textFields.contains(e.key) && e.value is String && (e.value! as String).isNotEmpty
            ? placeholder
            : e.key == 'a' || e.key == 'reasons'
                ? [for (final _ in (e.value as List? ?? const [])) placeholder]
                : e.value
    };

Event _redactEvent(Event e) =>
    Event(id: e.id, type: e.type, ts: e.ts, offsetMin: e.offsetMin, day: e.day, payload: _scrub(e.payload, 'redacted'));
Rec _redactRec(Rec r, int i) => Rec(id: r.id, kind: r.kind, created: r.created, data: _scrub(r.data, '${r.kind} ${i + 1}'));

/// Parses a backup file. Accepts format 1 (builds up to 18, no "format"
/// field) and format 2. Throws [BackupError] with a plain message otherwise.
Backup decodeBackup(String text) {
  final Object? j;
  try {
    j = jsonDecode(text);
  } on FormatException {
    throw const BackupError('This file is not a backup: it is not valid JSON.');
  }
  if (j is! Map || (j['app'] != backupApp && !legacyAppNames.contains(j['app'])) || j['events'] is! List || j['records'] is! List) {
    throw const BackupError('This file is not a $appName backup.');
  }
  final format = j['format'] as int? ?? 1;
  if (format > backupFormat) {
    throw BackupError('This backup was made by a newer version of the app (format $format). Update the app, then load it.');
  }
  try {
    return Backup(
        format,
        j['exportedAt'] as int? ?? 0,
        (j['settings'] as Map? ?? const {}).map((k, v) => MapEntry('$k', '$v')),
        [for (final e in j['events'] as List) Event.fromJson((e as Map).cast<String, Object?>())],
        [for (final r in j['records'] as List) Rec.fromJson((r as Map).cast<String, Object?>())],
        j['redacted'] == true);
  } catch (_) {
    throw const BackupError('This backup is damaged: some rows could not be read. Nothing was changed.');
  }
}
