// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SosMessagesTable extends SosMessages
    with TableInfo<$SosMessagesTable, SosMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SosMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    type,
    message,
    latitude,
    longitude,
    status,
    syncState,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sos_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<SosMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SosMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SosMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SosMessagesTable createAlias(String alias) {
    return $SosMessagesTable(attachedDatabase, alias);
  }
}

class SosMessage extends DataClass implements Insertable<SosMessage> {
  final String id;
  final String ownerId;
  final String type;
  final String? message;
  final double? latitude;
  final double? longitude;
  final String status;
  final String syncState;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SosMessage({
    required this.id,
    required this.ownerId,
    required this.type,
    this.message,
    this.latitude,
    this.longitude,
    required this.status,
    required this.syncState,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['status'] = Variable<String>(status);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SosMessagesCompanion toCompanion(bool nullToAbsent) {
    return SosMessagesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      type: Value(type),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      status: Value(status),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SosMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SosMessage(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      type: serializer.fromJson<String>(json['type']),
      message: serializer.fromJson<String?>(json['message']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      status: serializer.fromJson<String>(json['status']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'type': serializer.toJson<String>(type),
      'message': serializer.toJson<String?>(message),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'status': serializer.toJson<String>(status),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SosMessage copyWith({
    String? id,
    String? ownerId,
    String? type,
    Value<String?> message = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    String? status,
    String? syncState,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SosMessage(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    type: type ?? this.type,
    message: message.present ? message.value : this.message,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    status: status ?? this.status,
    syncState: syncState ?? this.syncState,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SosMessage copyWithCompanion(SosMessagesCompanion data) {
    return SosMessage(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      type: data.type.present ? data.type.value : this.type,
      message: data.message.present ? data.message.value : this.message,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      status: data.status.present ? data.status.value : this.status,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SosMessage(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('type: $type, ')
          ..write('message: $message, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('status: $status, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    type,
    message,
    latitude,
    longitude,
    status,
    syncState,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SosMessage &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.type == this.type &&
          other.message == this.message &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.status == this.status &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SosMessagesCompanion extends UpdateCompanion<SosMessage> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> type;
  final Value<String?> message;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> status;
  final Value<String> syncState;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SosMessagesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.type = const Value.absent(),
    this.message = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.status = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SosMessagesCompanion.insert({
    required String id,
    required String ownerId,
    required String type,
    this.message = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required String status,
    required String syncState,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       type = Value(type),
       status = Value(status),
       syncState = Value(syncState),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SosMessage> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? type,
    Expression<String>? message,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? status,
    Expression<String>? syncState,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (type != null) 'type': type,
      if (message != null) 'message': message,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (status != null) 'status': status,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SosMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? type,
    Value<String?>? message,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String>? status,
    Value<String>? syncState,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SosMessagesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      message: message ?? this.message,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SosMessagesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('type: $type, ')
          ..write('message: $message, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('status: $status, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SosSyncQueueTable extends SosSyncQueue
    with TableInfo<$SosSyncQueueTable, SosSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SosSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queueIdMeta = const VerificationMeta(
    'queueId',
  );
  @override
  late final GeneratedColumn<int> queueId = GeneratedColumn<int>(
    'queue_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sosIdMeta = const VerificationMeta('sosId');
  @override
  late final GeneratedColumn<String> sosId = GeneratedColumn<String>(
    'sos_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    queueId,
    sosId,
    ownerId,
    operation,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sos_sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SosSyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('queue_id')) {
      context.handle(
        _queueIdMeta,
        queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta),
      );
    }
    if (data.containsKey('sos_id')) {
      context.handle(
        _sosIdMeta,
        sosId.isAcceptableOrUnknown(data['sos_id']!, _sosIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sosIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {queueId};
  @override
  SosSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SosSyncQueueData(
      queueId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_id'],
      )!,
      sosId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sos_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SosSyncQueueTable createAlias(String alias) {
    return $SosSyncQueueTable(attachedDatabase, alias);
  }
}

class SosSyncQueueData extends DataClass
    implements Insertable<SosSyncQueueData> {
  final int queueId;
  final String sosId;
  final String ownerId;
  final String operation;
  final String? payload;
  final DateTime createdAt;
  const SosSyncQueueData({
    required this.queueId,
    required this.sosId,
    required this.ownerId,
    required this.operation,
    this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['queue_id'] = Variable<int>(queueId);
    map['sos_id'] = Variable<String>(sosId);
    map['owner_id'] = Variable<String>(ownerId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SosSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SosSyncQueueCompanion(
      queueId: Value(queueId),
      sosId: Value(sosId),
      ownerId: Value(ownerId),
      operation: Value(operation),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory SosSyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SosSyncQueueData(
      queueId: serializer.fromJson<int>(json['queueId']),
      sosId: serializer.fromJson<String>(json['sosId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queueId': serializer.toJson<int>(queueId),
      'sosId': serializer.toJson<String>(sosId),
      'ownerId': serializer.toJson<String>(ownerId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SosSyncQueueData copyWith({
    int? queueId,
    String? sosId,
    String? ownerId,
    String? operation,
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
  }) => SosSyncQueueData(
    queueId: queueId ?? this.queueId,
    sosId: sosId ?? this.sosId,
    ownerId: ownerId ?? this.ownerId,
    operation: operation ?? this.operation,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  SosSyncQueueData copyWithCompanion(SosSyncQueueCompanion data) {
    return SosSyncQueueData(
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      sosId: data.sosId.present ? data.sosId.value : this.sosId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SosSyncQueueData(')
          ..write('queueId: $queueId, ')
          ..write('sosId: $sosId, ')
          ..write('ownerId: $ownerId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(queueId, sosId, ownerId, operation, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SosSyncQueueData &&
          other.queueId == this.queueId &&
          other.sosId == this.sosId &&
          other.ownerId == this.ownerId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class SosSyncQueueCompanion extends UpdateCompanion<SosSyncQueueData> {
  final Value<int> queueId;
  final Value<String> sosId;
  final Value<String> ownerId;
  final Value<String> operation;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  const SosSyncQueueCompanion({
    this.queueId = const Value.absent(),
    this.sosId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SosSyncQueueCompanion.insert({
    this.queueId = const Value.absent(),
    required String sosId,
    required String ownerId,
    required String operation,
    this.payload = const Value.absent(),
    required DateTime createdAt,
  }) : sosId = Value(sosId),
       ownerId = Value(ownerId),
       operation = Value(operation),
       createdAt = Value(createdAt);
  static Insertable<SosSyncQueueData> custom({
    Expression<int>? queueId,
    Expression<String>? sosId,
    Expression<String>? ownerId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (queueId != null) 'queue_id': queueId,
      if (sosId != null) 'sos_id': sosId,
      if (ownerId != null) 'owner_id': ownerId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SosSyncQueueCompanion copyWith({
    Value<int>? queueId,
    Value<String>? sosId,
    Value<String>? ownerId,
    Value<String>? operation,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
  }) {
    return SosSyncQueueCompanion(
      queueId: queueId ?? this.queueId,
      sosId: sosId ?? this.sosId,
      ownerId: ownerId ?? this.ownerId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queueId.present) {
      map['queue_id'] = Variable<int>(queueId.value);
    }
    if (sosId.present) {
      map['sos_id'] = Variable<String>(sosId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SosSyncQueueCompanion(')
          ..write('queueId: $queueId, ')
          ..write('sosId: $sosId, ')
          ..write('ownerId: $ownerId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BleOutboxTable extends BleOutbox
    with TableInfo<$BleOutboxTable, BleOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sosIdMeta = const VerificationMeta('sosId');
  @override
  late final GeneratedColumn<String> sosId = GeneratedColumn<String>(
    'sos_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<String> destinationId = GeneratedColumn<String>(
    'destination_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acknowledgedAtMeta = const VerificationMeta(
    'acknowledgedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acknowledgedAt =
      GeneratedColumn<DateTime>(
        'acknowledged_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    sosId,
    destinationId,
    schemaVersion,
    payload,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    lastError,
    createdAt,
    updatedAt,
    acknowledgedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('sos_id')) {
      context.handle(
        _sosIdMeta,
        sosId.isAcceptableOrUnknown(data['sos_id']!, _sosIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sosIdMeta);
    }
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('acknowledged_at')) {
      context.handle(
        _acknowledgedAtMeta,
        acknowledgedAt.isAcceptableOrUnknown(
          data['acknowledged_at']!,
          _acknowledgedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  BleOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleOutboxData(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      sosId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sos_id'],
      )!,
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_id'],
      ),
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      acknowledgedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acknowledged_at'],
      ),
    );
  }

  @override
  $BleOutboxTable createAlias(String alias) {
    return $BleOutboxTable(attachedDatabase, alias);
  }
}

class BleOutboxData extends DataClass implements Insertable<BleOutboxData> {
  final String messageId;
  final String sosId;
  final String? destinationId;
  final int schemaVersion;
  final String payload;
  final String state;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acknowledgedAt;
  const BleOutboxData({
    required this.messageId,
    required this.sosId,
    this.destinationId,
    required this.schemaVersion,
    required this.payload,
    required this.state,
    required this.retryCount,
    this.nextRetryAt,
    this.lastAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.acknowledgedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['sos_id'] = Variable<String>(sosId);
    if (!nullToAbsent || destinationId != null) {
      map['destination_id'] = Variable<String>(destinationId);
    }
    map['schema_version'] = Variable<int>(schemaVersion);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || acknowledgedAt != null) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt);
    }
    return map;
  }

  BleOutboxCompanion toCompanion(bool nullToAbsent) {
    return BleOutboxCompanion(
      messageId: Value(messageId),
      sosId: Value(sosId),
      destinationId: destinationId == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationId),
      schemaVersion: Value(schemaVersion),
      payload: Value(payload),
      state: Value(state),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      acknowledgedAt: acknowledgedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acknowledgedAt),
    );
  }

  factory BleOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleOutboxData(
      messageId: serializer.fromJson<String>(json['messageId']),
      sosId: serializer.fromJson<String>(json['sosId']),
      destinationId: serializer.fromJson<String?>(json['destinationId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      acknowledgedAt: serializer.fromJson<DateTime?>(json['acknowledgedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'sosId': serializer.toJson<String>(sosId),
      'destinationId': serializer.toJson<String?>(destinationId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'acknowledgedAt': serializer.toJson<DateTime?>(acknowledgedAt),
    };
  }

  BleOutboxData copyWith({
    String? messageId,
    String? sosId,
    Value<String?> destinationId = const Value.absent(),
    int? schemaVersion,
    String? payload,
    String? state,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> acknowledgedAt = const Value.absent(),
  }) => BleOutboxData(
    messageId: messageId ?? this.messageId,
    sosId: sosId ?? this.sosId,
    destinationId: destinationId.present
        ? destinationId.value
        : this.destinationId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    acknowledgedAt: acknowledgedAt.present
        ? acknowledgedAt.value
        : this.acknowledgedAt,
  );
  BleOutboxData copyWithCompanion(BleOutboxCompanion data) {
    return BleOutboxData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      sosId: data.sosId.present ? data.sosId.value : this.sosId,
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      acknowledgedAt: data.acknowledgedAt.present
          ? data.acknowledgedAt.value
          : this.acknowledgedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleOutboxData(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('destinationId: $destinationId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    sosId,
    destinationId,
    schemaVersion,
    payload,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    lastError,
    createdAt,
    updatedAt,
    acknowledgedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleOutboxData &&
          other.messageId == this.messageId &&
          other.sosId == this.sosId &&
          other.destinationId == this.destinationId &&
          other.schemaVersion == this.schemaVersion &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.acknowledgedAt == this.acknowledgedAt);
}

class BleOutboxCompanion extends UpdateCompanion<BleOutboxData> {
  final Value<String> messageId;
  final Value<String> sosId;
  final Value<String?> destinationId;
  final Value<int> schemaVersion;
  final Value<String> payload;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> acknowledgedAt;
  final Value<int> rowid;
  const BleOutboxCompanion({
    this.messageId = const Value.absent(),
    this.sosId = const Value.absent(),
    this.destinationId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleOutboxCompanion.insert({
    required String messageId,
    required String sosId,
    this.destinationId = const Value.absent(),
    required int schemaVersion,
    required String payload,
    required String state,
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.acknowledgedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       sosId = Value(sosId),
       schemaVersion = Value(schemaVersion),
       payload = Value(payload),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BleOutboxData> custom({
    Expression<String>? messageId,
    Expression<String>? sosId,
    Expression<String>? destinationId,
    Expression<int>? schemaVersion,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? acknowledgedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (sosId != null) 'sos_id': sosId,
      if (destinationId != null) 'destination_id': destinationId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleOutboxCompanion copyWith({
    Value<String>? messageId,
    Value<String>? sosId,
    Value<String?>? destinationId,
    Value<int>? schemaVersion,
    Value<String>? payload,
    Value<String>? state,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime?>? lastAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? acknowledgedAt,
    Value<int>? rowid,
  }) {
    return BleOutboxCompanion(
      messageId: messageId ?? this.messageId,
      sosId: sosId ?? this.sosId,
      destinationId: destinationId ?? this.destinationId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (sosId.present) {
      map['sos_id'] = Variable<String>(sosId.value);
    }
    if (destinationId.present) {
      map['destination_id'] = Variable<String>(destinationId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (acknowledgedAt.present) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BleOutboxCompanion(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('destinationId: $destinationId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BleInboxTable extends BleInbox
    with TableInfo<$BleInboxTable, BleInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleInboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sosIdMeta = const VerificationMeta('sosId');
  @override
  late final GeneratedColumn<String> sosId = GeneratedColumn<String>(
    'sos_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderDeviceIdMeta = const VerificationMeta(
    'senderDeviceId',
  );
  @override
  late final GeneratedColumn<String> senderDeviceId = GeneratedColumn<String>(
    'sender_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
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
  static const VerificationMeta _processingStateMeta = const VerificationMeta(
    'processingState',
  );
  @override
  late final GeneratedColumn<String> processingState = GeneratedColumn<String>(
    'processing_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persistedAtMeta = const VerificationMeta(
    'persistedAt',
  );
  @override
  late final GeneratedColumn<DateTime> persistedAt = GeneratedColumn<DateTime>(
    'persisted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acknowledgementStatusMeta =
      const VerificationMeta('acknowledgementStatus');
  @override
  late final GeneratedColumn<String> acknowledgementStatus =
      GeneratedColumn<String>(
        'acknowledgement_status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    sosId,
    senderDeviceId,
    schemaVersion,
    payload,
    processingState,
    receivedAt,
    persistedAt,
    acknowledgementStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('sos_id')) {
      context.handle(
        _sosIdMeta,
        sosId.isAcceptableOrUnknown(data['sos_id']!, _sosIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sosIdMeta);
    }
    if (data.containsKey('sender_device_id')) {
      context.handle(
        _senderDeviceIdMeta,
        senderDeviceId.isAcceptableOrUnknown(
          data['sender_device_id']!,
          _senderDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('processing_state')) {
      context.handle(
        _processingStateMeta,
        processingState.isAcceptableOrUnknown(
          data['processing_state']!,
          _processingStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processingStateMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('persisted_at')) {
      context.handle(
        _persistedAtMeta,
        persistedAt.isAcceptableOrUnknown(
          data['persisted_at']!,
          _persistedAtMeta,
        ),
      );
    }
    if (data.containsKey('acknowledgement_status')) {
      context.handle(
        _acknowledgementStatusMeta,
        acknowledgementStatus.isAcceptableOrUnknown(
          data['acknowledgement_status']!,
          _acknowledgementStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  BleInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleInboxData(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      sosId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sos_id'],
      )!,
      senderDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_device_id'],
      ),
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      processingState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_state'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      persistedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}persisted_at'],
      ),
      acknowledgementStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acknowledgement_status'],
      ),
    );
  }

  @override
  $BleInboxTable createAlias(String alias) {
    return $BleInboxTable(attachedDatabase, alias);
  }
}

class BleInboxData extends DataClass implements Insertable<BleInboxData> {
  final String messageId;
  final String sosId;
  final String? senderDeviceId;
  final int schemaVersion;
  final String payload;
  final String processingState;
  final DateTime receivedAt;
  final DateTime? persistedAt;
  final String? acknowledgementStatus;
  const BleInboxData({
    required this.messageId,
    required this.sosId,
    this.senderDeviceId,
    required this.schemaVersion,
    required this.payload,
    required this.processingState,
    required this.receivedAt,
    this.persistedAt,
    this.acknowledgementStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['sos_id'] = Variable<String>(sosId);
    if (!nullToAbsent || senderDeviceId != null) {
      map['sender_device_id'] = Variable<String>(senderDeviceId);
    }
    map['schema_version'] = Variable<int>(schemaVersion);
    map['payload'] = Variable<String>(payload);
    map['processing_state'] = Variable<String>(processingState);
    map['received_at'] = Variable<DateTime>(receivedAt);
    if (!nullToAbsent || persistedAt != null) {
      map['persisted_at'] = Variable<DateTime>(persistedAt);
    }
    if (!nullToAbsent || acknowledgementStatus != null) {
      map['acknowledgement_status'] = Variable<String>(acknowledgementStatus);
    }
    return map;
  }

  BleInboxCompanion toCompanion(bool nullToAbsent) {
    return BleInboxCompanion(
      messageId: Value(messageId),
      sosId: Value(sosId),
      senderDeviceId: senderDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderDeviceId),
      schemaVersion: Value(schemaVersion),
      payload: Value(payload),
      processingState: Value(processingState),
      receivedAt: Value(receivedAt),
      persistedAt: persistedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(persistedAt),
      acknowledgementStatus: acknowledgementStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(acknowledgementStatus),
    );
  }

  factory BleInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleInboxData(
      messageId: serializer.fromJson<String>(json['messageId']),
      sosId: serializer.fromJson<String>(json['sosId']),
      senderDeviceId: serializer.fromJson<String?>(json['senderDeviceId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      payload: serializer.fromJson<String>(json['payload']),
      processingState: serializer.fromJson<String>(json['processingState']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      persistedAt: serializer.fromJson<DateTime?>(json['persistedAt']),
      acknowledgementStatus: serializer.fromJson<String?>(
        json['acknowledgementStatus'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'sosId': serializer.toJson<String>(sosId),
      'senderDeviceId': serializer.toJson<String?>(senderDeviceId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'payload': serializer.toJson<String>(payload),
      'processingState': serializer.toJson<String>(processingState),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'persistedAt': serializer.toJson<DateTime?>(persistedAt),
      'acknowledgementStatus': serializer.toJson<String?>(
        acknowledgementStatus,
      ),
    };
  }

  BleInboxData copyWith({
    String? messageId,
    String? sosId,
    Value<String?> senderDeviceId = const Value.absent(),
    int? schemaVersion,
    String? payload,
    String? processingState,
    DateTime? receivedAt,
    Value<DateTime?> persistedAt = const Value.absent(),
    Value<String?> acknowledgementStatus = const Value.absent(),
  }) => BleInboxData(
    messageId: messageId ?? this.messageId,
    sosId: sosId ?? this.sosId,
    senderDeviceId: senderDeviceId.present
        ? senderDeviceId.value
        : this.senderDeviceId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    payload: payload ?? this.payload,
    processingState: processingState ?? this.processingState,
    receivedAt: receivedAt ?? this.receivedAt,
    persistedAt: persistedAt.present ? persistedAt.value : this.persistedAt,
    acknowledgementStatus: acknowledgementStatus.present
        ? acknowledgementStatus.value
        : this.acknowledgementStatus,
  );
  BleInboxData copyWithCompanion(BleInboxCompanion data) {
    return BleInboxData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      sosId: data.sosId.present ? data.sosId.value : this.sosId,
      senderDeviceId: data.senderDeviceId.present
          ? data.senderDeviceId.value
          : this.senderDeviceId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      processingState: data.processingState.present
          ? data.processingState.value
          : this.processingState,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      persistedAt: data.persistedAt.present
          ? data.persistedAt.value
          : this.persistedAt,
      acknowledgementStatus: data.acknowledgementStatus.present
          ? data.acknowledgementStatus.value
          : this.acknowledgementStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleInboxData(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payload: $payload, ')
          ..write('processingState: $processingState, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('persistedAt: $persistedAt, ')
          ..write('acknowledgementStatus: $acknowledgementStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    sosId,
    senderDeviceId,
    schemaVersion,
    payload,
    processingState,
    receivedAt,
    persistedAt,
    acknowledgementStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleInboxData &&
          other.messageId == this.messageId &&
          other.sosId == this.sosId &&
          other.senderDeviceId == this.senderDeviceId &&
          other.schemaVersion == this.schemaVersion &&
          other.payload == this.payload &&
          other.processingState == this.processingState &&
          other.receivedAt == this.receivedAt &&
          other.persistedAt == this.persistedAt &&
          other.acknowledgementStatus == this.acknowledgementStatus);
}

class BleInboxCompanion extends UpdateCompanion<BleInboxData> {
  final Value<String> messageId;
  final Value<String> sosId;
  final Value<String?> senderDeviceId;
  final Value<int> schemaVersion;
  final Value<String> payload;
  final Value<String> processingState;
  final Value<DateTime> receivedAt;
  final Value<DateTime?> persistedAt;
  final Value<String?> acknowledgementStatus;
  final Value<int> rowid;
  const BleInboxCompanion({
    this.messageId = const Value.absent(),
    this.sosId = const Value.absent(),
    this.senderDeviceId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.processingState = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.persistedAt = const Value.absent(),
    this.acknowledgementStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleInboxCompanion.insert({
    required String messageId,
    required String sosId,
    this.senderDeviceId = const Value.absent(),
    required int schemaVersion,
    required String payload,
    required String processingState,
    required DateTime receivedAt,
    this.persistedAt = const Value.absent(),
    this.acknowledgementStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       sosId = Value(sosId),
       schemaVersion = Value(schemaVersion),
       payload = Value(payload),
       processingState = Value(processingState),
       receivedAt = Value(receivedAt);
  static Insertable<BleInboxData> custom({
    Expression<String>? messageId,
    Expression<String>? sosId,
    Expression<String>? senderDeviceId,
    Expression<int>? schemaVersion,
    Expression<String>? payload,
    Expression<String>? processingState,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? persistedAt,
    Expression<String>? acknowledgementStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (sosId != null) 'sos_id': sosId,
      if (senderDeviceId != null) 'sender_device_id': senderDeviceId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (payload != null) 'payload': payload,
      if (processingState != null) 'processing_state': processingState,
      if (receivedAt != null) 'received_at': receivedAt,
      if (persistedAt != null) 'persisted_at': persistedAt,
      if (acknowledgementStatus != null)
        'acknowledgement_status': acknowledgementStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleInboxCompanion copyWith({
    Value<String>? messageId,
    Value<String>? sosId,
    Value<String?>? senderDeviceId,
    Value<int>? schemaVersion,
    Value<String>? payload,
    Value<String>? processingState,
    Value<DateTime>? receivedAt,
    Value<DateTime?>? persistedAt,
    Value<String?>? acknowledgementStatus,
    Value<int>? rowid,
  }) {
    return BleInboxCompanion(
      messageId: messageId ?? this.messageId,
      sosId: sosId ?? this.sosId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payload: payload ?? this.payload,
      processingState: processingState ?? this.processingState,
      receivedAt: receivedAt ?? this.receivedAt,
      persistedAt: persistedAt ?? this.persistedAt,
      acknowledgementStatus:
          acknowledgementStatus ?? this.acknowledgementStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (sosId.present) {
      map['sos_id'] = Variable<String>(sosId.value);
    }
    if (senderDeviceId.present) {
      map['sender_device_id'] = Variable<String>(senderDeviceId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (processingState.present) {
      map['processing_state'] = Variable<String>(processingState.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (persistedAt.present) {
      map['persisted_at'] = Variable<DateTime>(persistedAt.value);
    }
    if (acknowledgementStatus.present) {
      map['acknowledgement_status'] = Variable<String>(
        acknowledgementStatus.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BleInboxCompanion(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payload: $payload, ')
          ..write('processingState: $processingState, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('persistedAt: $persistedAt, ')
          ..write('acknowledgementStatus: $acknowledgementStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SosMessagesTable sosMessages = $SosMessagesTable(this);
  late final $SosSyncQueueTable sosSyncQueue = $SosSyncQueueTable(this);
  late final $BleOutboxTable bleOutbox = $BleOutboxTable(this);
  late final $BleInboxTable bleInbox = $BleInboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sosMessages,
    sosSyncQueue,
    bleOutbox,
    bleInbox,
  ];
}

typedef $$SosMessagesTableCreateCompanionBuilder =
    SosMessagesCompanion Function({
      required String id,
      required String ownerId,
      required String type,
      Value<String?> message,
      Value<double?> latitude,
      Value<double?> longitude,
      required String status,
      required String syncState,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SosMessagesTableUpdateCompanionBuilder =
    SosMessagesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> type,
      Value<String?> message,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> status,
      Value<String> syncState,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SosMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $SosMessagesTable> {
  $$SosMessagesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SosMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SosMessagesTable> {
  $$SosMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SosMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SosMessagesTable> {
  $$SosMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SosMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SosMessagesTable,
          SosMessage,
          $$SosMessagesTableFilterComposer,
          $$SosMessagesTableOrderingComposer,
          $$SosMessagesTableAnnotationComposer,
          $$SosMessagesTableCreateCompanionBuilder,
          $$SosMessagesTableUpdateCompanionBuilder,
          (
            SosMessage,
            BaseReferences<_$AppDatabase, $SosMessagesTable, SosMessage>,
          ),
          SosMessage,
          PrefetchHooks Function()
        > {
  $$SosMessagesTableTableManager(_$AppDatabase db, $SosMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SosMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SosMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SosMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SosMessagesCompanion(
                id: id,
                ownerId: ownerId,
                type: type,
                message: message,
                latitude: latitude,
                longitude: longitude,
                status: status,
                syncState: syncState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String type,
                Value<String?> message = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required String status,
                required String syncState,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SosMessagesCompanion.insert(
                id: id,
                ownerId: ownerId,
                type: type,
                message: message,
                latitude: latitude,
                longitude: longitude,
                status: status,
                syncState: syncState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SosMessagesTable, SosMessage>(table),
                  BaseReferences<_$AppDatabase, $SosMessagesTable, SosMessage>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SosMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SosMessagesTable,
      SosMessage,
      $$SosMessagesTableFilterComposer,
      $$SosMessagesTableOrderingComposer,
      $$SosMessagesTableAnnotationComposer,
      $$SosMessagesTableCreateCompanionBuilder,
      $$SosMessagesTableUpdateCompanionBuilder,
      (
        SosMessage,
        BaseReferences<_$AppDatabase, $SosMessagesTable, SosMessage>,
      ),
      SosMessage,
      PrefetchHooks Function()
    >;
typedef $$SosSyncQueueTableCreateCompanionBuilder =
    SosSyncQueueCompanion Function({
      Value<int> queueId,
      required String sosId,
      required String ownerId,
      required String operation,
      Value<String?> payload,
      required DateTime createdAt,
    });
typedef $$SosSyncQueueTableUpdateCompanionBuilder =
    SosSyncQueueCompanion Function({
      Value<int> queueId,
      Value<String> sosId,
      Value<String> ownerId,
      Value<String> operation,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });

class $$SosSyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SosSyncQueueTable> {
  $$SosSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SosSyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SosSyncQueueTable> {
  $$SosSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SosSyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SosSyncQueueTable> {
  $$SosSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<String> get sosId =>
      $composableBuilder(column: $table.sosId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SosSyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SosSyncQueueTable,
          SosSyncQueueData,
          $$SosSyncQueueTableFilterComposer,
          $$SosSyncQueueTableOrderingComposer,
          $$SosSyncQueueTableAnnotationComposer,
          $$SosSyncQueueTableCreateCompanionBuilder,
          $$SosSyncQueueTableUpdateCompanionBuilder,
          (
            SosSyncQueueData,
            BaseReferences<_$AppDatabase, $SosSyncQueueTable, SosSyncQueueData>,
          ),
          SosSyncQueueData,
          PrefetchHooks Function()
        > {
  $$SosSyncQueueTableTableManager(_$AppDatabase db, $SosSyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SosSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SosSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SosSyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                Value<String> sosId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SosSyncQueueCompanion(
                queueId: queueId,
                sosId: sosId,
                ownerId: ownerId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                required String sosId,
                required String ownerId,
                required String operation,
                Value<String?> payload = const Value.absent(),
                required DateTime createdAt,
              }) => SosSyncQueueCompanion.insert(
                queueId: queueId,
                sosId: sosId,
                ownerId: ownerId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SosSyncQueueTable, SosSyncQueueData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SosSyncQueueTable,
                    SosSyncQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SosSyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SosSyncQueueTable,
      SosSyncQueueData,
      $$SosSyncQueueTableFilterComposer,
      $$SosSyncQueueTableOrderingComposer,
      $$SosSyncQueueTableAnnotationComposer,
      $$SosSyncQueueTableCreateCompanionBuilder,
      $$SosSyncQueueTableUpdateCompanionBuilder,
      (
        SosSyncQueueData,
        BaseReferences<_$AppDatabase, $SosSyncQueueTable, SosSyncQueueData>,
      ),
      SosSyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$BleOutboxTableCreateCompanionBuilder = BleOutboxCompanion Function({
  required String messageId,
  required String sosId,
  Value<String?> destinationId,
  required int schemaVersion,
  required String payload,
  required String state,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> lastError,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> acknowledgedAt,
  Value<int> rowid,
});
typedef $$BleOutboxTableUpdateCompanionBuilder = BleOutboxCompanion Function({
  Value<String> messageId,
  Value<String> sosId,
  Value<String?> destinationId,
  Value<int> schemaVersion,
  Value<String> payload,
  Value<String> state,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> acknowledgedAt,
  Value<int> rowid,
});

class $$BleOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $BleOutboxTable> {
  $$BleOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BleOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $BleOutboxTable> {
  $$BleOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BleOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleOutboxTable> {
  $$BleOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get sosId =>
      $composableBuilder(column: $table.sosId, builder: (column) => column);

  GeneratedColumn<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => column,
  );
}

class $$BleOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleOutboxTable,
          BleOutboxData,
          $$BleOutboxTableFilterComposer,
          $$BleOutboxTableOrderingComposer,
          $$BleOutboxTableAnnotationComposer,
          $$BleOutboxTableCreateCompanionBuilder,
          $$BleOutboxTableUpdateCompanionBuilder,
          (
            BleOutboxData,
            BaseReferences<_$AppDatabase, $BleOutboxTable, BleOutboxData>,
          ),
          BleOutboxData,
          PrefetchHooks Function()
        > {
  $$BleOutboxTableTableManager(_$AppDatabase db, $BleOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> sosId = const Value.absent(),
                Value<String?> destinationId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> acknowledgedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleOutboxCompanion(
                messageId: messageId,
                sosId: sosId,
                destinationId: destinationId,
                schemaVersion: schemaVersion,
                payload: payload,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                acknowledgedAt: acknowledgedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String sosId,
                Value<String?> destinationId = const Value.absent(),
                required int schemaVersion,
                required String payload,
                required String state,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> acknowledgedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleOutboxCompanion.insert(
                messageId: messageId,
                sosId: sosId,
                destinationId: destinationId,
                schemaVersion: schemaVersion,
                payload: payload,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                acknowledgedAt: acknowledgedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BleOutboxTable, BleOutboxData>(table),
                  BaseReferences<_$AppDatabase, $BleOutboxTable, BleOutboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BleOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleOutboxTable,
      BleOutboxData,
      $$BleOutboxTableFilterComposer,
      $$BleOutboxTableOrderingComposer,
      $$BleOutboxTableAnnotationComposer,
      $$BleOutboxTableCreateCompanionBuilder,
      $$BleOutboxTableUpdateCompanionBuilder,
      (
        BleOutboxData,
        BaseReferences<_$AppDatabase, $BleOutboxTable, BleOutboxData>,
      ),
      BleOutboxData,
      PrefetchHooks Function()
    >;
typedef $$BleInboxTableCreateCompanionBuilder = BleInboxCompanion Function({
  required String messageId,
  required String sosId,
  Value<String?> senderDeviceId,
  required int schemaVersion,
  required String payload,
  required String processingState,
  required DateTime receivedAt,
  Value<DateTime?> persistedAt,
  Value<String?> acknowledgementStatus,
  Value<int> rowid,
});
typedef $$BleInboxTableUpdateCompanionBuilder = BleInboxCompanion Function({
  Value<String> messageId,
  Value<String> sosId,
  Value<String?> senderDeviceId,
  Value<int> schemaVersion,
  Value<String> payload,
  Value<String> processingState,
  Value<DateTime> receivedAt,
  Value<DateTime?> persistedAt,
  Value<String?> acknowledgementStatus,
  Value<int> rowid,
});

class $$BleInboxTableFilterComposer
    extends Composer<_$AppDatabase, $BleInboxTable> {
  $$BleInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get persistedAt => $composableBuilder(
    column: $table.persistedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acknowledgementStatus => $composableBuilder(
    column: $table.acknowledgementStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BleInboxTableOrderingComposer
    extends Composer<_$AppDatabase, $BleInboxTable> {
  $$BleInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sosId => $composableBuilder(
    column: $table.sosId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get persistedAt => $composableBuilder(
    column: $table.persistedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acknowledgementStatus => $composableBuilder(
    column: $table.acknowledgementStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BleInboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleInboxTable> {
  $$BleInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get sosId =>
      $composableBuilder(column: $table.sosId, builder: (column) => column);

  GeneratedColumn<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get persistedAt => $composableBuilder(
    column: $table.persistedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acknowledgementStatus => $composableBuilder(
    column: $table.acknowledgementStatus,
    builder: (column) => column,
  );
}

class $$BleInboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleInboxTable,
          BleInboxData,
          $$BleInboxTableFilterComposer,
          $$BleInboxTableOrderingComposer,
          $$BleInboxTableAnnotationComposer,
          $$BleInboxTableCreateCompanionBuilder,
          $$BleInboxTableUpdateCompanionBuilder,
          (
            BleInboxData,
            BaseReferences<_$AppDatabase, $BleInboxTable, BleInboxData>,
          ),
          BleInboxData,
          PrefetchHooks Function()
        > {
  $$BleInboxTableTableManager(_$AppDatabase db, $BleInboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> sosId = const Value.absent(),
                Value<String?> senderDeviceId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> processingState = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<DateTime?> persistedAt = const Value.absent(),
                Value<String?> acknowledgementStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleInboxCompanion(
                messageId: messageId,
                sosId: sosId,
                senderDeviceId: senderDeviceId,
                schemaVersion: schemaVersion,
                payload: payload,
                processingState: processingState,
                receivedAt: receivedAt,
                persistedAt: persistedAt,
                acknowledgementStatus: acknowledgementStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String sosId,
                Value<String?> senderDeviceId = const Value.absent(),
                required int schemaVersion,
                required String payload,
                required String processingState,
                required DateTime receivedAt,
                Value<DateTime?> persistedAt = const Value.absent(),
                Value<String?> acknowledgementStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleInboxCompanion.insert(
                messageId: messageId,
                sosId: sosId,
                senderDeviceId: senderDeviceId,
                schemaVersion: schemaVersion,
                payload: payload,
                processingState: processingState,
                receivedAt: receivedAt,
                persistedAt: persistedAt,
                acknowledgementStatus: acknowledgementStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BleInboxTable, BleInboxData>(table),
                  BaseReferences<_$AppDatabase, $BleInboxTable, BleInboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BleInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleInboxTable,
      BleInboxData,
      $$BleInboxTableFilterComposer,
      $$BleInboxTableOrderingComposer,
      $$BleInboxTableAnnotationComposer,
      $$BleInboxTableCreateCompanionBuilder,
      $$BleInboxTableUpdateCompanionBuilder,
      (
        BleInboxData,
        BaseReferences<_$AppDatabase, $BleInboxTable, BleInboxData>,
      ),
      BleInboxData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SosMessagesTableTableManager get sosMessages =>
      $$SosMessagesTableTableManager(_db, _db.sosMessages);
  $$SosSyncQueueTableTableManager get sosSyncQueue =>
      $$SosSyncQueueTableTableManager(_db, _db.sosSyncQueue);
  $$BleOutboxTableTableManager get bleOutbox =>
      $$BleOutboxTableTableManager(_db, _db.bleOutbox);
  $$BleInboxTableTableManager get bleInbox =>
      $$BleInboxTableTableManager(_db, _db.bleInbox);
}
