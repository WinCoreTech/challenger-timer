// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_store.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMinMeta = const VerificationMeta(
    'offsetMin',
  );
  @override
  late final GeneratedColumn<int> offsetMin = GeneratedColumn<int>(
    'offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, type, ts, offsetMin, day, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('offset_min')) {
      context.handle(
        _offsetMinMeta,
        offsetMin.isAcceptableOrUnknown(data['offset_min']!, _offsetMinMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMinMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      offsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_min'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;
  final String type;
  final int ts;
  final int offsetMin;
  final int day;
  final String payload;
  const EventRow({
    required this.id,
    required this.type,
    required this.ts,
    required this.offsetMin,
    required this.day,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['ts'] = Variable<int>(ts);
    map['offset_min'] = Variable<int>(offsetMin);
    map['day'] = Variable<int>(day);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      type: Value(type),
      ts: Value(ts),
      offsetMin: Value(offsetMin),
      day: Value(day),
      payload: Value(payload),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      ts: serializer.fromJson<int>(json['ts']),
      offsetMin: serializer.fromJson<int>(json['offsetMin']),
      day: serializer.fromJson<int>(json['day']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'ts': serializer.toJson<int>(ts),
      'offsetMin': serializer.toJson<int>(offsetMin),
      'day': serializer.toJson<int>(day),
      'payload': serializer.toJson<String>(payload),
    };
  }

  EventRow copyWith({
    int? id,
    String? type,
    int? ts,
    int? offsetMin,
    int? day,
    String? payload,
  }) => EventRow(
    id: id ?? this.id,
    type: type ?? this.type,
    ts: ts ?? this.ts,
    offsetMin: offsetMin ?? this.offsetMin,
    day: day ?? this.day,
    payload: payload ?? this.payload,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      ts: data.ts.present ? data.ts.value : this.ts,
      offsetMin: data.offsetMin.present ? data.offsetMin.value : this.offsetMin,
      day: data.day.present ? data.day.value : this.day,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('ts: $ts, ')
          ..write('offsetMin: $offsetMin, ')
          ..write('day: $day, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, ts, offsetMin, day, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.ts == this.ts &&
          other.offsetMin == this.offsetMin &&
          other.day == this.day &&
          other.payload == this.payload);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<String> type;
  final Value<int> ts;
  final Value<int> offsetMin;
  final Value<int> day;
  final Value<String> payload;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.ts = const Value.absent(),
    this.offsetMin = const Value.absent(),
    this.day = const Value.absent(),
    this.payload = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required int ts,
    required int offsetMin,
    required int day,
    required String payload,
  }) : type = Value(type),
       ts = Value(ts),
       offsetMin = Value(offsetMin),
       day = Value(day),
       payload = Value(payload);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<int>? ts,
    Expression<int>? offsetMin,
    Expression<int>? day,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (ts != null) 'ts': ts,
      if (offsetMin != null) 'offset_min': offsetMin,
      if (day != null) 'day': day,
      if (payload != null) 'payload': payload,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<int>? ts,
    Value<int>? offsetMin,
    Value<int>? day,
    Value<String>? payload,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      ts: ts ?? this.ts,
      offsetMin: offsetMin ?? this.offsetMin,
      day: day ?? this.day,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (offsetMin.present) {
      map['offset_min'] = Variable<int>(offsetMin.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('ts: $ts, ')
          ..write('offsetMin: $offsetMin, ')
          ..write('day: $day, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $RecsTable extends Recs with TableInfo<$RecsTable, RecRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<int> created = GeneratedColumn<int>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, created, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $RecsTable createAlias(String alias) {
    return $RecsTable(attachedDatabase, alias);
  }
}

class RecRow extends DataClass implements Insertable<RecRow> {
  final String id;
  final String kind;
  final int created;
  final String data;
  const RecRow({
    required this.id,
    required this.kind,
    required this.created,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['created'] = Variable<int>(created);
    map['data'] = Variable<String>(data);
    return map;
  }

  RecsCompanion toCompanion(bool nullToAbsent) {
    return RecsCompanion(
      id: Value(id),
      kind: Value(kind),
      created: Value(created),
      data: Value(data),
    );
  }

  factory RecRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      created: serializer.fromJson<int>(json['created']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'created': serializer.toJson<int>(created),
      'data': serializer.toJson<String>(data),
    };
  }

  RecRow copyWith({String? id, String? kind, int? created, String? data}) =>
      RecRow(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        created: created ?? this.created,
        data: data ?? this.data,
      );
  RecRow copyWithCompanion(RecsCompanion data) {
    return RecRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      created: data.created.present ? data.created.value : this.created,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('created: $created, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, created, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.created == this.created &&
          other.data == this.data);
}

class RecsCompanion extends UpdateCompanion<RecRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<int> created;
  final Value<String> data;
  final Value<int> rowid;
  const RecsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.created = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecsCompanion.insert({
    required String id,
    required String kind,
    required int created,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       created = Value(created),
       data = Value(data);
  static Insertable<RecRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<int>? created,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (created != null) 'created': created,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<int>? created,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return RecsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      created: created ?? this.created,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(created.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('created: $created, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvsTable extends Kvs with TableInfo<$KvsTable, KvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kMeta = const VerificationMeta('k');
  @override
  late final GeneratedColumn<String> k = GeneratedColumn<String>(
    'k',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vMeta = const VerificationMeta('v');
  @override
  late final GeneratedColumn<String> v = GeneratedColumn<String>(
    'v',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [k, v];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kvs';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('k')) {
      context.handle(_kMeta, k.isAcceptableOrUnknown(data['k']!, _kMeta));
    } else if (isInserting) {
      context.missing(_kMeta);
    }
    if (data.containsKey('v')) {
      context.handle(_vMeta, v.isAcceptableOrUnknown(data['v']!, _vMeta));
    } else if (isInserting) {
      context.missing(_vMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {k};
  @override
  KvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvRow(
      k: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}k'],
      )!,
      v: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}v'],
      )!,
    );
  }

  @override
  $KvsTable createAlias(String alias) {
    return $KvsTable(attachedDatabase, alias);
  }
}

class KvRow extends DataClass implements Insertable<KvRow> {
  final String k;
  final String v;
  const KvRow({required this.k, required this.v});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['k'] = Variable<String>(k);
    map['v'] = Variable<String>(v);
    return map;
  }

  KvsCompanion toCompanion(bool nullToAbsent) {
    return KvsCompanion(k: Value(k), v: Value(v));
  }

  factory KvRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvRow(
      k: serializer.fromJson<String>(json['k']),
      v: serializer.fromJson<String>(json['v']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'k': serializer.toJson<String>(k),
      'v': serializer.toJson<String>(v),
    };
  }

  KvRow copyWith({String? k, String? v}) =>
      KvRow(k: k ?? this.k, v: v ?? this.v);
  KvRow copyWithCompanion(KvsCompanion data) {
    return KvRow(
      k: data.k.present ? data.k.value : this.k,
      v: data.v.present ? data.v.value : this.v,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvRow(')
          ..write('k: $k, ')
          ..write('v: $v')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(k, v);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvRow && other.k == this.k && other.v == this.v);
}

class KvsCompanion extends UpdateCompanion<KvRow> {
  final Value<String> k;
  final Value<String> v;
  final Value<int> rowid;
  const KvsCompanion({
    this.k = const Value.absent(),
    this.v = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvsCompanion.insert({
    required String k,
    required String v,
    this.rowid = const Value.absent(),
  }) : k = Value(k),
       v = Value(v);
  static Insertable<KvRow> custom({
    Expression<String>? k,
    Expression<String>? v,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (k != null) 'k': k,
      if (v != null) 'v': v,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvsCompanion copyWith({
    Value<String>? k,
    Value<String>? v,
    Value<int>? rowid,
  }) {
    return KvsCompanion(
      k: k ?? this.k,
      v: v ?? this.v,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (k.present) {
      map['k'] = Variable<String>(k.value);
    }
    if (v.present) {
      map['v'] = Variable<String>(v.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvsCompanion(')
          ..write('k: $k, ')
          ..write('v: $v, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $RecsTable recs = $RecsTable(this);
  late final $KvsTable kvs = $KvsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [events, recs, kvs];
}

typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  required String type,
  required int ts,
  required int offsetMin,
  required int day,
  required String payload,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<int> ts,
  Value<int> offsetMin,
  Value<int> day,
  Value<String> payload,
});

class $$EventsTableFilterComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMin => $composableBuilder(
    column: $table.offsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMin => $composableBuilder(
    column: $table.offsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get offsetMin =>
      $composableBuilder(column: $table.offsetMin, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDb, $EventsTable, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDb db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<int> offsetMin = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                type: type,
                ts: ts,
                offsetMin: offsetMin,
                day: day,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required int ts,
                required int offsetMin,
                required int day,
                required String payload,
              }) => EventsCompanion.insert(
                id: id,
                type: type,
                ts: ts,
                offsetMin: offsetMin,
                day: day,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventsTable, EventRow>(table),
                  BaseReferences<_$AppDb, $EventsTable, EventRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDb, $EventsTable, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $$RecsTableCreateCompanionBuilder = RecsCompanion Function({
  required String id,
  required String kind,
  required int created,
  required String data,
  Value<int> rowid,
});
typedef $$RecsTableUpdateCompanionBuilder = RecsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<int> created,
  Value<String> data,
  Value<int> rowid,
});

class $$RecsTableFilterComposer extends Composer<_$AppDb, $RecsTable> {
  $$RecsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecsTableOrderingComposer extends Composer<_$AppDb, $RecsTable> {
  $$RecsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecsTableAnnotationComposer extends Composer<_$AppDb, $RecsTable> {
  $$RecsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$RecsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RecsTable,
          RecRow,
          $$RecsTableFilterComposer,
          $$RecsTableOrderingComposer,
          $$RecsTableAnnotationComposer,
          $$RecsTableCreateCompanionBuilder,
          $$RecsTableUpdateCompanionBuilder,
          (RecRow, BaseReferences<_$AppDb, $RecsTable, RecRow>),
          RecRow,
          PrefetchHooks Function()
        > {
  $$RecsTableTableManager(_$AppDb db, $RecsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecsCompanion(
                id: id,
                kind: kind,
                created: created,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required int created,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => RecsCompanion.insert(
                id: id,
                kind: kind,
                created: created,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecsTable, RecRow>(table),
                  BaseReferences<_$AppDb, $RecsTable, RecRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RecsTable,
      RecRow,
      $$RecsTableFilterComposer,
      $$RecsTableOrderingComposer,
      $$RecsTableAnnotationComposer,
      $$RecsTableCreateCompanionBuilder,
      $$RecsTableUpdateCompanionBuilder,
      (RecRow, BaseReferences<_$AppDb, $RecsTable, RecRow>),
      RecRow,
      PrefetchHooks Function()
    >;
typedef $$KvsTableCreateCompanionBuilder = KvsCompanion Function({
  required String k,
  required String v,
  Value<int> rowid,
});
typedef $$KvsTableUpdateCompanionBuilder = KvsCompanion Function({
  Value<String> k,
  Value<String> v,
  Value<int> rowid,
});

class $$KvsTableFilterComposer extends Composer<_$AppDb, $KvsTable> {
  $$KvsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvsTableOrderingComposer extends Composer<_$AppDb, $KvsTable> {
  $$KvsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvsTableAnnotationComposer extends Composer<_$AppDb, $KvsTable> {
  $$KvsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get k =>
      $composableBuilder(column: $table.k, builder: (column) => column);

  GeneratedColumn<String> get v =>
      $composableBuilder(column: $table.v, builder: (column) => column);
}

class $$KvsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $KvsTable,
          KvRow,
          $$KvsTableFilterComposer,
          $$KvsTableOrderingComposer,
          $$KvsTableAnnotationComposer,
          $$KvsTableCreateCompanionBuilder,
          $$KvsTableUpdateCompanionBuilder,
          (KvRow, BaseReferences<_$AppDb, $KvsTable, KvRow>),
          KvRow,
          PrefetchHooks Function()
        > {
  $$KvsTableTableManager(_$AppDb db, $KvsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> k = const Value.absent(),
            Value<String> v = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KvsCompanion(k: k, v: v, rowid: rowid),
          createCompanionCallback: ({
            required String k,
            required String v,
            Value<int> rowid = const Value.absent(),
          }) => KvsCompanion.insert(k: k, v: v, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KvsTable, KvRow>(table),
                  BaseReferences<_$AppDb, $KvsTable, KvRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $KvsTable,
      KvRow,
      $$KvsTableFilterComposer,
      $$KvsTableOrderingComposer,
      $$KvsTableAnnotationComposer,
      $$KvsTableCreateCompanionBuilder,
      $$KvsTableUpdateCompanionBuilder,
      (KvRow, BaseReferences<_$AppDb, $KvsTable, KvRow>),
      KvRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$RecsTableTableManager get recs => $$RecsTableTableManager(_db, _db.recs);
  $$KvsTableTableManager get kvs => $$KvsTableTableManager(_db, _db.kvs);
}
