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

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientIdMeta = const VerificationMeta(
    'recipientId',
  );
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
    'recipient_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
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
  static const VerificationMeta _deliveryStatusMeta = const VerificationMeta(
    'deliveryStatus',
  );
  @override
  late final GeneratedColumn<String> deliveryStatus = GeneratedColumn<String>(
    'delivery_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attachmentPathMeta = const VerificationMeta(
    'attachmentPath',
  );
  @override
  late final GeneratedColumn<String> attachmentPath = GeneratedColumn<String>(
    'attachment_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentMimeTypeMeta =
      const VerificationMeta('attachmentMimeType');
  @override
  late final GeneratedColumn<String> attachmentMimeType =
      GeneratedColumn<String>(
        'attachment_mime_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentNameMeta = const VerificationMeta(
    'attachmentName',
  );
  @override
  late final GeneratedColumn<String> attachmentName = GeneratedColumn<String>(
    'attachment_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteMessageIdMeta = const VerificationMeta(
    'remoteMessageId',
  );
  @override
  late final GeneratedColumn<String> remoteMessageId = GeneratedColumn<String>(
    'remote_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transportMetadataMeta = const VerificationMeta(
    'transportMetadata',
  );
  @override
  late final GeneratedColumn<String> transportMetadata =
      GeneratedColumn<String>(
        'transport_metadata',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    sosId,
    ownerId,
    senderId,
    recipientId,
    messageType,
    textContent,
    createdAt,
    deliveryStatus,
    attachmentPath,
    attachmentMimeType,
    attachmentName,
    remoteMessageId,
    transportMetadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
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
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
        _recipientIdMeta,
        recipientId.isAcceptableOrUnknown(
          data['recipient_id']!,
          _recipientIdMeta,
        ),
      );
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
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
    if (data.containsKey('delivery_status')) {
      context.handle(
        _deliveryStatusMeta,
        deliveryStatus.isAcceptableOrUnknown(
          data['delivery_status']!,
          _deliveryStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deliveryStatusMeta);
    }
    if (data.containsKey('attachment_path')) {
      context.handle(
        _attachmentPathMeta,
        attachmentPath.isAcceptableOrUnknown(
          data['attachment_path']!,
          _attachmentPathMeta,
        ),
      );
    }
    if (data.containsKey('attachment_mime_type')) {
      context.handle(
        _attachmentMimeTypeMeta,
        attachmentMimeType.isAcceptableOrUnknown(
          data['attachment_mime_type']!,
          _attachmentMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('attachment_name')) {
      context.handle(
        _attachmentNameMeta,
        attachmentName.isAcceptableOrUnknown(
          data['attachment_name']!,
          _attachmentNameMeta,
        ),
      );
    }
    if (data.containsKey('remote_message_id')) {
      context.handle(
        _remoteMessageIdMeta,
        remoteMessageId.isAcceptableOrUnknown(
          data['remote_message_id']!,
          _remoteMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('transport_metadata')) {
      context.handle(
        _transportMetadataMeta,
        transportMetadata.isAcceptableOrUnknown(
          data['transport_metadata']!,
          _transportMetadataMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      sosId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sos_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      recipientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_id'],
      ),
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deliveryStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_status'],
      )!,
      attachmentPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_path'],
      ),
      attachmentMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_mime_type'],
      ),
      attachmentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_name'],
      ),
      remoteMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_message_id'],
      ),
      transportMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport_metadata'],
      ),
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String messageId;
  final String sosId;
  final String ownerId;
  final String senderId;
  final String? recipientId;
  final String messageType;
  final String? textContent;
  final DateTime createdAt;
  final String deliveryStatus;
  final String? attachmentPath;
  final String? attachmentMimeType;
  final String? attachmentName;
  final String? remoteMessageId;
  final String? transportMetadata;
  const ChatMessage({
    required this.messageId,
    required this.sosId,
    required this.ownerId,
    required this.senderId,
    this.recipientId,
    required this.messageType,
    this.textContent,
    required this.createdAt,
    required this.deliveryStatus,
    this.attachmentPath,
    this.attachmentMimeType,
    this.attachmentName,
    this.remoteMessageId,
    this.transportMetadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['sos_id'] = Variable<String>(sosId);
    map['owner_id'] = Variable<String>(ownerId);
    map['sender_id'] = Variable<String>(senderId);
    if (!nullToAbsent || recipientId != null) {
      map['recipient_id'] = Variable<String>(recipientId);
    }
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['delivery_status'] = Variable<String>(deliveryStatus);
    if (!nullToAbsent || attachmentPath != null) {
      map['attachment_path'] = Variable<String>(attachmentPath);
    }
    if (!nullToAbsent || attachmentMimeType != null) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType);
    }
    if (!nullToAbsent || attachmentName != null) {
      map['attachment_name'] = Variable<String>(attachmentName);
    }
    if (!nullToAbsent || remoteMessageId != null) {
      map['remote_message_id'] = Variable<String>(remoteMessageId);
    }
    if (!nullToAbsent || transportMetadata != null) {
      map['transport_metadata'] = Variable<String>(transportMetadata);
    }
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      messageId: Value(messageId),
      sosId: Value(sosId),
      ownerId: Value(ownerId),
      senderId: Value(senderId),
      recipientId: recipientId == null && nullToAbsent
          ? const Value.absent()
          : Value(recipientId),
      messageType: Value(messageType),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      createdAt: Value(createdAt),
      deliveryStatus: Value(deliveryStatus),
      attachmentPath: attachmentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentPath),
      attachmentMimeType: attachmentMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentMimeType),
      attachmentName: attachmentName == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentName),
      remoteMessageId: remoteMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteMessageId),
      transportMetadata: transportMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(transportMetadata),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      messageId: serializer.fromJson<String>(json['messageId']),
      sosId: serializer.fromJson<String>(json['sosId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      recipientId: serializer.fromJson<String?>(json['recipientId']),
      messageType: serializer.fromJson<String>(json['messageType']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deliveryStatus: serializer.fromJson<String>(json['deliveryStatus']),
      attachmentPath: serializer.fromJson<String?>(json['attachmentPath']),
      attachmentMimeType: serializer.fromJson<String?>(
        json['attachmentMimeType'],
      ),
      attachmentName: serializer.fromJson<String?>(json['attachmentName']),
      remoteMessageId: serializer.fromJson<String?>(json['remoteMessageId']),
      transportMetadata: serializer.fromJson<String?>(
        json['transportMetadata'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'sosId': serializer.toJson<String>(sosId),
      'ownerId': serializer.toJson<String>(ownerId),
      'senderId': serializer.toJson<String>(senderId),
      'recipientId': serializer.toJson<String?>(recipientId),
      'messageType': serializer.toJson<String>(messageType),
      'textContent': serializer.toJson<String?>(textContent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deliveryStatus': serializer.toJson<String>(deliveryStatus),
      'attachmentPath': serializer.toJson<String?>(attachmentPath),
      'attachmentMimeType': serializer.toJson<String?>(attachmentMimeType),
      'attachmentName': serializer.toJson<String?>(attachmentName),
      'remoteMessageId': serializer.toJson<String?>(remoteMessageId),
      'transportMetadata': serializer.toJson<String?>(transportMetadata),
    };
  }

  ChatMessage copyWith({
    String? messageId,
    String? sosId,
    String? ownerId,
    String? senderId,
    Value<String?> recipientId = const Value.absent(),
    String? messageType,
    Value<String?> textContent = const Value.absent(),
    DateTime? createdAt,
    String? deliveryStatus,
    Value<String?> attachmentPath = const Value.absent(),
    Value<String?> attachmentMimeType = const Value.absent(),
    Value<String?> attachmentName = const Value.absent(),
    Value<String?> remoteMessageId = const Value.absent(),
    Value<String?> transportMetadata = const Value.absent(),
  }) => ChatMessage(
    messageId: messageId ?? this.messageId,
    sosId: sosId ?? this.sosId,
    ownerId: ownerId ?? this.ownerId,
    senderId: senderId ?? this.senderId,
    recipientId: recipientId.present ? recipientId.value : this.recipientId,
    messageType: messageType ?? this.messageType,
    textContent: textContent.present ? textContent.value : this.textContent,
    createdAt: createdAt ?? this.createdAt,
    deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    attachmentPath: attachmentPath.present
        ? attachmentPath.value
        : this.attachmentPath,
    attachmentMimeType: attachmentMimeType.present
        ? attachmentMimeType.value
        : this.attachmentMimeType,
    attachmentName: attachmentName.present
        ? attachmentName.value
        : this.attachmentName,
    remoteMessageId: remoteMessageId.present
        ? remoteMessageId.value
        : this.remoteMessageId,
    transportMetadata: transportMetadata.present
        ? transportMetadata.value
        : this.transportMetadata,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      sosId: data.sosId.present ? data.sosId.value : this.sosId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveryStatus: data.deliveryStatus.present
          ? data.deliveryStatus.value
          : this.deliveryStatus,
      attachmentPath: data.attachmentPath.present
          ? data.attachmentPath.value
          : this.attachmentPath,
      attachmentMimeType: data.attachmentMimeType.present
          ? data.attachmentMimeType.value
          : this.attachmentMimeType,
      attachmentName: data.attachmentName.present
          ? data.attachmentName.value
          : this.attachmentName,
      remoteMessageId: data.remoteMessageId.present
          ? data.remoteMessageId.value
          : this.remoteMessageId,
      transportMetadata: data.transportMetadata.present
          ? data.transportMetadata.value
          : this.transportMetadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('ownerId: $ownerId, ')
          ..write('senderId: $senderId, ')
          ..write('recipientId: $recipientId, ')
          ..write('messageType: $messageType, ')
          ..write('textContent: $textContent, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveryStatus: $deliveryStatus, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('attachmentName: $attachmentName, ')
          ..write('remoteMessageId: $remoteMessageId, ')
          ..write('transportMetadata: $transportMetadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    sosId,
    ownerId,
    senderId,
    recipientId,
    messageType,
    textContent,
    createdAt,
    deliveryStatus,
    attachmentPath,
    attachmentMimeType,
    attachmentName,
    remoteMessageId,
    transportMetadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.messageId == this.messageId &&
          other.sosId == this.sosId &&
          other.ownerId == this.ownerId &&
          other.senderId == this.senderId &&
          other.recipientId == this.recipientId &&
          other.messageType == this.messageType &&
          other.textContent == this.textContent &&
          other.createdAt == this.createdAt &&
          other.deliveryStatus == this.deliveryStatus &&
          other.attachmentPath == this.attachmentPath &&
          other.attachmentMimeType == this.attachmentMimeType &&
          other.attachmentName == this.attachmentName &&
          other.remoteMessageId == this.remoteMessageId &&
          other.transportMetadata == this.transportMetadata);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> messageId;
  final Value<String> sosId;
  final Value<String> ownerId;
  final Value<String> senderId;
  final Value<String?> recipientId;
  final Value<String> messageType;
  final Value<String?> textContent;
  final Value<DateTime> createdAt;
  final Value<String> deliveryStatus;
  final Value<String?> attachmentPath;
  final Value<String?> attachmentMimeType;
  final Value<String?> attachmentName;
  final Value<String?> remoteMessageId;
  final Value<String?> transportMetadata;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.messageId = const Value.absent(),
    this.sosId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.textContent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveryStatus = const Value.absent(),
    this.attachmentPath = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.attachmentName = const Value.absent(),
    this.remoteMessageId = const Value.absent(),
    this.transportMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String messageId,
    required String sosId,
    required String ownerId,
    required String senderId,
    this.recipientId = const Value.absent(),
    required String messageType,
    this.textContent = const Value.absent(),
    required DateTime createdAt,
    required String deliveryStatus,
    this.attachmentPath = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.attachmentName = const Value.absent(),
    this.remoteMessageId = const Value.absent(),
    this.transportMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       sosId = Value(sosId),
       ownerId = Value(ownerId),
       senderId = Value(senderId),
       messageType = Value(messageType),
       createdAt = Value(createdAt),
       deliveryStatus = Value(deliveryStatus);
  static Insertable<ChatMessage> custom({
    Expression<String>? messageId,
    Expression<String>? sosId,
    Expression<String>? ownerId,
    Expression<String>? senderId,
    Expression<String>? recipientId,
    Expression<String>? messageType,
    Expression<String>? textContent,
    Expression<DateTime>? createdAt,
    Expression<String>? deliveryStatus,
    Expression<String>? attachmentPath,
    Expression<String>? attachmentMimeType,
    Expression<String>? attachmentName,
    Expression<String>? remoteMessageId,
    Expression<String>? transportMetadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (sosId != null) 'sos_id': sosId,
      if (ownerId != null) 'owner_id': ownerId,
      if (senderId != null) 'sender_id': senderId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (messageType != null) 'message_type': messageType,
      if (textContent != null) 'text_content': textContent,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveryStatus != null) 'delivery_status': deliveryStatus,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
      if (attachmentMimeType != null)
        'attachment_mime_type': attachmentMimeType,
      if (attachmentName != null) 'attachment_name': attachmentName,
      if (remoteMessageId != null) 'remote_message_id': remoteMessageId,
      if (transportMetadata != null) 'transport_metadata': transportMetadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? sosId,
    Value<String>? ownerId,
    Value<String>? senderId,
    Value<String?>? recipientId,
    Value<String>? messageType,
    Value<String?>? textContent,
    Value<DateTime>? createdAt,
    Value<String>? deliveryStatus,
    Value<String?>? attachmentPath,
    Value<String?>? attachmentMimeType,
    Value<String?>? attachmentName,
    Value<String?>? remoteMessageId,
    Value<String?>? transportMetadata,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      messageId: messageId ?? this.messageId,
      sosId: sosId ?? this.sosId,
      ownerId: ownerId ?? this.ownerId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      messageType: messageType ?? this.messageType,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentName: attachmentName ?? this.attachmentName,
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
      transportMetadata: transportMetadata ?? this.transportMetadata,
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
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deliveryStatus.present) {
      map['delivery_status'] = Variable<String>(deliveryStatus.value);
    }
    if (attachmentPath.present) {
      map['attachment_path'] = Variable<String>(attachmentPath.value);
    }
    if (attachmentMimeType.present) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType.value);
    }
    if (attachmentName.present) {
      map['attachment_name'] = Variable<String>(attachmentName.value);
    }
    if (remoteMessageId.present) {
      map['remote_message_id'] = Variable<String>(remoteMessageId.value);
    }
    if (transportMetadata.present) {
      map['transport_metadata'] = Variable<String>(transportMetadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('sosId: $sosId, ')
          ..write('ownerId: $ownerId, ')
          ..write('senderId: $senderId, ')
          ..write('recipientId: $recipientId, ')
          ..write('messageType: $messageType, ')
          ..write('textContent: $textContent, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveryStatus: $deliveryStatus, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('attachmentName: $attachmentName, ')
          ..write('remoteMessageId: $remoteMessageId, ')
          ..write('transportMetadata: $transportMetadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BleRelayMessagesTable extends BleRelayMessages
    with TableInfo<$BleRelayMessagesTable, BleRelayMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleRelayMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originKeyIdMeta = const VerificationMeta(
    'originKeyId',
  );
  @override
  late final GeneratedColumn<String> originKeyId = GeneratedColumn<String>(
    'origin_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originPublicKeyMeta = const VerificationMeta(
    'originPublicKey',
  );
  @override
  late final GeneratedColumn<String> originPublicKey = GeneratedColumn<String>(
    'origin_public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _immutablePayloadMeta = const VerificationMeta(
    'immutablePayload',
  );
  @override
  late final GeneratedColumn<String> immutablePayload = GeneratedColumn<String>(
    'immutable_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wireEnvelopeMeta = const VerificationMeta(
    'wireEnvelope',
  );
  @override
  late final GeneratedColumn<String> wireEnvelope = GeneratedColumn<String>(
    'wire_envelope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _immutableDigestMeta = const VerificationMeta(
    'immutableDigest',
  );
  @override
  late final GeneratedColumn<String> immutableDigest = GeneratedColumn<String>(
    'immutable_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originSignatureMeta = const VerificationMeta(
    'originSignature',
  );
  @override
  late final GeneratedColumn<String> originSignature = GeneratedColumn<String>(
    'origin_signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorizationScopeMeta =
      const VerificationMeta('authorizationScope');
  @override
  late final GeneratedColumn<String> authorizationScope =
      GeneratedColumn<String>(
        'authorization_scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _emergencyTypeMeta = const VerificationMeta(
    'emergencyType',
  );
  @override
  late final GeneratedColumn<String> emergencyType = GeneratedColumn<String>(
    'emergency_type',
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retentionDeadlineMeta = const VerificationMeta(
    'retentionDeadline',
  );
  @override
  late final GeneratedColumn<DateTime> retentionDeadline =
      GeneratedColumn<DateTime>(
        'retention_deadline',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _maxHopsMeta = const VerificationMeta(
    'maxHops',
  );
  @override
  late final GeneratedColumn<int> maxHops = GeneratedColumn<int>(
    'max_hops',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingHopCountMeta = const VerificationMeta(
    'incomingHopCount',
  );
  @override
  late final GeneratedColumn<int> incomingHopCount = GeneratedColumn<int>(
    'incoming_hop_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingPathMeta = const VerificationMeta(
    'incomingPath',
  );
  @override
  late final GeneratedColumn<String> incomingPath = GeneratedColumn<String>(
    'incoming_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingPeerIdMeta = const VerificationMeta(
    'incomingPeerId',
  );
  @override
  late final GeneratedColumn<String> incomingPeerId = GeneratedColumn<String>(
    'incoming_peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousHopKeyIdMeta = const VerificationMeta(
    'previousHopKeyId',
  );
  @override
  late final GeneratedColumn<String> previousHopKeyId = GeneratedColumn<String>(
    'previous_hop_key_id',
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
  static const VerificationMeta _payloadBytesMeta = const VerificationMeta(
    'payloadBytes',
  );
  @override
  late final GeneratedColumn<int> payloadBytes = GeneratedColumn<int>(
    'payload_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageBytesMeta = const VerificationMeta(
    'storageBytes',
  );
  @override
  late final GeneratedColumn<int> storageBytes = GeneratedColumn<int>(
    'storage_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalReceiptStateMeta = const VerificationMeta(
    'finalReceiptState',
  );
  @override
  late final GeneratedColumn<String> finalReceiptState =
      GeneratedColumn<String>(
        'final_receipt_state',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalRecipientKeyIdMeta =
      const VerificationMeta('finalRecipientKeyId');
  @override
  late final GeneratedColumn<String> finalRecipientKeyId =
      GeneratedColumn<String>(
        'final_recipient_key_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalAuthorizationIdMeta =
      const VerificationMeta('finalAuthorizationId');
  @override
  late final GeneratedColumn<String> finalAuthorizationId =
      GeneratedColumn<String>(
        'final_authorization_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalReceiptCorrelationIdMeta =
      const VerificationMeta('finalReceiptCorrelationId');
  @override
  late final GeneratedColumn<String> finalReceiptCorrelationId =
      GeneratedColumn<String>(
        'final_receipt_correlation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalRoutePeerDeviceIdMeta =
      const VerificationMeta('finalRoutePeerDeviceId');
  @override
  late final GeneratedColumn<String> finalRoutePeerDeviceId =
      GeneratedColumn<String>(
        'final_route_peer_device_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    originMessageId,
    incidentId,
    originKeyId,
    originPublicKey,
    immutablePayload,
    wireEnvelope,
    immutableDigest,
    originSignature,
    authorizationScope,
    emergencyType,
    createdAt,
    expiresAt,
    retentionDeadline,
    maxHops,
    incomingHopCount,
    incomingPath,
    incomingPeerId,
    previousHopKeyId,
    processingState,
    payloadBytes,
    storageBytes,
    receivedAt,
    persistedAt,
    finalReceiptState,
    finalRecipientKeyId,
    finalAuthorizationId,
    finalReceiptCorrelationId,
    finalRoutePeerDeviceId,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_relay_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleRelayMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('origin_key_id')) {
      context.handle(
        _originKeyIdMeta,
        originKeyId.isAcceptableOrUnknown(
          data['origin_key_id']!,
          _originKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originKeyIdMeta);
    }
    if (data.containsKey('origin_public_key')) {
      context.handle(
        _originPublicKeyMeta,
        originPublicKey.isAcceptableOrUnknown(
          data['origin_public_key']!,
          _originPublicKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originPublicKeyMeta);
    }
    if (data.containsKey('immutable_payload')) {
      context.handle(
        _immutablePayloadMeta,
        immutablePayload.isAcceptableOrUnknown(
          data['immutable_payload']!,
          _immutablePayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutablePayloadMeta);
    }
    if (data.containsKey('wire_envelope')) {
      context.handle(
        _wireEnvelopeMeta,
        wireEnvelope.isAcceptableOrUnknown(
          data['wire_envelope']!,
          _wireEnvelopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wireEnvelopeMeta);
    }
    if (data.containsKey('immutable_digest')) {
      context.handle(
        _immutableDigestMeta,
        immutableDigest.isAcceptableOrUnknown(
          data['immutable_digest']!,
          _immutableDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutableDigestMeta);
    }
    if (data.containsKey('origin_signature')) {
      context.handle(
        _originSignatureMeta,
        originSignature.isAcceptableOrUnknown(
          data['origin_signature']!,
          _originSignatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originSignatureMeta);
    }
    if (data.containsKey('authorization_scope')) {
      context.handle(
        _authorizationScopeMeta,
        authorizationScope.isAcceptableOrUnknown(
          data['authorization_scope']!,
          _authorizationScopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_authorizationScopeMeta);
    }
    if (data.containsKey('emergency_type')) {
      context.handle(
        _emergencyTypeMeta,
        emergencyType.isAcceptableOrUnknown(
          data['emergency_type']!,
          _emergencyTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emergencyTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('retention_deadline')) {
      context.handle(
        _retentionDeadlineMeta,
        retentionDeadline.isAcceptableOrUnknown(
          data['retention_deadline']!,
          _retentionDeadlineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retentionDeadlineMeta);
    }
    if (data.containsKey('max_hops')) {
      context.handle(
        _maxHopsMeta,
        maxHops.isAcceptableOrUnknown(data['max_hops']!, _maxHopsMeta),
      );
    } else if (isInserting) {
      context.missing(_maxHopsMeta);
    }
    if (data.containsKey('incoming_hop_count')) {
      context.handle(
        _incomingHopCountMeta,
        incomingHopCount.isAcceptableOrUnknown(
          data['incoming_hop_count']!,
          _incomingHopCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingHopCountMeta);
    }
    if (data.containsKey('incoming_path')) {
      context.handle(
        _incomingPathMeta,
        incomingPath.isAcceptableOrUnknown(
          data['incoming_path']!,
          _incomingPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingPathMeta);
    }
    if (data.containsKey('incoming_peer_id')) {
      context.handle(
        _incomingPeerIdMeta,
        incomingPeerId.isAcceptableOrUnknown(
          data['incoming_peer_id']!,
          _incomingPeerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingPeerIdMeta);
    }
    if (data.containsKey('previous_hop_key_id')) {
      context.handle(
        _previousHopKeyIdMeta,
        previousHopKeyId.isAcceptableOrUnknown(
          data['previous_hop_key_id']!,
          _previousHopKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousHopKeyIdMeta);
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
    if (data.containsKey('payload_bytes')) {
      context.handle(
        _payloadBytesMeta,
        payloadBytes.isAcceptableOrUnknown(
          data['payload_bytes']!,
          _payloadBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadBytesMeta);
    }
    if (data.containsKey('storage_bytes')) {
      context.handle(
        _storageBytesMeta,
        storageBytes.isAcceptableOrUnknown(
          data['storage_bytes']!,
          _storageBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageBytesMeta);
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
    } else if (isInserting) {
      context.missing(_persistedAtMeta);
    }
    if (data.containsKey('final_receipt_state')) {
      context.handle(
        _finalReceiptStateMeta,
        finalReceiptState.isAcceptableOrUnknown(
          data['final_receipt_state']!,
          _finalReceiptStateMeta,
        ),
      );
    }
    if (data.containsKey('final_recipient_key_id')) {
      context.handle(
        _finalRecipientKeyIdMeta,
        finalRecipientKeyId.isAcceptableOrUnknown(
          data['final_recipient_key_id']!,
          _finalRecipientKeyIdMeta,
        ),
      );
    }
    if (data.containsKey('final_authorization_id')) {
      context.handle(
        _finalAuthorizationIdMeta,
        finalAuthorizationId.isAcceptableOrUnknown(
          data['final_authorization_id']!,
          _finalAuthorizationIdMeta,
        ),
      );
    }
    if (data.containsKey('final_receipt_correlation_id')) {
      context.handle(
        _finalReceiptCorrelationIdMeta,
        finalReceiptCorrelationId.isAcceptableOrUnknown(
          data['final_receipt_correlation_id']!,
          _finalReceiptCorrelationIdMeta,
        ),
      );
    }
    if (data.containsKey('final_route_peer_device_id')) {
      context.handle(
        _finalRoutePeerDeviceIdMeta,
        finalRoutePeerDeviceId.isAcceptableOrUnknown(
          data['final_route_peer_device_id']!,
          _finalRoutePeerDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {originMessageId};
  @override
  BleRelayMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleRelayMessage(
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      originKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_key_id'],
      )!,
      originPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_public_key'],
      )!,
      immutablePayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_payload'],
      )!,
      wireEnvelope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wire_envelope'],
      )!,
      immutableDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_digest'],
      )!,
      originSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_signature'],
      )!,
      authorizationScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}authorization_scope'],
      )!,
      emergencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emergency_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      retentionDeadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}retention_deadline'],
      )!,
      maxHops: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_hops'],
      )!,
      incomingHopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}incoming_hop_count'],
      )!,
      incomingPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incoming_path'],
      )!,
      incomingPeerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incoming_peer_id'],
      )!,
      previousHopKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_hop_key_id'],
      )!,
      processingState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_state'],
      )!,
      payloadBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_bytes'],
      )!,
      storageBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}storage_bytes'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      persistedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}persisted_at'],
      )!,
      finalReceiptState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_receipt_state'],
      ),
      finalRecipientKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_recipient_key_id'],
      ),
      finalAuthorizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_authorization_id'],
      ),
      finalReceiptCorrelationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_receipt_correlation_id'],
      ),
      finalRoutePeerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_route_peer_device_id'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $BleRelayMessagesTable createAlias(String alias) {
    return $BleRelayMessagesTable(attachedDatabase, alias);
  }
}

class BleRelayMessage extends DataClass implements Insertable<BleRelayMessage> {
  final String originMessageId;
  final String incidentId;
  final String originKeyId;
  final String originPublicKey;
  final String immutablePayload;
  final String wireEnvelope;
  final String immutableDigest;
  final String originSignature;
  final String authorizationScope;
  final String emergencyType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime retentionDeadline;
  final int maxHops;
  final int incomingHopCount;
  final String incomingPath;
  final String incomingPeerId;
  final String previousHopKeyId;
  final String processingState;
  final int payloadBytes;
  final int storageBytes;
  final DateTime receivedAt;
  final DateTime persistedAt;
  final String? finalReceiptState;
  final String? finalRecipientKeyId;
  final String? finalAuthorizationId;
  final String? finalReceiptCorrelationId;
  final String? finalRoutePeerDeviceId;
  final String? lastError;
  const BleRelayMessage({
    required this.originMessageId,
    required this.incidentId,
    required this.originKeyId,
    required this.originPublicKey,
    required this.immutablePayload,
    required this.wireEnvelope,
    required this.immutableDigest,
    required this.originSignature,
    required this.authorizationScope,
    required this.emergencyType,
    required this.createdAt,
    required this.expiresAt,
    required this.retentionDeadline,
    required this.maxHops,
    required this.incomingHopCount,
    required this.incomingPath,
    required this.incomingPeerId,
    required this.previousHopKeyId,
    required this.processingState,
    required this.payloadBytes,
    required this.storageBytes,
    required this.receivedAt,
    required this.persistedAt,
    this.finalReceiptState,
    this.finalRecipientKeyId,
    this.finalAuthorizationId,
    this.finalReceiptCorrelationId,
    this.finalRoutePeerDeviceId,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['origin_key_id'] = Variable<String>(originKeyId);
    map['origin_public_key'] = Variable<String>(originPublicKey);
    map['immutable_payload'] = Variable<String>(immutablePayload);
    map['wire_envelope'] = Variable<String>(wireEnvelope);
    map['immutable_digest'] = Variable<String>(immutableDigest);
    map['origin_signature'] = Variable<String>(originSignature);
    map['authorization_scope'] = Variable<String>(authorizationScope);
    map['emergency_type'] = Variable<String>(emergencyType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['retention_deadline'] = Variable<DateTime>(retentionDeadline);
    map['max_hops'] = Variable<int>(maxHops);
    map['incoming_hop_count'] = Variable<int>(incomingHopCount);
    map['incoming_path'] = Variable<String>(incomingPath);
    map['incoming_peer_id'] = Variable<String>(incomingPeerId);
    map['previous_hop_key_id'] = Variable<String>(previousHopKeyId);
    map['processing_state'] = Variable<String>(processingState);
    map['payload_bytes'] = Variable<int>(payloadBytes);
    map['storage_bytes'] = Variable<int>(storageBytes);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['persisted_at'] = Variable<DateTime>(persistedAt);
    if (!nullToAbsent || finalReceiptState != null) {
      map['final_receipt_state'] = Variable<String>(finalReceiptState);
    }
    if (!nullToAbsent || finalRecipientKeyId != null) {
      map['final_recipient_key_id'] = Variable<String>(finalRecipientKeyId);
    }
    if (!nullToAbsent || finalAuthorizationId != null) {
      map['final_authorization_id'] = Variable<String>(finalAuthorizationId);
    }
    if (!nullToAbsent || finalReceiptCorrelationId != null) {
      map['final_receipt_correlation_id'] = Variable<String>(
        finalReceiptCorrelationId,
      );
    }
    if (!nullToAbsent || finalRoutePeerDeviceId != null) {
      map['final_route_peer_device_id'] = Variable<String>(
        finalRoutePeerDeviceId,
      );
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  BleRelayMessagesCompanion toCompanion(bool nullToAbsent) {
    return BleRelayMessagesCompanion(
      originMessageId: Value(originMessageId),
      incidentId: Value(incidentId),
      originKeyId: Value(originKeyId),
      originPublicKey: Value(originPublicKey),
      immutablePayload: Value(immutablePayload),
      wireEnvelope: Value(wireEnvelope),
      immutableDigest: Value(immutableDigest),
      originSignature: Value(originSignature),
      authorizationScope: Value(authorizationScope),
      emergencyType: Value(emergencyType),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      retentionDeadline: Value(retentionDeadline),
      maxHops: Value(maxHops),
      incomingHopCount: Value(incomingHopCount),
      incomingPath: Value(incomingPath),
      incomingPeerId: Value(incomingPeerId),
      previousHopKeyId: Value(previousHopKeyId),
      processingState: Value(processingState),
      payloadBytes: Value(payloadBytes),
      storageBytes: Value(storageBytes),
      receivedAt: Value(receivedAt),
      persistedAt: Value(persistedAt),
      finalReceiptState: finalReceiptState == null && nullToAbsent
          ? const Value.absent()
          : Value(finalReceiptState),
      finalRecipientKeyId: finalRecipientKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalRecipientKeyId),
      finalAuthorizationId: finalAuthorizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalAuthorizationId),
      finalReceiptCorrelationId:
          finalReceiptCorrelationId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalReceiptCorrelationId),
      finalRoutePeerDeviceId: finalRoutePeerDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalRoutePeerDeviceId),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory BleRelayMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleRelayMessage(
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      originKeyId: serializer.fromJson<String>(json['originKeyId']),
      originPublicKey: serializer.fromJson<String>(json['originPublicKey']),
      immutablePayload: serializer.fromJson<String>(json['immutablePayload']),
      wireEnvelope: serializer.fromJson<String>(json['wireEnvelope']),
      immutableDigest: serializer.fromJson<String>(json['immutableDigest']),
      originSignature: serializer.fromJson<String>(json['originSignature']),
      authorizationScope: serializer.fromJson<String>(
        json['authorizationScope'],
      ),
      emergencyType: serializer.fromJson<String>(json['emergencyType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      retentionDeadline: serializer.fromJson<DateTime>(
        json['retentionDeadline'],
      ),
      maxHops: serializer.fromJson<int>(json['maxHops']),
      incomingHopCount: serializer.fromJson<int>(json['incomingHopCount']),
      incomingPath: serializer.fromJson<String>(json['incomingPath']),
      incomingPeerId: serializer.fromJson<String>(json['incomingPeerId']),
      previousHopKeyId: serializer.fromJson<String>(json['previousHopKeyId']),
      processingState: serializer.fromJson<String>(json['processingState']),
      payloadBytes: serializer.fromJson<int>(json['payloadBytes']),
      storageBytes: serializer.fromJson<int>(json['storageBytes']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      persistedAt: serializer.fromJson<DateTime>(json['persistedAt']),
      finalReceiptState: serializer.fromJson<String?>(
        json['finalReceiptState'],
      ),
      finalRecipientKeyId: serializer.fromJson<String?>(
        json['finalRecipientKeyId'],
      ),
      finalAuthorizationId: serializer.fromJson<String?>(
        json['finalAuthorizationId'],
      ),
      finalReceiptCorrelationId: serializer.fromJson<String?>(
        json['finalReceiptCorrelationId'],
      ),
      finalRoutePeerDeviceId: serializer.fromJson<String?>(
        json['finalRoutePeerDeviceId'],
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'originMessageId': serializer.toJson<String>(originMessageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'originKeyId': serializer.toJson<String>(originKeyId),
      'originPublicKey': serializer.toJson<String>(originPublicKey),
      'immutablePayload': serializer.toJson<String>(immutablePayload),
      'wireEnvelope': serializer.toJson<String>(wireEnvelope),
      'immutableDigest': serializer.toJson<String>(immutableDigest),
      'originSignature': serializer.toJson<String>(originSignature),
      'authorizationScope': serializer.toJson<String>(authorizationScope),
      'emergencyType': serializer.toJson<String>(emergencyType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'retentionDeadline': serializer.toJson<DateTime>(retentionDeadline),
      'maxHops': serializer.toJson<int>(maxHops),
      'incomingHopCount': serializer.toJson<int>(incomingHopCount),
      'incomingPath': serializer.toJson<String>(incomingPath),
      'incomingPeerId': serializer.toJson<String>(incomingPeerId),
      'previousHopKeyId': serializer.toJson<String>(previousHopKeyId),
      'processingState': serializer.toJson<String>(processingState),
      'payloadBytes': serializer.toJson<int>(payloadBytes),
      'storageBytes': serializer.toJson<int>(storageBytes),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'persistedAt': serializer.toJson<DateTime>(persistedAt),
      'finalReceiptState': serializer.toJson<String?>(finalReceiptState),
      'finalRecipientKeyId': serializer.toJson<String?>(finalRecipientKeyId),
      'finalAuthorizationId': serializer.toJson<String?>(finalAuthorizationId),
      'finalReceiptCorrelationId': serializer.toJson<String?>(
        finalReceiptCorrelationId,
      ),
      'finalRoutePeerDeviceId': serializer.toJson<String?>(
        finalRoutePeerDeviceId,
      ),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  BleRelayMessage copyWith({
    String? originMessageId,
    String? incidentId,
    String? originKeyId,
    String? originPublicKey,
    String? immutablePayload,
    String? wireEnvelope,
    String? immutableDigest,
    String? originSignature,
    String? authorizationScope,
    String? emergencyType,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? retentionDeadline,
    int? maxHops,
    int? incomingHopCount,
    String? incomingPath,
    String? incomingPeerId,
    String? previousHopKeyId,
    String? processingState,
    int? payloadBytes,
    int? storageBytes,
    DateTime? receivedAt,
    DateTime? persistedAt,
    Value<String?> finalReceiptState = const Value.absent(),
    Value<String?> finalRecipientKeyId = const Value.absent(),
    Value<String?> finalAuthorizationId = const Value.absent(),
    Value<String?> finalReceiptCorrelationId = const Value.absent(),
    Value<String?> finalRoutePeerDeviceId = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => BleRelayMessage(
    originMessageId: originMessageId ?? this.originMessageId,
    incidentId: incidentId ?? this.incidentId,
    originKeyId: originKeyId ?? this.originKeyId,
    originPublicKey: originPublicKey ?? this.originPublicKey,
    immutablePayload: immutablePayload ?? this.immutablePayload,
    wireEnvelope: wireEnvelope ?? this.wireEnvelope,
    immutableDigest: immutableDigest ?? this.immutableDigest,
    originSignature: originSignature ?? this.originSignature,
    authorizationScope: authorizationScope ?? this.authorizationScope,
    emergencyType: emergencyType ?? this.emergencyType,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    retentionDeadline: retentionDeadline ?? this.retentionDeadline,
    maxHops: maxHops ?? this.maxHops,
    incomingHopCount: incomingHopCount ?? this.incomingHopCount,
    incomingPath: incomingPath ?? this.incomingPath,
    incomingPeerId: incomingPeerId ?? this.incomingPeerId,
    previousHopKeyId: previousHopKeyId ?? this.previousHopKeyId,
    processingState: processingState ?? this.processingState,
    payloadBytes: payloadBytes ?? this.payloadBytes,
    storageBytes: storageBytes ?? this.storageBytes,
    receivedAt: receivedAt ?? this.receivedAt,
    persistedAt: persistedAt ?? this.persistedAt,
    finalReceiptState: finalReceiptState.present
        ? finalReceiptState.value
        : this.finalReceiptState,
    finalRecipientKeyId: finalRecipientKeyId.present
        ? finalRecipientKeyId.value
        : this.finalRecipientKeyId,
    finalAuthorizationId: finalAuthorizationId.present
        ? finalAuthorizationId.value
        : this.finalAuthorizationId,
    finalReceiptCorrelationId: finalReceiptCorrelationId.present
        ? finalReceiptCorrelationId.value
        : this.finalReceiptCorrelationId,
    finalRoutePeerDeviceId: finalRoutePeerDeviceId.present
        ? finalRoutePeerDeviceId.value
        : this.finalRoutePeerDeviceId,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  BleRelayMessage copyWithCompanion(BleRelayMessagesCompanion data) {
    return BleRelayMessage(
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      originKeyId: data.originKeyId.present
          ? data.originKeyId.value
          : this.originKeyId,
      originPublicKey: data.originPublicKey.present
          ? data.originPublicKey.value
          : this.originPublicKey,
      immutablePayload: data.immutablePayload.present
          ? data.immutablePayload.value
          : this.immutablePayload,
      wireEnvelope: data.wireEnvelope.present
          ? data.wireEnvelope.value
          : this.wireEnvelope,
      immutableDigest: data.immutableDigest.present
          ? data.immutableDigest.value
          : this.immutableDigest,
      originSignature: data.originSignature.present
          ? data.originSignature.value
          : this.originSignature,
      authorizationScope: data.authorizationScope.present
          ? data.authorizationScope.value
          : this.authorizationScope,
      emergencyType: data.emergencyType.present
          ? data.emergencyType.value
          : this.emergencyType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      retentionDeadline: data.retentionDeadline.present
          ? data.retentionDeadline.value
          : this.retentionDeadline,
      maxHops: data.maxHops.present ? data.maxHops.value : this.maxHops,
      incomingHopCount: data.incomingHopCount.present
          ? data.incomingHopCount.value
          : this.incomingHopCount,
      incomingPath: data.incomingPath.present
          ? data.incomingPath.value
          : this.incomingPath,
      incomingPeerId: data.incomingPeerId.present
          ? data.incomingPeerId.value
          : this.incomingPeerId,
      previousHopKeyId: data.previousHopKeyId.present
          ? data.previousHopKeyId.value
          : this.previousHopKeyId,
      processingState: data.processingState.present
          ? data.processingState.value
          : this.processingState,
      payloadBytes: data.payloadBytes.present
          ? data.payloadBytes.value
          : this.payloadBytes,
      storageBytes: data.storageBytes.present
          ? data.storageBytes.value
          : this.storageBytes,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      persistedAt: data.persistedAt.present
          ? data.persistedAt.value
          : this.persistedAt,
      finalReceiptState: data.finalReceiptState.present
          ? data.finalReceiptState.value
          : this.finalReceiptState,
      finalRecipientKeyId: data.finalRecipientKeyId.present
          ? data.finalRecipientKeyId.value
          : this.finalRecipientKeyId,
      finalAuthorizationId: data.finalAuthorizationId.present
          ? data.finalAuthorizationId.value
          : this.finalAuthorizationId,
      finalReceiptCorrelationId: data.finalReceiptCorrelationId.present
          ? data.finalReceiptCorrelationId.value
          : this.finalReceiptCorrelationId,
      finalRoutePeerDeviceId: data.finalRoutePeerDeviceId.present
          ? data.finalRoutePeerDeviceId.value
          : this.finalRoutePeerDeviceId,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleRelayMessage(')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('originPublicKey: $originPublicKey, ')
          ..write('immutablePayload: $immutablePayload, ')
          ..write('wireEnvelope: $wireEnvelope, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('originSignature: $originSignature, ')
          ..write('authorizationScope: $authorizationScope, ')
          ..write('emergencyType: $emergencyType, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('retentionDeadline: $retentionDeadline, ')
          ..write('maxHops: $maxHops, ')
          ..write('incomingHopCount: $incomingHopCount, ')
          ..write('incomingPath: $incomingPath, ')
          ..write('incomingPeerId: $incomingPeerId, ')
          ..write('previousHopKeyId: $previousHopKeyId, ')
          ..write('processingState: $processingState, ')
          ..write('payloadBytes: $payloadBytes, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('persistedAt: $persistedAt, ')
          ..write('finalReceiptState: $finalReceiptState, ')
          ..write('finalRecipientKeyId: $finalRecipientKeyId, ')
          ..write('finalAuthorizationId: $finalAuthorizationId, ')
          ..write('finalReceiptCorrelationId: $finalReceiptCorrelationId, ')
          ..write('finalRoutePeerDeviceId: $finalRoutePeerDeviceId, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    originMessageId,
    incidentId,
    originKeyId,
    originPublicKey,
    immutablePayload,
    wireEnvelope,
    immutableDigest,
    originSignature,
    authorizationScope,
    emergencyType,
    createdAt,
    expiresAt,
    retentionDeadline,
    maxHops,
    incomingHopCount,
    incomingPath,
    incomingPeerId,
    previousHopKeyId,
    processingState,
    payloadBytes,
    storageBytes,
    receivedAt,
    persistedAt,
    finalReceiptState,
    finalRecipientKeyId,
    finalAuthorizationId,
    finalReceiptCorrelationId,
    finalRoutePeerDeviceId,
    lastError,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleRelayMessage &&
          other.originMessageId == this.originMessageId &&
          other.incidentId == this.incidentId &&
          other.originKeyId == this.originKeyId &&
          other.originPublicKey == this.originPublicKey &&
          other.immutablePayload == this.immutablePayload &&
          other.wireEnvelope == this.wireEnvelope &&
          other.immutableDigest == this.immutableDigest &&
          other.originSignature == this.originSignature &&
          other.authorizationScope == this.authorizationScope &&
          other.emergencyType == this.emergencyType &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.retentionDeadline == this.retentionDeadline &&
          other.maxHops == this.maxHops &&
          other.incomingHopCount == this.incomingHopCount &&
          other.incomingPath == this.incomingPath &&
          other.incomingPeerId == this.incomingPeerId &&
          other.previousHopKeyId == this.previousHopKeyId &&
          other.processingState == this.processingState &&
          other.payloadBytes == this.payloadBytes &&
          other.storageBytes == this.storageBytes &&
          other.receivedAt == this.receivedAt &&
          other.persistedAt == this.persistedAt &&
          other.finalReceiptState == this.finalReceiptState &&
          other.finalRecipientKeyId == this.finalRecipientKeyId &&
          other.finalAuthorizationId == this.finalAuthorizationId &&
          other.finalReceiptCorrelationId == this.finalReceiptCorrelationId &&
          other.finalRoutePeerDeviceId == this.finalRoutePeerDeviceId &&
          other.lastError == this.lastError);
}

class BleRelayMessagesCompanion extends UpdateCompanion<BleRelayMessage> {
  final Value<String> originMessageId;
  final Value<String> incidentId;
  final Value<String> originKeyId;
  final Value<String> originPublicKey;
  final Value<String> immutablePayload;
  final Value<String> wireEnvelope;
  final Value<String> immutableDigest;
  final Value<String> originSignature;
  final Value<String> authorizationScope;
  final Value<String> emergencyType;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime> retentionDeadline;
  final Value<int> maxHops;
  final Value<int> incomingHopCount;
  final Value<String> incomingPath;
  final Value<String> incomingPeerId;
  final Value<String> previousHopKeyId;
  final Value<String> processingState;
  final Value<int> payloadBytes;
  final Value<int> storageBytes;
  final Value<DateTime> receivedAt;
  final Value<DateTime> persistedAt;
  final Value<String?> finalReceiptState;
  final Value<String?> finalRecipientKeyId;
  final Value<String?> finalAuthorizationId;
  final Value<String?> finalReceiptCorrelationId;
  final Value<String?> finalRoutePeerDeviceId;
  final Value<String?> lastError;
  final Value<int> rowid;
  const BleRelayMessagesCompanion({
    this.originMessageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.originKeyId = const Value.absent(),
    this.originPublicKey = const Value.absent(),
    this.immutablePayload = const Value.absent(),
    this.wireEnvelope = const Value.absent(),
    this.immutableDigest = const Value.absent(),
    this.originSignature = const Value.absent(),
    this.authorizationScope = const Value.absent(),
    this.emergencyType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.retentionDeadline = const Value.absent(),
    this.maxHops = const Value.absent(),
    this.incomingHopCount = const Value.absent(),
    this.incomingPath = const Value.absent(),
    this.incomingPeerId = const Value.absent(),
    this.previousHopKeyId = const Value.absent(),
    this.processingState = const Value.absent(),
    this.payloadBytes = const Value.absent(),
    this.storageBytes = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.persistedAt = const Value.absent(),
    this.finalReceiptState = const Value.absent(),
    this.finalRecipientKeyId = const Value.absent(),
    this.finalAuthorizationId = const Value.absent(),
    this.finalReceiptCorrelationId = const Value.absent(),
    this.finalRoutePeerDeviceId = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleRelayMessagesCompanion.insert({
    required String originMessageId,
    required String incidentId,
    required String originKeyId,
    required String originPublicKey,
    required String immutablePayload,
    required String wireEnvelope,
    required String immutableDigest,
    required String originSignature,
    required String authorizationScope,
    required String emergencyType,
    required DateTime createdAt,
    required DateTime expiresAt,
    required DateTime retentionDeadline,
    required int maxHops,
    required int incomingHopCount,
    required String incomingPath,
    required String incomingPeerId,
    required String previousHopKeyId,
    required String processingState,
    required int payloadBytes,
    required int storageBytes,
    required DateTime receivedAt,
    required DateTime persistedAt,
    this.finalReceiptState = const Value.absent(),
    this.finalRecipientKeyId = const Value.absent(),
    this.finalAuthorizationId = const Value.absent(),
    this.finalReceiptCorrelationId = const Value.absent(),
    this.finalRoutePeerDeviceId = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : originMessageId = Value(originMessageId),
       incidentId = Value(incidentId),
       originKeyId = Value(originKeyId),
       originPublicKey = Value(originPublicKey),
       immutablePayload = Value(immutablePayload),
       wireEnvelope = Value(wireEnvelope),
       immutableDigest = Value(immutableDigest),
       originSignature = Value(originSignature),
       authorizationScope = Value(authorizationScope),
       emergencyType = Value(emergencyType),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt),
       retentionDeadline = Value(retentionDeadline),
       maxHops = Value(maxHops),
       incomingHopCount = Value(incomingHopCount),
       incomingPath = Value(incomingPath),
       incomingPeerId = Value(incomingPeerId),
       previousHopKeyId = Value(previousHopKeyId),
       processingState = Value(processingState),
       payloadBytes = Value(payloadBytes),
       storageBytes = Value(storageBytes),
       receivedAt = Value(receivedAt),
       persistedAt = Value(persistedAt);
  static Insertable<BleRelayMessage> custom({
    Expression<String>? originMessageId,
    Expression<String>? incidentId,
    Expression<String>? originKeyId,
    Expression<String>? originPublicKey,
    Expression<String>? immutablePayload,
    Expression<String>? wireEnvelope,
    Expression<String>? immutableDigest,
    Expression<String>? originSignature,
    Expression<String>? authorizationScope,
    Expression<String>? emergencyType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? retentionDeadline,
    Expression<int>? maxHops,
    Expression<int>? incomingHopCount,
    Expression<String>? incomingPath,
    Expression<String>? incomingPeerId,
    Expression<String>? previousHopKeyId,
    Expression<String>? processingState,
    Expression<int>? payloadBytes,
    Expression<int>? storageBytes,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? persistedAt,
    Expression<String>? finalReceiptState,
    Expression<String>? finalRecipientKeyId,
    Expression<String>? finalAuthorizationId,
    Expression<String>? finalReceiptCorrelationId,
    Expression<String>? finalRoutePeerDeviceId,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (originKeyId != null) 'origin_key_id': originKeyId,
      if (originPublicKey != null) 'origin_public_key': originPublicKey,
      if (immutablePayload != null) 'immutable_payload': immutablePayload,
      if (wireEnvelope != null) 'wire_envelope': wireEnvelope,
      if (immutableDigest != null) 'immutable_digest': immutableDigest,
      if (originSignature != null) 'origin_signature': originSignature,
      if (authorizationScope != null) 'authorization_scope': authorizationScope,
      if (emergencyType != null) 'emergency_type': emergencyType,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (retentionDeadline != null) 'retention_deadline': retentionDeadline,
      if (maxHops != null) 'max_hops': maxHops,
      if (incomingHopCount != null) 'incoming_hop_count': incomingHopCount,
      if (incomingPath != null) 'incoming_path': incomingPath,
      if (incomingPeerId != null) 'incoming_peer_id': incomingPeerId,
      if (previousHopKeyId != null) 'previous_hop_key_id': previousHopKeyId,
      if (processingState != null) 'processing_state': processingState,
      if (payloadBytes != null) 'payload_bytes': payloadBytes,
      if (storageBytes != null) 'storage_bytes': storageBytes,
      if (receivedAt != null) 'received_at': receivedAt,
      if (persistedAt != null) 'persisted_at': persistedAt,
      if (finalReceiptState != null) 'final_receipt_state': finalReceiptState,
      if (finalRecipientKeyId != null)
        'final_recipient_key_id': finalRecipientKeyId,
      if (finalAuthorizationId != null)
        'final_authorization_id': finalAuthorizationId,
      if (finalReceiptCorrelationId != null)
        'final_receipt_correlation_id': finalReceiptCorrelationId,
      if (finalRoutePeerDeviceId != null)
        'final_route_peer_device_id': finalRoutePeerDeviceId,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleRelayMessagesCompanion copyWith({
    Value<String>? originMessageId,
    Value<String>? incidentId,
    Value<String>? originKeyId,
    Value<String>? originPublicKey,
    Value<String>? immutablePayload,
    Value<String>? wireEnvelope,
    Value<String>? immutableDigest,
    Value<String>? originSignature,
    Value<String>? authorizationScope,
    Value<String>? emergencyType,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<DateTime>? retentionDeadline,
    Value<int>? maxHops,
    Value<int>? incomingHopCount,
    Value<String>? incomingPath,
    Value<String>? incomingPeerId,
    Value<String>? previousHopKeyId,
    Value<String>? processingState,
    Value<int>? payloadBytes,
    Value<int>? storageBytes,
    Value<DateTime>? receivedAt,
    Value<DateTime>? persistedAt,
    Value<String?>? finalReceiptState,
    Value<String?>? finalRecipientKeyId,
    Value<String?>? finalAuthorizationId,
    Value<String?>? finalReceiptCorrelationId,
    Value<String?>? finalRoutePeerDeviceId,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return BleRelayMessagesCompanion(
      originMessageId: originMessageId ?? this.originMessageId,
      incidentId: incidentId ?? this.incidentId,
      originKeyId: originKeyId ?? this.originKeyId,
      originPublicKey: originPublicKey ?? this.originPublicKey,
      immutablePayload: immutablePayload ?? this.immutablePayload,
      wireEnvelope: wireEnvelope ?? this.wireEnvelope,
      immutableDigest: immutableDigest ?? this.immutableDigest,
      originSignature: originSignature ?? this.originSignature,
      authorizationScope: authorizationScope ?? this.authorizationScope,
      emergencyType: emergencyType ?? this.emergencyType,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      retentionDeadline: retentionDeadline ?? this.retentionDeadline,
      maxHops: maxHops ?? this.maxHops,
      incomingHopCount: incomingHopCount ?? this.incomingHopCount,
      incomingPath: incomingPath ?? this.incomingPath,
      incomingPeerId: incomingPeerId ?? this.incomingPeerId,
      previousHopKeyId: previousHopKeyId ?? this.previousHopKeyId,
      processingState: processingState ?? this.processingState,
      payloadBytes: payloadBytes ?? this.payloadBytes,
      storageBytes: storageBytes ?? this.storageBytes,
      receivedAt: receivedAt ?? this.receivedAt,
      persistedAt: persistedAt ?? this.persistedAt,
      finalReceiptState: finalReceiptState ?? this.finalReceiptState,
      finalRecipientKeyId: finalRecipientKeyId ?? this.finalRecipientKeyId,
      finalAuthorizationId: finalAuthorizationId ?? this.finalAuthorizationId,
      finalReceiptCorrelationId:
          finalReceiptCorrelationId ?? this.finalReceiptCorrelationId,
      finalRoutePeerDeviceId:
          finalRoutePeerDeviceId ?? this.finalRoutePeerDeviceId,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (originKeyId.present) {
      map['origin_key_id'] = Variable<String>(originKeyId.value);
    }
    if (originPublicKey.present) {
      map['origin_public_key'] = Variable<String>(originPublicKey.value);
    }
    if (immutablePayload.present) {
      map['immutable_payload'] = Variable<String>(immutablePayload.value);
    }
    if (wireEnvelope.present) {
      map['wire_envelope'] = Variable<String>(wireEnvelope.value);
    }
    if (immutableDigest.present) {
      map['immutable_digest'] = Variable<String>(immutableDigest.value);
    }
    if (originSignature.present) {
      map['origin_signature'] = Variable<String>(originSignature.value);
    }
    if (authorizationScope.present) {
      map['authorization_scope'] = Variable<String>(authorizationScope.value);
    }
    if (emergencyType.present) {
      map['emergency_type'] = Variable<String>(emergencyType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (retentionDeadline.present) {
      map['retention_deadline'] = Variable<DateTime>(retentionDeadline.value);
    }
    if (maxHops.present) {
      map['max_hops'] = Variable<int>(maxHops.value);
    }
    if (incomingHopCount.present) {
      map['incoming_hop_count'] = Variable<int>(incomingHopCount.value);
    }
    if (incomingPath.present) {
      map['incoming_path'] = Variable<String>(incomingPath.value);
    }
    if (incomingPeerId.present) {
      map['incoming_peer_id'] = Variable<String>(incomingPeerId.value);
    }
    if (previousHopKeyId.present) {
      map['previous_hop_key_id'] = Variable<String>(previousHopKeyId.value);
    }
    if (processingState.present) {
      map['processing_state'] = Variable<String>(processingState.value);
    }
    if (payloadBytes.present) {
      map['payload_bytes'] = Variable<int>(payloadBytes.value);
    }
    if (storageBytes.present) {
      map['storage_bytes'] = Variable<int>(storageBytes.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (persistedAt.present) {
      map['persisted_at'] = Variable<DateTime>(persistedAt.value);
    }
    if (finalReceiptState.present) {
      map['final_receipt_state'] = Variable<String>(finalReceiptState.value);
    }
    if (finalRecipientKeyId.present) {
      map['final_recipient_key_id'] = Variable<String>(
        finalRecipientKeyId.value,
      );
    }
    if (finalAuthorizationId.present) {
      map['final_authorization_id'] = Variable<String>(
        finalAuthorizationId.value,
      );
    }
    if (finalReceiptCorrelationId.present) {
      map['final_receipt_correlation_id'] = Variable<String>(
        finalReceiptCorrelationId.value,
      );
    }
    if (finalRoutePeerDeviceId.present) {
      map['final_route_peer_device_id'] = Variable<String>(
        finalRoutePeerDeviceId.value,
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BleRelayMessagesCompanion(')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('originPublicKey: $originPublicKey, ')
          ..write('immutablePayload: $immutablePayload, ')
          ..write('wireEnvelope: $wireEnvelope, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('originSignature: $originSignature, ')
          ..write('authorizationScope: $authorizationScope, ')
          ..write('emergencyType: $emergencyType, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('retentionDeadline: $retentionDeadline, ')
          ..write('maxHops: $maxHops, ')
          ..write('incomingHopCount: $incomingHopCount, ')
          ..write('incomingPath: $incomingPath, ')
          ..write('incomingPeerId: $incomingPeerId, ')
          ..write('previousHopKeyId: $previousHopKeyId, ')
          ..write('processingState: $processingState, ')
          ..write('payloadBytes: $payloadBytes, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('persistedAt: $persistedAt, ')
          ..write('finalReceiptState: $finalReceiptState, ')
          ..write('finalRecipientKeyId: $finalRecipientKeyId, ')
          ..write('finalAuthorizationId: $finalAuthorizationId, ')
          ..write('finalReceiptCorrelationId: $finalReceiptCorrelationId, ')
          ..write('finalRoutePeerDeviceId: $finalRoutePeerDeviceId, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BleRelayAttemptsTable extends BleRelayAttempts
    with TableInfo<$BleRelayAttemptsTable, BleRelayAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleRelayAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ble_relay_messages (origin_message_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nextHopKeyIdMeta = const VerificationMeta(
    'nextHopKeyId',
  );
  @override
  late final GeneratedColumn<String> nextHopKeyId = GeneratedColumn<String>(
    'next_hop_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correlationIdMeta = const VerificationMeta(
    'correlationId',
  );
  @override
  late final GeneratedColumn<String> correlationId = GeneratedColumn<String>(
    'correlation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextHopDeviceIdMeta = const VerificationMeta(
    'nextHopDeviceId',
  );
  @override
  late final GeneratedColumn<String> nextHopDeviceId = GeneratedColumn<String>(
    'next_hop_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outgoingHopCountMeta = const VerificationMeta(
    'outgoingHopCount',
  );
  @override
  late final GeneratedColumn<int> outgoingHopCount = GeneratedColumn<int>(
    'outgoing_hop_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outgoingPathMeta = const VerificationMeta(
    'outgoingPath',
  );
  @override
  late final GeneratedColumn<String> outgoingPath = GeneratedColumn<String>(
    'outgoing_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageBytesMeta = const VerificationMeta(
    'storageBytes',
  );
  @override
  late final GeneratedColumn<int> storageBytes = GeneratedColumn<int>(
    'storage_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
    'accepted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    originMessageId,
    nextHopKeyId,
    attemptId,
    correlationId,
    nextHopDeviceId,
    outgoingHopCount,
    outgoingPath,
    storageBytes,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    lastError,
    createdAt,
    updatedAt,
    acceptedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_relay_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleRelayAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('next_hop_key_id')) {
      context.handle(
        _nextHopKeyIdMeta,
        nextHopKeyId.isAcceptableOrUnknown(
          data['next_hop_key_id']!,
          _nextHopKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextHopKeyIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('correlation_id')) {
      context.handle(
        _correlationIdMeta,
        correlationId.isAcceptableOrUnknown(
          data['correlation_id']!,
          _correlationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correlationIdMeta);
    }
    if (data.containsKey('next_hop_device_id')) {
      context.handle(
        _nextHopDeviceIdMeta,
        nextHopDeviceId.isAcceptableOrUnknown(
          data['next_hop_device_id']!,
          _nextHopDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextHopDeviceIdMeta);
    }
    if (data.containsKey('outgoing_hop_count')) {
      context.handle(
        _outgoingHopCountMeta,
        outgoingHopCount.isAcceptableOrUnknown(
          data['outgoing_hop_count']!,
          _outgoingHopCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outgoingHopCountMeta);
    }
    if (data.containsKey('outgoing_path')) {
      context.handle(
        _outgoingPathMeta,
        outgoingPath.isAcceptableOrUnknown(
          data['outgoing_path']!,
          _outgoingPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outgoingPathMeta);
    }
    if (data.containsKey('storage_bytes')) {
      context.handle(
        _storageBytesMeta,
        storageBytes.isAcceptableOrUnknown(
          data['storage_bytes']!,
          _storageBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageBytesMeta);
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
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {originMessageId, nextHopKeyId};
  @override
  BleRelayAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleRelayAttempt(
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      nextHopKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_hop_key_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      correlationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correlation_id'],
      )!,
      nextHopDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_hop_device_id'],
      )!,
      outgoingHopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outgoing_hop_count'],
      )!,
      outgoingPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outgoing_path'],
      )!,
      storageBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}storage_bytes'],
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
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accepted_at'],
      ),
    );
  }

  @override
  $BleRelayAttemptsTable createAlias(String alias) {
    return $BleRelayAttemptsTable(attachedDatabase, alias);
  }
}

class BleRelayAttempt extends DataClass implements Insertable<BleRelayAttempt> {
  final String originMessageId;
  final String nextHopKeyId;
  final String attemptId;
  final String correlationId;
  final String nextHopDeviceId;
  final int outgoingHopCount;
  final String outgoingPath;
  final int storageBytes;
  final String state;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  const BleRelayAttempt({
    required this.originMessageId,
    required this.nextHopKeyId,
    required this.attemptId,
    required this.correlationId,
    required this.nextHopDeviceId,
    required this.outgoingHopCount,
    required this.outgoingPath,
    required this.storageBytes,
    required this.state,
    required this.retryCount,
    this.nextRetryAt,
    this.lastAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['next_hop_key_id'] = Variable<String>(nextHopKeyId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['correlation_id'] = Variable<String>(correlationId);
    map['next_hop_device_id'] = Variable<String>(nextHopDeviceId);
    map['outgoing_hop_count'] = Variable<int>(outgoingHopCount);
    map['outgoing_path'] = Variable<String>(outgoingPath);
    map['storage_bytes'] = Variable<int>(storageBytes);
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
    if (!nullToAbsent || acceptedAt != null) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt);
    }
    return map;
  }

  BleRelayAttemptsCompanion toCompanion(bool nullToAbsent) {
    return BleRelayAttemptsCompanion(
      originMessageId: Value(originMessageId),
      nextHopKeyId: Value(nextHopKeyId),
      attemptId: Value(attemptId),
      correlationId: Value(correlationId),
      nextHopDeviceId: Value(nextHopDeviceId),
      outgoingHopCount: Value(outgoingHopCount),
      outgoingPath: Value(outgoingPath),
      storageBytes: Value(storageBytes),
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
      acceptedAt: acceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedAt),
    );
  }

  factory BleRelayAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleRelayAttempt(
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      nextHopKeyId: serializer.fromJson<String>(json['nextHopKeyId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      correlationId: serializer.fromJson<String>(json['correlationId']),
      nextHopDeviceId: serializer.fromJson<String>(json['nextHopDeviceId']),
      outgoingHopCount: serializer.fromJson<int>(json['outgoingHopCount']),
      outgoingPath: serializer.fromJson<String>(json['outgoingPath']),
      storageBytes: serializer.fromJson<int>(json['storageBytes']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      acceptedAt: serializer.fromJson<DateTime?>(json['acceptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'originMessageId': serializer.toJson<String>(originMessageId),
      'nextHopKeyId': serializer.toJson<String>(nextHopKeyId),
      'attemptId': serializer.toJson<String>(attemptId),
      'correlationId': serializer.toJson<String>(correlationId),
      'nextHopDeviceId': serializer.toJson<String>(nextHopDeviceId),
      'outgoingHopCount': serializer.toJson<int>(outgoingHopCount),
      'outgoingPath': serializer.toJson<String>(outgoingPath),
      'storageBytes': serializer.toJson<int>(storageBytes),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'acceptedAt': serializer.toJson<DateTime?>(acceptedAt),
    };
  }

  BleRelayAttempt copyWith({
    String? originMessageId,
    String? nextHopKeyId,
    String? attemptId,
    String? correlationId,
    String? nextHopDeviceId,
    int? outgoingHopCount,
    String? outgoingPath,
    int? storageBytes,
    String? state,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> acceptedAt = const Value.absent(),
  }) => BleRelayAttempt(
    originMessageId: originMessageId ?? this.originMessageId,
    nextHopKeyId: nextHopKeyId ?? this.nextHopKeyId,
    attemptId: attemptId ?? this.attemptId,
    correlationId: correlationId ?? this.correlationId,
    nextHopDeviceId: nextHopDeviceId ?? this.nextHopDeviceId,
    outgoingHopCount: outgoingHopCount ?? this.outgoingHopCount,
    outgoingPath: outgoingPath ?? this.outgoingPath,
    storageBytes: storageBytes ?? this.storageBytes,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    acceptedAt: acceptedAt.present ? acceptedAt.value : this.acceptedAt,
  );
  BleRelayAttempt copyWithCompanion(BleRelayAttemptsCompanion data) {
    return BleRelayAttempt(
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      nextHopKeyId: data.nextHopKeyId.present
          ? data.nextHopKeyId.value
          : this.nextHopKeyId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      correlationId: data.correlationId.present
          ? data.correlationId.value
          : this.correlationId,
      nextHopDeviceId: data.nextHopDeviceId.present
          ? data.nextHopDeviceId.value
          : this.nextHopDeviceId,
      outgoingHopCount: data.outgoingHopCount.present
          ? data.outgoingHopCount.value
          : this.outgoingHopCount,
      outgoingPath: data.outgoingPath.present
          ? data.outgoingPath.value
          : this.outgoingPath,
      storageBytes: data.storageBytes.present
          ? data.storageBytes.value
          : this.storageBytes,
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
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleRelayAttempt(')
          ..write('originMessageId: $originMessageId, ')
          ..write('nextHopKeyId: $nextHopKeyId, ')
          ..write('attemptId: $attemptId, ')
          ..write('correlationId: $correlationId, ')
          ..write('nextHopDeviceId: $nextHopDeviceId, ')
          ..write('outgoingHopCount: $outgoingHopCount, ')
          ..write('outgoingPath: $outgoingPath, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    originMessageId,
    nextHopKeyId,
    attemptId,
    correlationId,
    nextHopDeviceId,
    outgoingHopCount,
    outgoingPath,
    storageBytes,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    lastError,
    createdAt,
    updatedAt,
    acceptedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleRelayAttempt &&
          other.originMessageId == this.originMessageId &&
          other.nextHopKeyId == this.nextHopKeyId &&
          other.attemptId == this.attemptId &&
          other.correlationId == this.correlationId &&
          other.nextHopDeviceId == this.nextHopDeviceId &&
          other.outgoingHopCount == this.outgoingHopCount &&
          other.outgoingPath == this.outgoingPath &&
          other.storageBytes == this.storageBytes &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.acceptedAt == this.acceptedAt);
}

class BleRelayAttemptsCompanion extends UpdateCompanion<BleRelayAttempt> {
  final Value<String> originMessageId;
  final Value<String> nextHopKeyId;
  final Value<String> attemptId;
  final Value<String> correlationId;
  final Value<String> nextHopDeviceId;
  final Value<int> outgoingHopCount;
  final Value<String> outgoingPath;
  final Value<int> storageBytes;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> acceptedAt;
  final Value<int> rowid;
  const BleRelayAttemptsCompanion({
    this.originMessageId = const Value.absent(),
    this.nextHopKeyId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.correlationId = const Value.absent(),
    this.nextHopDeviceId = const Value.absent(),
    this.outgoingHopCount = const Value.absent(),
    this.outgoingPath = const Value.absent(),
    this.storageBytes = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleRelayAttemptsCompanion.insert({
    required String originMessageId,
    required String nextHopKeyId,
    required String attemptId,
    required String correlationId,
    required String nextHopDeviceId,
    required int outgoingHopCount,
    required String outgoingPath,
    required int storageBytes,
    required String state,
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : originMessageId = Value(originMessageId),
       nextHopKeyId = Value(nextHopKeyId),
       attemptId = Value(attemptId),
       correlationId = Value(correlationId),
       nextHopDeviceId = Value(nextHopDeviceId),
       outgoingHopCount = Value(outgoingHopCount),
       outgoingPath = Value(outgoingPath),
       storageBytes = Value(storageBytes),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BleRelayAttempt> custom({
    Expression<String>? originMessageId,
    Expression<String>? nextHopKeyId,
    Expression<String>? attemptId,
    Expression<String>? correlationId,
    Expression<String>? nextHopDeviceId,
    Expression<int>? outgoingHopCount,
    Expression<String>? outgoingPath,
    Expression<int>? storageBytes,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? acceptedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (nextHopKeyId != null) 'next_hop_key_id': nextHopKeyId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (correlationId != null) 'correlation_id': correlationId,
      if (nextHopDeviceId != null) 'next_hop_device_id': nextHopDeviceId,
      if (outgoingHopCount != null) 'outgoing_hop_count': outgoingHopCount,
      if (outgoingPath != null) 'outgoing_path': outgoingPath,
      if (storageBytes != null) 'storage_bytes': storageBytes,
      if (state != null) 'state': state,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleRelayAttemptsCompanion copyWith({
    Value<String>? originMessageId,
    Value<String>? nextHopKeyId,
    Value<String>? attemptId,
    Value<String>? correlationId,
    Value<String>? nextHopDeviceId,
    Value<int>? outgoingHopCount,
    Value<String>? outgoingPath,
    Value<int>? storageBytes,
    Value<String>? state,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime?>? lastAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? acceptedAt,
    Value<int>? rowid,
  }) {
    return BleRelayAttemptsCompanion(
      originMessageId: originMessageId ?? this.originMessageId,
      nextHopKeyId: nextHopKeyId ?? this.nextHopKeyId,
      attemptId: attemptId ?? this.attemptId,
      correlationId: correlationId ?? this.correlationId,
      nextHopDeviceId: nextHopDeviceId ?? this.nextHopDeviceId,
      outgoingHopCount: outgoingHopCount ?? this.outgoingHopCount,
      outgoingPath: outgoingPath ?? this.outgoingPath,
      storageBytes: storageBytes ?? this.storageBytes,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (nextHopKeyId.present) {
      map['next_hop_key_id'] = Variable<String>(nextHopKeyId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (correlationId.present) {
      map['correlation_id'] = Variable<String>(correlationId.value);
    }
    if (nextHopDeviceId.present) {
      map['next_hop_device_id'] = Variable<String>(nextHopDeviceId.value);
    }
    if (outgoingHopCount.present) {
      map['outgoing_hop_count'] = Variable<int>(outgoingHopCount.value);
    }
    if (outgoingPath.present) {
      map['outgoing_path'] = Variable<String>(outgoingPath.value);
    }
    if (storageBytes.present) {
      map['storage_bytes'] = Variable<int>(storageBytes.value);
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
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BleRelayAttemptsCompanion(')
          ..write('originMessageId: $originMessageId, ')
          ..write('nextHopKeyId: $nextHopKeyId, ')
          ..write('attemptId: $attemptId, ')
          ..write('correlationId: $correlationId, ')
          ..write('nextHopDeviceId: $nextHopDeviceId, ')
          ..write('outgoingHopCount: $outgoingHopCount, ')
          ..write('outgoingPath: $outgoingPath, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BleRelayReceiptsTable extends BleRelayReceipts
    with TableInfo<$BleRelayReceiptsTable, BleRelayReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleRelayReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _semanticKeyMeta = const VerificationMeta(
    'semanticKey',
  );
  @override
  late final GeneratedColumn<String> semanticKey = GeneratedColumn<String>(
    'semantic_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptTypeMeta = const VerificationMeta(
    'receiptType',
  );
  @override
  late final GeneratedColumn<String> receiptType = GeneratedColumn<String>(
    'receipt_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ble_relay_messages (origin_message_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _immutableDigestMeta = const VerificationMeta(
    'immutableDigest',
  );
  @override
  late final GeneratedColumn<String> immutableDigest = GeneratedColumn<String>(
    'immutable_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signerKeyIdMeta = const VerificationMeta(
    'signerKeyId',
  );
  @override
  late final GeneratedColumn<String> signerKeyId = GeneratedColumn<String>(
    'signer_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signerPublicKeyMeta = const VerificationMeta(
    'signerPublicKey',
  );
  @override
  late final GeneratedColumn<String> signerPublicKey = GeneratedColumn<String>(
    'signer_public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correlationIdMeta = const VerificationMeta(
    'correlationId',
  );
  @override
  late final GeneratedColumn<String> correlationId = GeneratedColumn<String>(
    'correlation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalAuthorizationIdMeta =
      const VerificationMeta('finalAuthorizationId');
  @override
  late final GeneratedColumn<String> finalAuthorizationId =
      GeneratedColumn<String>(
        'final_authorization_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourcePeerDeviceIdMeta =
      const VerificationMeta('sourcePeerDeviceId');
  @override
  late final GeneratedColumn<String> sourcePeerDeviceId =
      GeneratedColumn<String>(
        'source_peer_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _previousHopKeyIdMeta = const VerificationMeta(
    'previousHopKeyId',
  );
  @override
  late final GeneratedColumn<String> previousHopKeyId = GeneratedColumn<String>(
    'previous_hop_key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previousHopDeviceIdMeta =
      const VerificationMeta('previousHopDeviceId');
  @override
  late final GeneratedColumn<String> previousHopDeviceId =
      GeneratedColumn<String>(
        'previous_hop_device_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageBytesMeta = const VerificationMeta(
    'storageBytes',
  );
  @override
  late final GeneratedColumn<int> storageBytes = GeneratedColumn<int>(
    'storage_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
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
    semanticKey,
    receiptId,
    receiptType,
    originMessageId,
    incidentId,
    immutableDigest,
    signerKeyId,
    signerPublicKey,
    correlationId,
    attemptId,
    finalAuthorizationId,
    sourcePeerDeviceId,
    previousHopKeyId,
    previousHopDeviceId,
    payload,
    signature,
    storageBytes,
    state,
    createdAt,
    expiresAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_relay_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleRelayReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('semantic_key')) {
      context.handle(
        _semanticKeyMeta,
        semanticKey.isAcceptableOrUnknown(
          data['semantic_key']!,
          _semanticKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticKeyMeta);
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('receipt_type')) {
      context.handle(
        _receiptTypeMeta,
        receiptType.isAcceptableOrUnknown(
          data['receipt_type']!,
          _receiptTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receiptTypeMeta);
    }
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('immutable_digest')) {
      context.handle(
        _immutableDigestMeta,
        immutableDigest.isAcceptableOrUnknown(
          data['immutable_digest']!,
          _immutableDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutableDigestMeta);
    }
    if (data.containsKey('signer_key_id')) {
      context.handle(
        _signerKeyIdMeta,
        signerKeyId.isAcceptableOrUnknown(
          data['signer_key_id']!,
          _signerKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signerKeyIdMeta);
    }
    if (data.containsKey('signer_public_key')) {
      context.handle(
        _signerPublicKeyMeta,
        signerPublicKey.isAcceptableOrUnknown(
          data['signer_public_key']!,
          _signerPublicKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signerPublicKeyMeta);
    }
    if (data.containsKey('correlation_id')) {
      context.handle(
        _correlationIdMeta,
        correlationId.isAcceptableOrUnknown(
          data['correlation_id']!,
          _correlationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correlationIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    }
    if (data.containsKey('final_authorization_id')) {
      context.handle(
        _finalAuthorizationIdMeta,
        finalAuthorizationId.isAcceptableOrUnknown(
          data['final_authorization_id']!,
          _finalAuthorizationIdMeta,
        ),
      );
    }
    if (data.containsKey('source_peer_device_id')) {
      context.handle(
        _sourcePeerDeviceIdMeta,
        sourcePeerDeviceId.isAcceptableOrUnknown(
          data['source_peer_device_id']!,
          _sourcePeerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePeerDeviceIdMeta);
    }
    if (data.containsKey('previous_hop_key_id')) {
      context.handle(
        _previousHopKeyIdMeta,
        previousHopKeyId.isAcceptableOrUnknown(
          data['previous_hop_key_id']!,
          _previousHopKeyIdMeta,
        ),
      );
    }
    if (data.containsKey('previous_hop_device_id')) {
      context.handle(
        _previousHopDeviceIdMeta,
        previousHopDeviceId.isAcceptableOrUnknown(
          data['previous_hop_device_id']!,
          _previousHopDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('storage_bytes')) {
      context.handle(
        _storageBytesMeta,
        storageBytes.isAcceptableOrUnknown(
          data['storage_bytes']!,
          _storageBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageBytesMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
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
  Set<GeneratedColumn> get $primaryKey => {semanticKey};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {receiptId},
  ];
  @override
  BleRelayReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleRelayReceipt(
      semanticKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_key'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      receiptType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_type'],
      )!,
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      immutableDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_digest'],
      )!,
      signerKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_key_id'],
      )!,
      signerPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_public_key'],
      )!,
      correlationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correlation_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      ),
      finalAuthorizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_authorization_id'],
      ),
      sourcePeerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_peer_device_id'],
      )!,
      previousHopKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_hop_key_id'],
      ),
      previousHopDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_hop_device_id'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      storageBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}storage_bytes'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BleRelayReceiptsTable createAlias(String alias) {
    return $BleRelayReceiptsTable(attachedDatabase, alias);
  }
}

class BleRelayReceipt extends DataClass implements Insertable<BleRelayReceipt> {
  final String semanticKey;
  final String receiptId;
  final String receiptType;
  final String originMessageId;
  final String incidentId;
  final String immutableDigest;
  final String signerKeyId;
  final String signerPublicKey;
  final String correlationId;
  final String? attemptId;
  final String? finalAuthorizationId;
  final String sourcePeerDeviceId;
  final String? previousHopKeyId;
  final String? previousHopDeviceId;
  final String payload;
  final String signature;
  final int storageBytes;
  final String state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime updatedAt;
  const BleRelayReceipt({
    required this.semanticKey,
    required this.receiptId,
    required this.receiptType,
    required this.originMessageId,
    required this.incidentId,
    required this.immutableDigest,
    required this.signerKeyId,
    required this.signerPublicKey,
    required this.correlationId,
    this.attemptId,
    this.finalAuthorizationId,
    required this.sourcePeerDeviceId,
    this.previousHopKeyId,
    this.previousHopDeviceId,
    required this.payload,
    required this.signature,
    required this.storageBytes,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['semantic_key'] = Variable<String>(semanticKey);
    map['receipt_id'] = Variable<String>(receiptId);
    map['receipt_type'] = Variable<String>(receiptType);
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['immutable_digest'] = Variable<String>(immutableDigest);
    map['signer_key_id'] = Variable<String>(signerKeyId);
    map['signer_public_key'] = Variable<String>(signerPublicKey);
    map['correlation_id'] = Variable<String>(correlationId);
    if (!nullToAbsent || attemptId != null) {
      map['attempt_id'] = Variable<String>(attemptId);
    }
    if (!nullToAbsent || finalAuthorizationId != null) {
      map['final_authorization_id'] = Variable<String>(finalAuthorizationId);
    }
    map['source_peer_device_id'] = Variable<String>(sourcePeerDeviceId);
    if (!nullToAbsent || previousHopKeyId != null) {
      map['previous_hop_key_id'] = Variable<String>(previousHopKeyId);
    }
    if (!nullToAbsent || previousHopDeviceId != null) {
      map['previous_hop_device_id'] = Variable<String>(previousHopDeviceId);
    }
    map['payload'] = Variable<String>(payload);
    map['signature'] = Variable<String>(signature);
    map['storage_bytes'] = Variable<int>(storageBytes);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BleRelayReceiptsCompanion toCompanion(bool nullToAbsent) {
    return BleRelayReceiptsCompanion(
      semanticKey: Value(semanticKey),
      receiptId: Value(receiptId),
      receiptType: Value(receiptType),
      originMessageId: Value(originMessageId),
      incidentId: Value(incidentId),
      immutableDigest: Value(immutableDigest),
      signerKeyId: Value(signerKeyId),
      signerPublicKey: Value(signerPublicKey),
      correlationId: Value(correlationId),
      attemptId: attemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(attemptId),
      finalAuthorizationId: finalAuthorizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalAuthorizationId),
      sourcePeerDeviceId: Value(sourcePeerDeviceId),
      previousHopKeyId: previousHopKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousHopKeyId),
      previousHopDeviceId: previousHopDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousHopDeviceId),
      payload: Value(payload),
      signature: Value(signature),
      storageBytes: Value(storageBytes),
      state: Value(state),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BleRelayReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleRelayReceipt(
      semanticKey: serializer.fromJson<String>(json['semanticKey']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      receiptType: serializer.fromJson<String>(json['receiptType']),
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      immutableDigest: serializer.fromJson<String>(json['immutableDigest']),
      signerKeyId: serializer.fromJson<String>(json['signerKeyId']),
      signerPublicKey: serializer.fromJson<String>(json['signerPublicKey']),
      correlationId: serializer.fromJson<String>(json['correlationId']),
      attemptId: serializer.fromJson<String?>(json['attemptId']),
      finalAuthorizationId: serializer.fromJson<String?>(
        json['finalAuthorizationId'],
      ),
      sourcePeerDeviceId: serializer.fromJson<String>(
        json['sourcePeerDeviceId'],
      ),
      previousHopKeyId: serializer.fromJson<String?>(json['previousHopKeyId']),
      previousHopDeviceId: serializer.fromJson<String?>(
        json['previousHopDeviceId'],
      ),
      payload: serializer.fromJson<String>(json['payload']),
      signature: serializer.fromJson<String>(json['signature']),
      storageBytes: serializer.fromJson<int>(json['storageBytes']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'semanticKey': serializer.toJson<String>(semanticKey),
      'receiptId': serializer.toJson<String>(receiptId),
      'receiptType': serializer.toJson<String>(receiptType),
      'originMessageId': serializer.toJson<String>(originMessageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'immutableDigest': serializer.toJson<String>(immutableDigest),
      'signerKeyId': serializer.toJson<String>(signerKeyId),
      'signerPublicKey': serializer.toJson<String>(signerPublicKey),
      'correlationId': serializer.toJson<String>(correlationId),
      'attemptId': serializer.toJson<String?>(attemptId),
      'finalAuthorizationId': serializer.toJson<String?>(finalAuthorizationId),
      'sourcePeerDeviceId': serializer.toJson<String>(sourcePeerDeviceId),
      'previousHopKeyId': serializer.toJson<String?>(previousHopKeyId),
      'previousHopDeviceId': serializer.toJson<String?>(previousHopDeviceId),
      'payload': serializer.toJson<String>(payload),
      'signature': serializer.toJson<String>(signature),
      'storageBytes': serializer.toJson<int>(storageBytes),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BleRelayReceipt copyWith({
    String? semanticKey,
    String? receiptId,
    String? receiptType,
    String? originMessageId,
    String? incidentId,
    String? immutableDigest,
    String? signerKeyId,
    String? signerPublicKey,
    String? correlationId,
    Value<String?> attemptId = const Value.absent(),
    Value<String?> finalAuthorizationId = const Value.absent(),
    String? sourcePeerDeviceId,
    Value<String?> previousHopKeyId = const Value.absent(),
    Value<String?> previousHopDeviceId = const Value.absent(),
    String? payload,
    String? signature,
    int? storageBytes,
    String? state,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) => BleRelayReceipt(
    semanticKey: semanticKey ?? this.semanticKey,
    receiptId: receiptId ?? this.receiptId,
    receiptType: receiptType ?? this.receiptType,
    originMessageId: originMessageId ?? this.originMessageId,
    incidentId: incidentId ?? this.incidentId,
    immutableDigest: immutableDigest ?? this.immutableDigest,
    signerKeyId: signerKeyId ?? this.signerKeyId,
    signerPublicKey: signerPublicKey ?? this.signerPublicKey,
    correlationId: correlationId ?? this.correlationId,
    attemptId: attemptId.present ? attemptId.value : this.attemptId,
    finalAuthorizationId: finalAuthorizationId.present
        ? finalAuthorizationId.value
        : this.finalAuthorizationId,
    sourcePeerDeviceId: sourcePeerDeviceId ?? this.sourcePeerDeviceId,
    previousHopKeyId: previousHopKeyId.present
        ? previousHopKeyId.value
        : this.previousHopKeyId,
    previousHopDeviceId: previousHopDeviceId.present
        ? previousHopDeviceId.value
        : this.previousHopDeviceId,
    payload: payload ?? this.payload,
    signature: signature ?? this.signature,
    storageBytes: storageBytes ?? this.storageBytes,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BleRelayReceipt copyWithCompanion(BleRelayReceiptsCompanion data) {
    return BleRelayReceipt(
      semanticKey: data.semanticKey.present
          ? data.semanticKey.value
          : this.semanticKey,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      receiptType: data.receiptType.present
          ? data.receiptType.value
          : this.receiptType,
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      immutableDigest: data.immutableDigest.present
          ? data.immutableDigest.value
          : this.immutableDigest,
      signerKeyId: data.signerKeyId.present
          ? data.signerKeyId.value
          : this.signerKeyId,
      signerPublicKey: data.signerPublicKey.present
          ? data.signerPublicKey.value
          : this.signerPublicKey,
      correlationId: data.correlationId.present
          ? data.correlationId.value
          : this.correlationId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      finalAuthorizationId: data.finalAuthorizationId.present
          ? data.finalAuthorizationId.value
          : this.finalAuthorizationId,
      sourcePeerDeviceId: data.sourcePeerDeviceId.present
          ? data.sourcePeerDeviceId.value
          : this.sourcePeerDeviceId,
      previousHopKeyId: data.previousHopKeyId.present
          ? data.previousHopKeyId.value
          : this.previousHopKeyId,
      previousHopDeviceId: data.previousHopDeviceId.present
          ? data.previousHopDeviceId.value
          : this.previousHopDeviceId,
      payload: data.payload.present ? data.payload.value : this.payload,
      signature: data.signature.present ? data.signature.value : this.signature,
      storageBytes: data.storageBytes.present
          ? data.storageBytes.value
          : this.storageBytes,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleRelayReceipt(')
          ..write('semanticKey: $semanticKey, ')
          ..write('receiptId: $receiptId, ')
          ..write('receiptType: $receiptType, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('signerKeyId: $signerKeyId, ')
          ..write('signerPublicKey: $signerPublicKey, ')
          ..write('correlationId: $correlationId, ')
          ..write('attemptId: $attemptId, ')
          ..write('finalAuthorizationId: $finalAuthorizationId, ')
          ..write('sourcePeerDeviceId: $sourcePeerDeviceId, ')
          ..write('previousHopKeyId: $previousHopKeyId, ')
          ..write('previousHopDeviceId: $previousHopDeviceId, ')
          ..write('payload: $payload, ')
          ..write('signature: $signature, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    semanticKey,
    receiptId,
    receiptType,
    originMessageId,
    incidentId,
    immutableDigest,
    signerKeyId,
    signerPublicKey,
    correlationId,
    attemptId,
    finalAuthorizationId,
    sourcePeerDeviceId,
    previousHopKeyId,
    previousHopDeviceId,
    payload,
    signature,
    storageBytes,
    state,
    createdAt,
    expiresAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleRelayReceipt &&
          other.semanticKey == this.semanticKey &&
          other.receiptId == this.receiptId &&
          other.receiptType == this.receiptType &&
          other.originMessageId == this.originMessageId &&
          other.incidentId == this.incidentId &&
          other.immutableDigest == this.immutableDigest &&
          other.signerKeyId == this.signerKeyId &&
          other.signerPublicKey == this.signerPublicKey &&
          other.correlationId == this.correlationId &&
          other.attemptId == this.attemptId &&
          other.finalAuthorizationId == this.finalAuthorizationId &&
          other.sourcePeerDeviceId == this.sourcePeerDeviceId &&
          other.previousHopKeyId == this.previousHopKeyId &&
          other.previousHopDeviceId == this.previousHopDeviceId &&
          other.payload == this.payload &&
          other.signature == this.signature &&
          other.storageBytes == this.storageBytes &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.updatedAt == this.updatedAt);
}

class BleRelayReceiptsCompanion extends UpdateCompanion<BleRelayReceipt> {
  final Value<String> semanticKey;
  final Value<String> receiptId;
  final Value<String> receiptType;
  final Value<String> originMessageId;
  final Value<String> incidentId;
  final Value<String> immutableDigest;
  final Value<String> signerKeyId;
  final Value<String> signerPublicKey;
  final Value<String> correlationId;
  final Value<String?> attemptId;
  final Value<String?> finalAuthorizationId;
  final Value<String> sourcePeerDeviceId;
  final Value<String?> previousHopKeyId;
  final Value<String?> previousHopDeviceId;
  final Value<String> payload;
  final Value<String> signature;
  final Value<int> storageBytes;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BleRelayReceiptsCompanion({
    this.semanticKey = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.receiptType = const Value.absent(),
    this.originMessageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.immutableDigest = const Value.absent(),
    this.signerKeyId = const Value.absent(),
    this.signerPublicKey = const Value.absent(),
    this.correlationId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.finalAuthorizationId = const Value.absent(),
    this.sourcePeerDeviceId = const Value.absent(),
    this.previousHopKeyId = const Value.absent(),
    this.previousHopDeviceId = const Value.absent(),
    this.payload = const Value.absent(),
    this.signature = const Value.absent(),
    this.storageBytes = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleRelayReceiptsCompanion.insert({
    required String semanticKey,
    required String receiptId,
    required String receiptType,
    required String originMessageId,
    required String incidentId,
    required String immutableDigest,
    required String signerKeyId,
    required String signerPublicKey,
    required String correlationId,
    this.attemptId = const Value.absent(),
    this.finalAuthorizationId = const Value.absent(),
    required String sourcePeerDeviceId,
    this.previousHopKeyId = const Value.absent(),
    this.previousHopDeviceId = const Value.absent(),
    required String payload,
    required String signature,
    required int storageBytes,
    required String state,
    required DateTime createdAt,
    required DateTime expiresAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : semanticKey = Value(semanticKey),
       receiptId = Value(receiptId),
       receiptType = Value(receiptType),
       originMessageId = Value(originMessageId),
       incidentId = Value(incidentId),
       immutableDigest = Value(immutableDigest),
       signerKeyId = Value(signerKeyId),
       signerPublicKey = Value(signerPublicKey),
       correlationId = Value(correlationId),
       sourcePeerDeviceId = Value(sourcePeerDeviceId),
       payload = Value(payload),
       signature = Value(signature),
       storageBytes = Value(storageBytes),
       state = Value(state),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt),
       updatedAt = Value(updatedAt);
  static Insertable<BleRelayReceipt> custom({
    Expression<String>? semanticKey,
    Expression<String>? receiptId,
    Expression<String>? receiptType,
    Expression<String>? originMessageId,
    Expression<String>? incidentId,
    Expression<String>? immutableDigest,
    Expression<String>? signerKeyId,
    Expression<String>? signerPublicKey,
    Expression<String>? correlationId,
    Expression<String>? attemptId,
    Expression<String>? finalAuthorizationId,
    Expression<String>? sourcePeerDeviceId,
    Expression<String>? previousHopKeyId,
    Expression<String>? previousHopDeviceId,
    Expression<String>? payload,
    Expression<String>? signature,
    Expression<int>? storageBytes,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (semanticKey != null) 'semantic_key': semanticKey,
      if (receiptId != null) 'receipt_id': receiptId,
      if (receiptType != null) 'receipt_type': receiptType,
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (immutableDigest != null) 'immutable_digest': immutableDigest,
      if (signerKeyId != null) 'signer_key_id': signerKeyId,
      if (signerPublicKey != null) 'signer_public_key': signerPublicKey,
      if (correlationId != null) 'correlation_id': correlationId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (finalAuthorizationId != null)
        'final_authorization_id': finalAuthorizationId,
      if (sourcePeerDeviceId != null)
        'source_peer_device_id': sourcePeerDeviceId,
      if (previousHopKeyId != null) 'previous_hop_key_id': previousHopKeyId,
      if (previousHopDeviceId != null)
        'previous_hop_device_id': previousHopDeviceId,
      if (payload != null) 'payload': payload,
      if (signature != null) 'signature': signature,
      if (storageBytes != null) 'storage_bytes': storageBytes,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleRelayReceiptsCompanion copyWith({
    Value<String>? semanticKey,
    Value<String>? receiptId,
    Value<String>? receiptType,
    Value<String>? originMessageId,
    Value<String>? incidentId,
    Value<String>? immutableDigest,
    Value<String>? signerKeyId,
    Value<String>? signerPublicKey,
    Value<String>? correlationId,
    Value<String?>? attemptId,
    Value<String?>? finalAuthorizationId,
    Value<String>? sourcePeerDeviceId,
    Value<String?>? previousHopKeyId,
    Value<String?>? previousHopDeviceId,
    Value<String>? payload,
    Value<String>? signature,
    Value<int>? storageBytes,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BleRelayReceiptsCompanion(
      semanticKey: semanticKey ?? this.semanticKey,
      receiptId: receiptId ?? this.receiptId,
      receiptType: receiptType ?? this.receiptType,
      originMessageId: originMessageId ?? this.originMessageId,
      incidentId: incidentId ?? this.incidentId,
      immutableDigest: immutableDigest ?? this.immutableDigest,
      signerKeyId: signerKeyId ?? this.signerKeyId,
      signerPublicKey: signerPublicKey ?? this.signerPublicKey,
      correlationId: correlationId ?? this.correlationId,
      attemptId: attemptId ?? this.attemptId,
      finalAuthorizationId: finalAuthorizationId ?? this.finalAuthorizationId,
      sourcePeerDeviceId: sourcePeerDeviceId ?? this.sourcePeerDeviceId,
      previousHopKeyId: previousHopKeyId ?? this.previousHopKeyId,
      previousHopDeviceId: previousHopDeviceId ?? this.previousHopDeviceId,
      payload: payload ?? this.payload,
      signature: signature ?? this.signature,
      storageBytes: storageBytes ?? this.storageBytes,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (semanticKey.present) {
      map['semantic_key'] = Variable<String>(semanticKey.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (receiptType.present) {
      map['receipt_type'] = Variable<String>(receiptType.value);
    }
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (immutableDigest.present) {
      map['immutable_digest'] = Variable<String>(immutableDigest.value);
    }
    if (signerKeyId.present) {
      map['signer_key_id'] = Variable<String>(signerKeyId.value);
    }
    if (signerPublicKey.present) {
      map['signer_public_key'] = Variable<String>(signerPublicKey.value);
    }
    if (correlationId.present) {
      map['correlation_id'] = Variable<String>(correlationId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (finalAuthorizationId.present) {
      map['final_authorization_id'] = Variable<String>(
        finalAuthorizationId.value,
      );
    }
    if (sourcePeerDeviceId.present) {
      map['source_peer_device_id'] = Variable<String>(sourcePeerDeviceId.value);
    }
    if (previousHopKeyId.present) {
      map['previous_hop_key_id'] = Variable<String>(previousHopKeyId.value);
    }
    if (previousHopDeviceId.present) {
      map['previous_hop_device_id'] = Variable<String>(
        previousHopDeviceId.value,
      );
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (storageBytes.present) {
      map['storage_bytes'] = Variable<int>(storageBytes.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
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
    return (StringBuffer('BleRelayReceiptsCompanion(')
          ..write('semanticKey: $semanticKey, ')
          ..write('receiptId: $receiptId, ')
          ..write('receiptType: $receiptType, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('signerKeyId: $signerKeyId, ')
          ..write('signerPublicKey: $signerPublicKey, ')
          ..write('correlationId: $correlationId, ')
          ..write('attemptId: $attemptId, ')
          ..write('finalAuthorizationId: $finalAuthorizationId, ')
          ..write('sourcePeerDeviceId: $sourcePeerDeviceId, ')
          ..write('previousHopKeyId: $previousHopKeyId, ')
          ..write('previousHopDeviceId: $previousHopDeviceId, ')
          ..write('payload: $payload, ')
          ..write('signature: $signature, ')
          ..write('storageBytes: $storageBytes, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RescueInboxTable extends RescueInbox
    with TableInfo<$RescueInboxTable, RescueInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RescueInboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originKeyIdMeta = const VerificationMeta(
    'originKeyId',
  );
  @override
  late final GeneratedColumn<String> originKeyId = GeneratedColumn<String>(
    'origin_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _immutableDigestMeta = const VerificationMeta(
    'immutableDigest',
  );
  @override
  late final GeneratedColumn<String> immutableDigest = GeneratedColumn<String>(
    'immutable_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emergencyTypeMeta = const VerificationMeta(
    'emergencyType',
  );
  @override
  late final GeneratedColumn<String> emergencyType = GeneratedColumn<String>(
    'emergency_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emergencyMessageMeta = const VerificationMeta(
    'emergencyMessage',
  );
  @override
  late final GeneratedColumn<String> emergencyMessage = GeneratedColumn<String>(
    'emergency_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _includeLocationMeta = const VerificationMeta(
    'includeLocation',
  );
  @override
  late final GeneratedColumn<bool> includeLocation = GeneratedColumn<bool>(
    'include_location',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_location" IN (0, 1))',
    ),
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
  static const VerificationMeta _incomingHopCountMeta = const VerificationMeta(
    'incomingHopCount',
  );
  @override
  late final GeneratedColumn<int> incomingHopCount = GeneratedColumn<int>(
    'incoming_hop_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingPathMeta = const VerificationMeta(
    'incomingPath',
  );
  @override
  late final GeneratedColumn<String> incomingPath = GeneratedColumn<String>(
    'incoming_path',
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptanceIdMeta = const VerificationMeta(
    'acceptanceId',
  );
  @override
  late final GeneratedColumn<String> acceptanceId = GeneratedColumn<String>(
    'acceptance_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
    'accepted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    originMessageId,
    incidentId,
    originKeyId,
    immutableDigest,
    emergencyType,
    emergencyMessage,
    includeLocation,
    latitude,
    longitude,
    incomingHopCount,
    incomingPath,
    createdAt,
    expiresAt,
    receivedAt,
    state,
    acceptanceId,
    acceptedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rescue_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<RescueInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('origin_key_id')) {
      context.handle(
        _originKeyIdMeta,
        originKeyId.isAcceptableOrUnknown(
          data['origin_key_id']!,
          _originKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originKeyIdMeta);
    }
    if (data.containsKey('immutable_digest')) {
      context.handle(
        _immutableDigestMeta,
        immutableDigest.isAcceptableOrUnknown(
          data['immutable_digest']!,
          _immutableDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutableDigestMeta);
    }
    if (data.containsKey('emergency_type')) {
      context.handle(
        _emergencyTypeMeta,
        emergencyType.isAcceptableOrUnknown(
          data['emergency_type']!,
          _emergencyTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emergencyTypeMeta);
    }
    if (data.containsKey('emergency_message')) {
      context.handle(
        _emergencyMessageMeta,
        emergencyMessage.isAcceptableOrUnknown(
          data['emergency_message']!,
          _emergencyMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emergencyMessageMeta);
    }
    if (data.containsKey('include_location')) {
      context.handle(
        _includeLocationMeta,
        includeLocation.isAcceptableOrUnknown(
          data['include_location']!,
          _includeLocationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeLocationMeta);
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
    if (data.containsKey('incoming_hop_count')) {
      context.handle(
        _incomingHopCountMeta,
        incomingHopCount.isAcceptableOrUnknown(
          data['incoming_hop_count']!,
          _incomingHopCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingHopCountMeta);
    }
    if (data.containsKey('incoming_path')) {
      context.handle(
        _incomingPathMeta,
        incomingPath.isAcceptableOrUnknown(
          data['incoming_path']!,
          _incomingPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingPathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('acceptance_id')) {
      context.handle(
        _acceptanceIdMeta,
        acceptanceId.isAcceptableOrUnknown(
          data['acceptance_id']!,
          _acceptanceIdMeta,
        ),
      );
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, originMessageId};
  @override
  RescueInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RescueInboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      originKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_key_id'],
      )!,
      immutableDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_digest'],
      )!,
      emergencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emergency_type'],
      )!,
      emergencyMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emergency_message'],
      )!,
      includeLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_location'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      incomingHopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}incoming_hop_count'],
      )!,
      incomingPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incoming_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      acceptanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acceptance_id'],
      ),
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accepted_at'],
      ),
    );
  }

  @override
  $RescueInboxTable createAlias(String alias) {
    return $RescueInboxTable(attachedDatabase, alias);
  }
}

class RescueInboxData extends DataClass implements Insertable<RescueInboxData> {
  final String ownerId;
  final String originMessageId;
  final String incidentId;
  final String originKeyId;
  final String immutableDigest;
  final String emergencyType;
  final String emergencyMessage;
  final bool includeLocation;
  final double? latitude;
  final double? longitude;
  final int incomingHopCount;
  final String incomingPath;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime receivedAt;
  final String state;
  final String? acceptanceId;
  final DateTime? acceptedAt;
  const RescueInboxData({
    required this.ownerId,
    required this.originMessageId,
    required this.incidentId,
    required this.originKeyId,
    required this.immutableDigest,
    required this.emergencyType,
    required this.emergencyMessage,
    required this.includeLocation,
    this.latitude,
    this.longitude,
    required this.incomingHopCount,
    required this.incomingPath,
    required this.createdAt,
    required this.expiresAt,
    required this.receivedAt,
    required this.state,
    this.acceptanceId,
    this.acceptedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['origin_key_id'] = Variable<String>(originKeyId);
    map['immutable_digest'] = Variable<String>(immutableDigest);
    map['emergency_type'] = Variable<String>(emergencyType);
    map['emergency_message'] = Variable<String>(emergencyMessage);
    map['include_location'] = Variable<bool>(includeLocation);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['incoming_hop_count'] = Variable<int>(incomingHopCount);
    map['incoming_path'] = Variable<String>(incomingPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || acceptanceId != null) {
      map['acceptance_id'] = Variable<String>(acceptanceId);
    }
    if (!nullToAbsent || acceptedAt != null) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt);
    }
    return map;
  }

  RescueInboxCompanion toCompanion(bool nullToAbsent) {
    return RescueInboxCompanion(
      ownerId: Value(ownerId),
      originMessageId: Value(originMessageId),
      incidentId: Value(incidentId),
      originKeyId: Value(originKeyId),
      immutableDigest: Value(immutableDigest),
      emergencyType: Value(emergencyType),
      emergencyMessage: Value(emergencyMessage),
      includeLocation: Value(includeLocation),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      incomingHopCount: Value(incomingHopCount),
      incomingPath: Value(incomingPath),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      receivedAt: Value(receivedAt),
      state: Value(state),
      acceptanceId: acceptanceId == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptanceId),
      acceptedAt: acceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedAt),
    );
  }

  factory RescueInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RescueInboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      originKeyId: serializer.fromJson<String>(json['originKeyId']),
      immutableDigest: serializer.fromJson<String>(json['immutableDigest']),
      emergencyType: serializer.fromJson<String>(json['emergencyType']),
      emergencyMessage: serializer.fromJson<String>(json['emergencyMessage']),
      includeLocation: serializer.fromJson<bool>(json['includeLocation']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      incomingHopCount: serializer.fromJson<int>(json['incomingHopCount']),
      incomingPath: serializer.fromJson<String>(json['incomingPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      state: serializer.fromJson<String>(json['state']),
      acceptanceId: serializer.fromJson<String?>(json['acceptanceId']),
      acceptedAt: serializer.fromJson<DateTime?>(json['acceptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'originMessageId': serializer.toJson<String>(originMessageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'originKeyId': serializer.toJson<String>(originKeyId),
      'immutableDigest': serializer.toJson<String>(immutableDigest),
      'emergencyType': serializer.toJson<String>(emergencyType),
      'emergencyMessage': serializer.toJson<String>(emergencyMessage),
      'includeLocation': serializer.toJson<bool>(includeLocation),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'incomingHopCount': serializer.toJson<int>(incomingHopCount),
      'incomingPath': serializer.toJson<String>(incomingPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'state': serializer.toJson<String>(state),
      'acceptanceId': serializer.toJson<String?>(acceptanceId),
      'acceptedAt': serializer.toJson<DateTime?>(acceptedAt),
    };
  }

  RescueInboxData copyWith({
    String? ownerId,
    String? originMessageId,
    String? incidentId,
    String? originKeyId,
    String? immutableDigest,
    String? emergencyType,
    String? emergencyMessage,
    bool? includeLocation,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    int? incomingHopCount,
    String? incomingPath,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? receivedAt,
    String? state,
    Value<String?> acceptanceId = const Value.absent(),
    Value<DateTime?> acceptedAt = const Value.absent(),
  }) => RescueInboxData(
    ownerId: ownerId ?? this.ownerId,
    originMessageId: originMessageId ?? this.originMessageId,
    incidentId: incidentId ?? this.incidentId,
    originKeyId: originKeyId ?? this.originKeyId,
    immutableDigest: immutableDigest ?? this.immutableDigest,
    emergencyType: emergencyType ?? this.emergencyType,
    emergencyMessage: emergencyMessage ?? this.emergencyMessage,
    includeLocation: includeLocation ?? this.includeLocation,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    incomingHopCount: incomingHopCount ?? this.incomingHopCount,
    incomingPath: incomingPath ?? this.incomingPath,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    receivedAt: receivedAt ?? this.receivedAt,
    state: state ?? this.state,
    acceptanceId: acceptanceId.present ? acceptanceId.value : this.acceptanceId,
    acceptedAt: acceptedAt.present ? acceptedAt.value : this.acceptedAt,
  );
  RescueInboxData copyWithCompanion(RescueInboxCompanion data) {
    return RescueInboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      originKeyId: data.originKeyId.present
          ? data.originKeyId.value
          : this.originKeyId,
      immutableDigest: data.immutableDigest.present
          ? data.immutableDigest.value
          : this.immutableDigest,
      emergencyType: data.emergencyType.present
          ? data.emergencyType.value
          : this.emergencyType,
      emergencyMessage: data.emergencyMessage.present
          ? data.emergencyMessage.value
          : this.emergencyMessage,
      includeLocation: data.includeLocation.present
          ? data.includeLocation.value
          : this.includeLocation,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      incomingHopCount: data.incomingHopCount.present
          ? data.incomingHopCount.value
          : this.incomingHopCount,
      incomingPath: data.incomingPath.present
          ? data.incomingPath.value
          : this.incomingPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      state: data.state.present ? data.state.value : this.state,
      acceptanceId: data.acceptanceId.present
          ? data.acceptanceId.value
          : this.acceptanceId,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RescueInboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('emergencyType: $emergencyType, ')
          ..write('emergencyMessage: $emergencyMessage, ')
          ..write('includeLocation: $includeLocation, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('incomingHopCount: $incomingHopCount, ')
          ..write('incomingPath: $incomingPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('state: $state, ')
          ..write('acceptanceId: $acceptanceId, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    originMessageId,
    incidentId,
    originKeyId,
    immutableDigest,
    emergencyType,
    emergencyMessage,
    includeLocation,
    latitude,
    longitude,
    incomingHopCount,
    incomingPath,
    createdAt,
    expiresAt,
    receivedAt,
    state,
    acceptanceId,
    acceptedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RescueInboxData &&
          other.ownerId == this.ownerId &&
          other.originMessageId == this.originMessageId &&
          other.incidentId == this.incidentId &&
          other.originKeyId == this.originKeyId &&
          other.immutableDigest == this.immutableDigest &&
          other.emergencyType == this.emergencyType &&
          other.emergencyMessage == this.emergencyMessage &&
          other.includeLocation == this.includeLocation &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.incomingHopCount == this.incomingHopCount &&
          other.incomingPath == this.incomingPath &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.receivedAt == this.receivedAt &&
          other.state == this.state &&
          other.acceptanceId == this.acceptanceId &&
          other.acceptedAt == this.acceptedAt);
}

class RescueInboxCompanion extends UpdateCompanion<RescueInboxData> {
  final Value<String> ownerId;
  final Value<String> originMessageId;
  final Value<String> incidentId;
  final Value<String> originKeyId;
  final Value<String> immutableDigest;
  final Value<String> emergencyType;
  final Value<String> emergencyMessage;
  final Value<bool> includeLocation;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> incomingHopCount;
  final Value<String> incomingPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime> receivedAt;
  final Value<String> state;
  final Value<String?> acceptanceId;
  final Value<DateTime?> acceptedAt;
  final Value<int> rowid;
  const RescueInboxCompanion({
    this.ownerId = const Value.absent(),
    this.originMessageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.originKeyId = const Value.absent(),
    this.immutableDigest = const Value.absent(),
    this.emergencyType = const Value.absent(),
    this.emergencyMessage = const Value.absent(),
    this.includeLocation = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.incomingHopCount = const Value.absent(),
    this.incomingPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.state = const Value.absent(),
    this.acceptanceId = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RescueInboxCompanion.insert({
    required String ownerId,
    required String originMessageId,
    required String incidentId,
    required String originKeyId,
    required String immutableDigest,
    required String emergencyType,
    required String emergencyMessage,
    required bool includeLocation,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required int incomingHopCount,
    required String incomingPath,
    required DateTime createdAt,
    required DateTime expiresAt,
    required DateTime receivedAt,
    required String state,
    this.acceptanceId = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       originMessageId = Value(originMessageId),
       incidentId = Value(incidentId),
       originKeyId = Value(originKeyId),
       immutableDigest = Value(immutableDigest),
       emergencyType = Value(emergencyType),
       emergencyMessage = Value(emergencyMessage),
       includeLocation = Value(includeLocation),
       incomingHopCount = Value(incomingHopCount),
       incomingPath = Value(incomingPath),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt),
       receivedAt = Value(receivedAt),
       state = Value(state);
  static Insertable<RescueInboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? originMessageId,
    Expression<String>? incidentId,
    Expression<String>? originKeyId,
    Expression<String>? immutableDigest,
    Expression<String>? emergencyType,
    Expression<String>? emergencyMessage,
    Expression<bool>? includeLocation,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? incomingHopCount,
    Expression<String>? incomingPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? receivedAt,
    Expression<String>? state,
    Expression<String>? acceptanceId,
    Expression<DateTime>? acceptedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (originKeyId != null) 'origin_key_id': originKeyId,
      if (immutableDigest != null) 'immutable_digest': immutableDigest,
      if (emergencyType != null) 'emergency_type': emergencyType,
      if (emergencyMessage != null) 'emergency_message': emergencyMessage,
      if (includeLocation != null) 'include_location': includeLocation,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (incomingHopCount != null) 'incoming_hop_count': incomingHopCount,
      if (incomingPath != null) 'incoming_path': incomingPath,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (state != null) 'state': state,
      if (acceptanceId != null) 'acceptance_id': acceptanceId,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RescueInboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? originMessageId,
    Value<String>? incidentId,
    Value<String>? originKeyId,
    Value<String>? immutableDigest,
    Value<String>? emergencyType,
    Value<String>? emergencyMessage,
    Value<bool>? includeLocation,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? incomingHopCount,
    Value<String>? incomingPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<DateTime>? receivedAt,
    Value<String>? state,
    Value<String?>? acceptanceId,
    Value<DateTime?>? acceptedAt,
    Value<int>? rowid,
  }) {
    return RescueInboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      originMessageId: originMessageId ?? this.originMessageId,
      incidentId: incidentId ?? this.incidentId,
      originKeyId: originKeyId ?? this.originKeyId,
      immutableDigest: immutableDigest ?? this.immutableDigest,
      emergencyType: emergencyType ?? this.emergencyType,
      emergencyMessage: emergencyMessage ?? this.emergencyMessage,
      includeLocation: includeLocation ?? this.includeLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      incomingHopCount: incomingHopCount ?? this.incomingHopCount,
      incomingPath: incomingPath ?? this.incomingPath,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      receivedAt: receivedAt ?? this.receivedAt,
      state: state ?? this.state,
      acceptanceId: acceptanceId ?? this.acceptanceId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (originKeyId.present) {
      map['origin_key_id'] = Variable<String>(originKeyId.value);
    }
    if (immutableDigest.present) {
      map['immutable_digest'] = Variable<String>(immutableDigest.value);
    }
    if (emergencyType.present) {
      map['emergency_type'] = Variable<String>(emergencyType.value);
    }
    if (emergencyMessage.present) {
      map['emergency_message'] = Variable<String>(emergencyMessage.value);
    }
    if (includeLocation.present) {
      map['include_location'] = Variable<bool>(includeLocation.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (incomingHopCount.present) {
      map['incoming_hop_count'] = Variable<int>(incomingHopCount.value);
    }
    if (incomingPath.present) {
      map['incoming_path'] = Variable<String>(incomingPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (acceptanceId.present) {
      map['acceptance_id'] = Variable<String>(acceptanceId.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RescueInboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('emergencyType: $emergencyType, ')
          ..write('emergencyMessage: $emergencyMessage, ')
          ..write('includeLocation: $includeLocation, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('incomingHopCount: $incomingHopCount, ')
          ..write('incomingPath: $incomingPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('state: $state, ')
          ..write('acceptanceId: $acceptanceId, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RescueResponseOutboxTable extends RescueResponseOutbox
    with TableInfo<$RescueResponseOutboxTable, RescueResponseOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RescueResponseOutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originKeyIdMeta = const VerificationMeta(
    'originKeyId',
  );
  @override
  late final GeneratedColumn<String> originKeyId = GeneratedColumn<String>(
    'origin_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responderKeyIdMeta = const VerificationMeta(
    'responderKeyId',
  );
  @override
  late final GeneratedColumn<String> responderKeyId = GeneratedColumn<String>(
    'responder_key_id',
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _finalAckAtMeta = const VerificationMeta(
    'finalAckAt',
  );
  @override
  late final GeneratedColumn<DateTime> finalAckAt = GeneratedColumn<DateTime>(
    'final_ack_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    incidentId,
    originMessageId,
    originKeyId,
    responderKeyId,
    payload,
    state,
    retryCount,
    nextRetryAt,
    expiresAt,
    createdAt,
    updatedAt,
    finalAckAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rescue_response_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<RescueResponseOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('origin_key_id')) {
      context.handle(
        _originKeyIdMeta,
        originKeyId.isAcceptableOrUnknown(
          data['origin_key_id']!,
          _originKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originKeyIdMeta);
    }
    if (data.containsKey('responder_key_id')) {
      context.handle(
        _responderKeyIdMeta,
        responderKeyId.isAcceptableOrUnknown(
          data['responder_key_id']!,
          _responderKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responderKeyIdMeta);
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
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
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
    if (data.containsKey('final_ack_at')) {
      context.handle(
        _finalAckAtMeta,
        finalAckAt.isAcceptableOrUnknown(
          data['final_ack_at']!,
          _finalAckAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  RescueResponseOutboxData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RescueResponseOutboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      originKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_key_id'],
      )!,
      responderKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}responder_key_id'],
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
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      finalAckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}final_ack_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $RescueResponseOutboxTable createAlias(String alias) {
    return $RescueResponseOutboxTable(attachedDatabase, alias);
  }
}

class RescueResponseOutboxData extends DataClass
    implements Insertable<RescueResponseOutboxData> {
  final String ownerId;
  final String messageId;
  final String incidentId;
  final String originMessageId;
  final String originKeyId;
  final String responderKeyId;
  final String payload;
  final String state;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalAckAt;
  final String? lastError;
  const RescueResponseOutboxData({
    required this.ownerId,
    required this.messageId,
    required this.incidentId,
    required this.originMessageId,
    required this.originKeyId,
    required this.responderKeyId,
    required this.payload,
    required this.state,
    required this.retryCount,
    this.nextRetryAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.finalAckAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['origin_key_id'] = Variable<String>(originKeyId);
    map['responder_key_id'] = Variable<String>(responderKeyId);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || finalAckAt != null) {
      map['final_ack_at'] = Variable<DateTime>(finalAckAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  RescueResponseOutboxCompanion toCompanion(bool nullToAbsent) {
    return RescueResponseOutboxCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      incidentId: Value(incidentId),
      originMessageId: Value(originMessageId),
      originKeyId: Value(originKeyId),
      responderKeyId: Value(responderKeyId),
      payload: Value(payload),
      state: Value(state),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      finalAckAt: finalAckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finalAckAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory RescueResponseOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RescueResponseOutboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      originKeyId: serializer.fromJson<String>(json['originKeyId']),
      responderKeyId: serializer.fromJson<String>(json['responderKeyId']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      finalAckAt: serializer.fromJson<DateTime?>(json['finalAckAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'originMessageId': serializer.toJson<String>(originMessageId),
      'originKeyId': serializer.toJson<String>(originKeyId),
      'responderKeyId': serializer.toJson<String>(responderKeyId),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'finalAckAt': serializer.toJson<DateTime?>(finalAckAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  RescueResponseOutboxData copyWith({
    String? ownerId,
    String? messageId,
    String? incidentId,
    String? originMessageId,
    String? originKeyId,
    String? responderKeyId,
    String? payload,
    String? state,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> finalAckAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => RescueResponseOutboxData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    incidentId: incidentId ?? this.incidentId,
    originMessageId: originMessageId ?? this.originMessageId,
    originKeyId: originKeyId ?? this.originKeyId,
    responderKeyId: responderKeyId ?? this.responderKeyId,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    finalAckAt: finalAckAt.present ? finalAckAt.value : this.finalAckAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  RescueResponseOutboxData copyWithCompanion(
    RescueResponseOutboxCompanion data,
  ) {
    return RescueResponseOutboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      originKeyId: data.originKeyId.present
          ? data.originKeyId.value
          : this.originKeyId,
      responderKeyId: data.responderKeyId.present
          ? data.responderKeyId.value
          : this.responderKeyId,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      finalAckAt: data.finalAckAt.present
          ? data.finalAckAt.value
          : this.finalAckAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseOutboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('responderKeyId: $responderKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finalAckAt: $finalAckAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    incidentId,
    originMessageId,
    originKeyId,
    responderKeyId,
    payload,
    state,
    retryCount,
    nextRetryAt,
    expiresAt,
    createdAt,
    updatedAt,
    finalAckAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RescueResponseOutboxData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.incidentId == this.incidentId &&
          other.originMessageId == this.originMessageId &&
          other.originKeyId == this.originKeyId &&
          other.responderKeyId == this.responderKeyId &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.finalAckAt == this.finalAckAt &&
          other.lastError == this.lastError);
}

class RescueResponseOutboxCompanion
    extends UpdateCompanion<RescueResponseOutboxData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> incidentId;
  final Value<String> originMessageId;
  final Value<String> originKeyId;
  final Value<String> responderKeyId;
  final Value<String> payload;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> finalAckAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const RescueResponseOutboxCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.originMessageId = const Value.absent(),
    this.originKeyId = const Value.absent(),
    this.responderKeyId = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.finalAckAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RescueResponseOutboxCompanion.insert({
    required String ownerId,
    required String messageId,
    required String incidentId,
    required String originMessageId,
    required String originKeyId,
    required String responderKeyId,
    required String payload,
    required String state,
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime expiresAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.finalAckAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       incidentId = Value(incidentId),
       originMessageId = Value(originMessageId),
       originKeyId = Value(originKeyId),
       responderKeyId = Value(responderKeyId),
       payload = Value(payload),
       state = Value(state),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RescueResponseOutboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? incidentId,
    Expression<String>? originMessageId,
    Expression<String>? originKeyId,
    Expression<String>? responderKeyId,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? finalAckAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (originKeyId != null) 'origin_key_id': originKeyId,
      if (responderKeyId != null) 'responder_key_id': responderKeyId,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (finalAckAt != null) 'final_ack_at': finalAckAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RescueResponseOutboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? incidentId,
    Value<String>? originMessageId,
    Value<String>? originKeyId,
    Value<String>? responderKeyId,
    Value<String>? payload,
    Value<String>? state,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? expiresAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? finalAckAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return RescueResponseOutboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      incidentId: incidentId ?? this.incidentId,
      originMessageId: originMessageId ?? this.originMessageId,
      originKeyId: originKeyId ?? this.originKeyId,
      responderKeyId: responderKeyId ?? this.responderKeyId,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finalAckAt: finalAckAt ?? this.finalAckAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (originKeyId.present) {
      map['origin_key_id'] = Variable<String>(originKeyId.value);
    }
    if (responderKeyId.present) {
      map['responder_key_id'] = Variable<String>(responderKeyId.value);
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
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (finalAckAt.present) {
      map['final_ack_at'] = Variable<DateTime>(finalAckAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseOutboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('originKeyId: $originKeyId, ')
          ..write('responderKeyId: $responderKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finalAckAt: $finalAckAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RescueResponseInboxTable extends RescueResponseInbox
    with TableInfo<$RescueResponseInboxTable, RescueResponseInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RescueResponseInboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMessageIdMeta = const VerificationMeta(
    'originMessageId',
  );
  @override
  late final GeneratedColumn<String> originMessageId = GeneratedColumn<String>(
    'origin_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responderKeyIdMeta = const VerificationMeta(
    'responderKeyId',
  );
  @override
  late final GeneratedColumn<String> responderKeyId = GeneratedColumn<String>(
    'responder_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _immutableDigestMeta = const VerificationMeta(
    'immutableDigest',
  );
  @override
  late final GeneratedColumn<String> immutableDigest = GeneratedColumn<String>(
    'immutable_digest',
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
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    incidentId,
    originMessageId,
    responderKeyId,
    immutableDigest,
    payload,
    state,
    receivedAt,
    processedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rescue_response_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<RescueResponseInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('origin_message_id')) {
      context.handle(
        _originMessageIdMeta,
        originMessageId.isAcceptableOrUnknown(
          data['origin_message_id']!,
          _originMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originMessageIdMeta);
    }
    if (data.containsKey('responder_key_id')) {
      context.handle(
        _responderKeyIdMeta,
        responderKeyId.isAcceptableOrUnknown(
          data['responder_key_id']!,
          _responderKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responderKeyIdMeta);
    }
    if (data.containsKey('immutable_digest')) {
      context.handle(
        _immutableDigestMeta,
        immutableDigest.isAcceptableOrUnknown(
          data['immutable_digest']!,
          _immutableDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutableDigestMeta);
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
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  RescueResponseInboxData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RescueResponseInboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      originMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_message_id'],
      )!,
      responderKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}responder_key_id'],
      )!,
      immutableDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_digest'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      ),
    );
  }

  @override
  $RescueResponseInboxTable createAlias(String alias) {
    return $RescueResponseInboxTable(attachedDatabase, alias);
  }
}

class RescueResponseInboxData extends DataClass
    implements Insertable<RescueResponseInboxData> {
  final String ownerId;
  final String messageId;
  final String incidentId;
  final String originMessageId;
  final String responderKeyId;
  final String immutableDigest;
  final String payload;
  final String state;
  final DateTime receivedAt;
  final DateTime? processedAt;
  const RescueResponseInboxData({
    required this.ownerId,
    required this.messageId,
    required this.incidentId,
    required this.originMessageId,
    required this.responderKeyId,
    required this.immutableDigest,
    required this.payload,
    required this.state,
    required this.receivedAt,
    this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['origin_message_id'] = Variable<String>(originMessageId);
    map['responder_key_id'] = Variable<String>(responderKeyId);
    map['immutable_digest'] = Variable<String>(immutableDigest);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['received_at'] = Variable<DateTime>(receivedAt);
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<DateTime>(processedAt);
    }
    return map;
  }

  RescueResponseInboxCompanion toCompanion(bool nullToAbsent) {
    return RescueResponseInboxCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      incidentId: Value(incidentId),
      originMessageId: Value(originMessageId),
      responderKeyId: Value(responderKeyId),
      immutableDigest: Value(immutableDigest),
      payload: Value(payload),
      state: Value(state),
      receivedAt: Value(receivedAt),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
    );
  }

  factory RescueResponseInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RescueResponseInboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      originMessageId: serializer.fromJson<String>(json['originMessageId']),
      responderKeyId: serializer.fromJson<String>(json['responderKeyId']),
      immutableDigest: serializer.fromJson<String>(json['immutableDigest']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      processedAt: serializer.fromJson<DateTime?>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'originMessageId': serializer.toJson<String>(originMessageId),
      'responderKeyId': serializer.toJson<String>(responderKeyId),
      'immutableDigest': serializer.toJson<String>(immutableDigest),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'processedAt': serializer.toJson<DateTime?>(processedAt),
    };
  }

  RescueResponseInboxData copyWith({
    String? ownerId,
    String? messageId,
    String? incidentId,
    String? originMessageId,
    String? responderKeyId,
    String? immutableDigest,
    String? payload,
    String? state,
    DateTime? receivedAt,
    Value<DateTime?> processedAt = const Value.absent(),
  }) => RescueResponseInboxData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    incidentId: incidentId ?? this.incidentId,
    originMessageId: originMessageId ?? this.originMessageId,
    responderKeyId: responderKeyId ?? this.responderKeyId,
    immutableDigest: immutableDigest ?? this.immutableDigest,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    receivedAt: receivedAt ?? this.receivedAt,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
  );
  RescueResponseInboxData copyWithCompanion(RescueResponseInboxCompanion data) {
    return RescueResponseInboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      originMessageId: data.originMessageId.present
          ? data.originMessageId.value
          : this.originMessageId,
      responderKeyId: data.responderKeyId.present
          ? data.responderKeyId.value
          : this.responderKeyId,
      immutableDigest: data.immutableDigest.present
          ? data.immutableDigest.value
          : this.immutableDigest,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseInboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('responderKeyId: $responderKeyId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    incidentId,
    originMessageId,
    responderKeyId,
    immutableDigest,
    payload,
    state,
    receivedAt,
    processedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RescueResponseInboxData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.incidentId == this.incidentId &&
          other.originMessageId == this.originMessageId &&
          other.responderKeyId == this.responderKeyId &&
          other.immutableDigest == this.immutableDigest &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.receivedAt == this.receivedAt &&
          other.processedAt == this.processedAt);
}

class RescueResponseInboxCompanion
    extends UpdateCompanion<RescueResponseInboxData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> incidentId;
  final Value<String> originMessageId;
  final Value<String> responderKeyId;
  final Value<String> immutableDigest;
  final Value<String> payload;
  final Value<String> state;
  final Value<DateTime> receivedAt;
  final Value<DateTime?> processedAt;
  final Value<int> rowid;
  const RescueResponseInboxCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.originMessageId = const Value.absent(),
    this.responderKeyId = const Value.absent(),
    this.immutableDigest = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RescueResponseInboxCompanion.insert({
    required String ownerId,
    required String messageId,
    required String incidentId,
    required String originMessageId,
    required String responderKeyId,
    required String immutableDigest,
    required String payload,
    required String state,
    required DateTime receivedAt,
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       incidentId = Value(incidentId),
       originMessageId = Value(originMessageId),
       responderKeyId = Value(responderKeyId),
       immutableDigest = Value(immutableDigest),
       payload = Value(payload),
       state = Value(state),
       receivedAt = Value(receivedAt);
  static Insertable<RescueResponseInboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? incidentId,
    Expression<String>? originMessageId,
    Expression<String>? responderKeyId,
    Expression<String>? immutableDigest,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? processedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (originMessageId != null) 'origin_message_id': originMessageId,
      if (responderKeyId != null) 'responder_key_id': responderKeyId,
      if (immutableDigest != null) 'immutable_digest': immutableDigest,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (receivedAt != null) 'received_at': receivedAt,
      if (processedAt != null) 'processed_at': processedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RescueResponseInboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? incidentId,
    Value<String>? originMessageId,
    Value<String>? responderKeyId,
    Value<String>? immutableDigest,
    Value<String>? payload,
    Value<String>? state,
    Value<DateTime>? receivedAt,
    Value<DateTime?>? processedAt,
    Value<int>? rowid,
  }) {
    return RescueResponseInboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      incidentId: incidentId ?? this.incidentId,
      originMessageId: originMessageId ?? this.originMessageId,
      responderKeyId: responderKeyId ?? this.responderKeyId,
      immutableDigest: immutableDigest ?? this.immutableDigest,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      receivedAt: receivedAt ?? this.receivedAt,
      processedAt: processedAt ?? this.processedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (originMessageId.present) {
      map['origin_message_id'] = Variable<String>(originMessageId.value);
    }
    if (responderKeyId.present) {
      map['responder_key_id'] = Variable<String>(responderKeyId.value);
    }
    if (immutableDigest.present) {
      map['immutable_digest'] = Variable<String>(immutableDigest.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseInboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('originMessageId: $originMessageId, ')
          ..write('responderKeyId: $responderKeyId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('processedAt: $processedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RescueResponseJobsTable extends RescueResponseJobs
    with TableInfo<$RescueResponseJobsTable, RescueResponseJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RescueResponseJobsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _responseMessageIdMeta = const VerificationMeta(
    'responseMessageId',
  );
  @override
  late final GeneratedColumn<String> responseMessageId =
      GeneratedColumn<String>(
        'response_message_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _nextHopKeyIdMeta = const VerificationMeta(
    'nextHopKeyId',
  );
  @override
  late final GeneratedColumn<String> nextHopKeyId = GeneratedColumn<String>(
    'next_hop_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextHopDeviceIdMeta = const VerificationMeta(
    'nextHopDeviceId',
  );
  @override
  late final GeneratedColumn<String> nextHopDeviceId = GeneratedColumn<String>(
    'next_hop_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionBindingMeta = const VerificationMeta(
    'sessionBinding',
  );
  @override
  late final GeneratedColumn<String> sessionBinding = GeneratedColumn<String>(
    'session_binding',
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
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    responseMessageId,
    nextHopKeyId,
    nextHopDeviceId,
    sessionBinding,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    createdAt,
    updatedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rescue_response_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RescueResponseJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('response_message_id')) {
      context.handle(
        _responseMessageIdMeta,
        responseMessageId.isAcceptableOrUnknown(
          data['response_message_id']!,
          _responseMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseMessageIdMeta);
    }
    if (data.containsKey('next_hop_key_id')) {
      context.handle(
        _nextHopKeyIdMeta,
        nextHopKeyId.isAcceptableOrUnknown(
          data['next_hop_key_id']!,
          _nextHopKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextHopKeyIdMeta);
    }
    if (data.containsKey('next_hop_device_id')) {
      context.handle(
        _nextHopDeviceIdMeta,
        nextHopDeviceId.isAcceptableOrUnknown(
          data['next_hop_device_id']!,
          _nextHopDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextHopDeviceIdMeta);
    }
    if (data.containsKey('session_binding')) {
      context.handle(
        _sessionBindingMeta,
        sessionBinding.isAcceptableOrUnknown(
          data['session_binding']!,
          _sessionBindingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionBindingMeta);
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
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    ownerId,
    responseMessageId,
    nextHopKeyId,
  };
  @override
  RescueResponseJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RescueResponseJob(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      responseMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_message_id'],
      )!,
      nextHopKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_hop_key_id'],
      )!,
      nextHopDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_hop_device_id'],
      )!,
      sessionBinding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_binding'],
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
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $RescueResponseJobsTable createAlias(String alias) {
    return $RescueResponseJobsTable(attachedDatabase, alias);
  }
}

class RescueResponseJob extends DataClass
    implements Insertable<RescueResponseJob> {
  final String ownerId;
  final String responseMessageId;
  final String nextHopKeyId;
  final String nextHopDeviceId;
  final String sessionBinding;
  final String state;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
  const RescueResponseJob({
    required this.ownerId,
    required this.responseMessageId,
    required this.nextHopKeyId,
    required this.nextHopDeviceId,
    required this.sessionBinding,
    required this.state,
    required this.retryCount,
    this.nextRetryAt,
    this.lastAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['response_message_id'] = Variable<String>(responseMessageId);
    map['next_hop_key_id'] = Variable<String>(nextHopKeyId);
    map['next_hop_device_id'] = Variable<String>(nextHopDeviceId);
    map['session_binding'] = Variable<String>(sessionBinding);
    map['state'] = Variable<String>(state);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  RescueResponseJobsCompanion toCompanion(bool nullToAbsent) {
    return RescueResponseJobsCompanion(
      ownerId: Value(ownerId),
      responseMessageId: Value(responseMessageId),
      nextHopKeyId: Value(nextHopKeyId),
      nextHopDeviceId: Value(nextHopDeviceId),
      sessionBinding: Value(sessionBinding),
      state: Value(state),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory RescueResponseJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RescueResponseJob(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      responseMessageId: serializer.fromJson<String>(json['responseMessageId']),
      nextHopKeyId: serializer.fromJson<String>(json['nextHopKeyId']),
      nextHopDeviceId: serializer.fromJson<String>(json['nextHopDeviceId']),
      sessionBinding: serializer.fromJson<String>(json['sessionBinding']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'responseMessageId': serializer.toJson<String>(responseMessageId),
      'nextHopKeyId': serializer.toJson<String>(nextHopKeyId),
      'nextHopDeviceId': serializer.toJson<String>(nextHopDeviceId),
      'sessionBinding': serializer.toJson<String>(sessionBinding),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  RescueResponseJob copyWith({
    String? ownerId,
    String? responseMessageId,
    String? nextHopKeyId,
    String? nextHopDeviceId,
    String? sessionBinding,
    String? state,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> lastError = const Value.absent(),
  }) => RescueResponseJob(
    ownerId: ownerId ?? this.ownerId,
    responseMessageId: responseMessageId ?? this.responseMessageId,
    nextHopKeyId: nextHopKeyId ?? this.nextHopKeyId,
    nextHopDeviceId: nextHopDeviceId ?? this.nextHopDeviceId,
    sessionBinding: sessionBinding ?? this.sessionBinding,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  RescueResponseJob copyWithCompanion(RescueResponseJobsCompanion data) {
    return RescueResponseJob(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      responseMessageId: data.responseMessageId.present
          ? data.responseMessageId.value
          : this.responseMessageId,
      nextHopKeyId: data.nextHopKeyId.present
          ? data.nextHopKeyId.value
          : this.nextHopKeyId,
      nextHopDeviceId: data.nextHopDeviceId.present
          ? data.nextHopDeviceId.value
          : this.nextHopDeviceId,
      sessionBinding: data.sessionBinding.present
          ? data.sessionBinding.value
          : this.sessionBinding,
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
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseJob(')
          ..write('ownerId: $ownerId, ')
          ..write('responseMessageId: $responseMessageId, ')
          ..write('nextHopKeyId: $nextHopKeyId, ')
          ..write('nextHopDeviceId: $nextHopDeviceId, ')
          ..write('sessionBinding: $sessionBinding, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    responseMessageId,
    nextHopKeyId,
    nextHopDeviceId,
    sessionBinding,
    state,
    retryCount,
    nextRetryAt,
    lastAttemptAt,
    createdAt,
    updatedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RescueResponseJob &&
          other.ownerId == this.ownerId &&
          other.responseMessageId == this.responseMessageId &&
          other.nextHopKeyId == this.nextHopKeyId &&
          other.nextHopDeviceId == this.nextHopDeviceId &&
          other.sessionBinding == this.sessionBinding &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastError == this.lastError);
}

class RescueResponseJobsCompanion extends UpdateCompanion<RescueResponseJob> {
  final Value<String> ownerId;
  final Value<String> responseMessageId;
  final Value<String> nextHopKeyId;
  final Value<String> nextHopDeviceId;
  final Value<String> sessionBinding;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const RescueResponseJobsCompanion({
    this.ownerId = const Value.absent(),
    this.responseMessageId = const Value.absent(),
    this.nextHopKeyId = const Value.absent(),
    this.nextHopDeviceId = const Value.absent(),
    this.sessionBinding = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RescueResponseJobsCompanion.insert({
    required String ownerId,
    required String responseMessageId,
    required String nextHopKeyId,
    required String nextHopDeviceId,
    required String sessionBinding,
    required String state,
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       responseMessageId = Value(responseMessageId),
       nextHopKeyId = Value(nextHopKeyId),
       nextHopDeviceId = Value(nextHopDeviceId),
       sessionBinding = Value(sessionBinding),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RescueResponseJob> custom({
    Expression<String>? ownerId,
    Expression<String>? responseMessageId,
    Expression<String>? nextHopKeyId,
    Expression<String>? nextHopDeviceId,
    Expression<String>? sessionBinding,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (responseMessageId != null) 'response_message_id': responseMessageId,
      if (nextHopKeyId != null) 'next_hop_key_id': nextHopKeyId,
      if (nextHopDeviceId != null) 'next_hop_device_id': nextHopDeviceId,
      if (sessionBinding != null) 'session_binding': sessionBinding,
      if (state != null) 'state': state,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RescueResponseJobsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? responseMessageId,
    Value<String>? nextHopKeyId,
    Value<String>? nextHopDeviceId,
    Value<String>? sessionBinding,
    Value<String>? state,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return RescueResponseJobsCompanion(
      ownerId: ownerId ?? this.ownerId,
      responseMessageId: responseMessageId ?? this.responseMessageId,
      nextHopKeyId: nextHopKeyId ?? this.nextHopKeyId,
      nextHopDeviceId: nextHopDeviceId ?? this.nextHopDeviceId,
      sessionBinding: sessionBinding ?? this.sessionBinding,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (responseMessageId.present) {
      map['response_message_id'] = Variable<String>(responseMessageId.value);
    }
    if (nextHopKeyId.present) {
      map['next_hop_key_id'] = Variable<String>(nextHopKeyId.value);
    }
    if (nextHopDeviceId.present) {
      map['next_hop_device_id'] = Variable<String>(nextHopDeviceId.value);
    }
    if (sessionBinding.present) {
      map['session_binding'] = Variable<String>(sessionBinding.value);
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseJobsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('responseMessageId: $responseMessageId, ')
          ..write('nextHopKeyId: $nextHopKeyId, ')
          ..write('nextHopDeviceId: $nextHopDeviceId, ')
          ..write('sessionBinding: $sessionBinding, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RescueResponseReplayTable extends RescueResponseReplay
    with TableInfo<$RescueResponseReplayTable, RescueResponseReplayData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RescueResponseReplayTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _immutableDigestMeta = const VerificationMeta(
    'immutableDigest',
  );
  @override
  late final GeneratedColumn<String> immutableDigest = GeneratedColumn<String>(
    'immutable_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    immutableDigest,
    firstSeenAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rescue_response_replay';
  @override
  VerificationContext validateIntegrity(
    Insertable<RescueResponseReplayData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('immutable_digest')) {
      context.handle(
        _immutableDigestMeta,
        immutableDigest.isAcceptableOrUnknown(
          data['immutable_digest']!,
          _immutableDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_immutableDigestMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  RescueResponseReplayData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RescueResponseReplayData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      immutableDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immutable_digest'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $RescueResponseReplayTable createAlias(String alias) {
    return $RescueResponseReplayTable(attachedDatabase, alias);
  }
}

class RescueResponseReplayData extends DataClass
    implements Insertable<RescueResponseReplayData> {
  final String ownerId;
  final String messageId;
  final String immutableDigest;
  final DateTime firstSeenAt;
  final DateTime expiresAt;
  const RescueResponseReplayData({
    required this.ownerId,
    required this.messageId,
    required this.immutableDigest,
    required this.firstSeenAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['immutable_digest'] = Variable<String>(immutableDigest);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  RescueResponseReplayCompanion toCompanion(bool nullToAbsent) {
    return RescueResponseReplayCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      immutableDigest: Value(immutableDigest),
      firstSeenAt: Value(firstSeenAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory RescueResponseReplayData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RescueResponseReplayData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      immutableDigest: serializer.fromJson<String>(json['immutableDigest']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'immutableDigest': serializer.toJson<String>(immutableDigest),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  RescueResponseReplayData copyWith({
    String? ownerId,
    String? messageId,
    String? immutableDigest,
    DateTime? firstSeenAt,
    DateTime? expiresAt,
  }) => RescueResponseReplayData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    immutableDigest: immutableDigest ?? this.immutableDigest,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  RescueResponseReplayData copyWithCompanion(
    RescueResponseReplayCompanion data,
  ) {
    return RescueResponseReplayData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      immutableDigest: data.immutableDigest.present
          ? data.immutableDigest.value
          : this.immutableDigest,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseReplayData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(ownerId, messageId, immutableDigest, firstSeenAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RescueResponseReplayData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.immutableDigest == this.immutableDigest &&
          other.firstSeenAt == this.firstSeenAt &&
          other.expiresAt == this.expiresAt);
}

class RescueResponseReplayCompanion
    extends UpdateCompanion<RescueResponseReplayData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> immutableDigest;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const RescueResponseReplayCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.immutableDigest = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RescueResponseReplayCompanion.insert({
    required String ownerId,
    required String messageId,
    required String immutableDigest,
    required DateTime firstSeenAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       immutableDigest = Value(immutableDigest),
       firstSeenAt = Value(firstSeenAt),
       expiresAt = Value(expiresAt);
  static Insertable<RescueResponseReplayData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? immutableDigest,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (immutableDigest != null) 'immutable_digest': immutableDigest,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RescueResponseReplayCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? immutableDigest,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return RescueResponseReplayCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      immutableDigest: immutableDigest ?? this.immutableDigest,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (immutableDigest.present) {
      map['immutable_digest'] = Variable<String>(immutableDigest.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RescueResponseReplayCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('immutableDigest: $immutableDigest, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatRelayOutboxTable extends ChatRelayOutbox
    with TableInfo<$ChatRelayOutboxTable, ChatRelayOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatRelayOutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderKeyIdMeta = const VerificationMeta(
    'senderKeyId',
  );
  @override
  late final GeneratedColumn<String> senderKeyId = GeneratedColumn<String>(
    'sender_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientKeyIdMeta = const VerificationMeta(
    'recipientKeyId',
  );
  @override
  late final GeneratedColumn<String> recipientKeyId = GeneratedColumn<String>(
    'recipient_key_id',
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
  static const VerificationMeta _hopCountMeta = const VerificationMeta(
    'hopCount',
  );
  @override
  late final GeneratedColumn<int> hopCount = GeneratedColumn<int>(
    'hop_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    incidentId,
    senderKeyId,
    recipientKeyId,
    payload,
    state,
    hopCount,
    retryCount,
    nextRetryAt,
    expiresAt,
    createdAt,
    updatedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_relay_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatRelayOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('sender_key_id')) {
      context.handle(
        _senderKeyIdMeta,
        senderKeyId.isAcceptableOrUnknown(
          data['sender_key_id']!,
          _senderKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderKeyIdMeta);
    }
    if (data.containsKey('recipient_key_id')) {
      context.handle(
        _recipientKeyIdMeta,
        recipientKeyId.isAcceptableOrUnknown(
          data['recipient_key_id']!,
          _recipientKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientKeyIdMeta);
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
    if (data.containsKey('hop_count')) {
      context.handle(
        _hopCountMeta,
        hopCount.isAcceptableOrUnknown(data['hop_count']!, _hopCountMeta),
      );
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
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
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
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  ChatRelayOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatRelayOutboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      senderKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_key_id'],
      )!,
      recipientKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_key_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      hopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hop_count'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ChatRelayOutboxTable createAlias(String alias) {
    return $ChatRelayOutboxTable(attachedDatabase, alias);
  }
}

class ChatRelayOutboxData extends DataClass
    implements Insertable<ChatRelayOutboxData> {
  final String ownerId;
  final String messageId;
  final String incidentId;
  final String senderKeyId;
  final String recipientKeyId;
  final String payload;
  final String state;
  final int hopCount;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
  const ChatRelayOutboxData({
    required this.ownerId,
    required this.messageId,
    required this.incidentId,
    required this.senderKeyId,
    required this.recipientKeyId,
    required this.payload,
    required this.state,
    required this.hopCount,
    required this.retryCount,
    this.nextRetryAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['sender_key_id'] = Variable<String>(senderKeyId);
    map['recipient_key_id'] = Variable<String>(recipientKeyId);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['hop_count'] = Variable<int>(hopCount);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ChatRelayOutboxCompanion toCompanion(bool nullToAbsent) {
    return ChatRelayOutboxCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      incidentId: Value(incidentId),
      senderKeyId: Value(senderKeyId),
      recipientKeyId: Value(recipientKeyId),
      payload: Value(payload),
      state: Value(state),
      hopCount: Value(hopCount),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory ChatRelayOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatRelayOutboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      senderKeyId: serializer.fromJson<String>(json['senderKeyId']),
      recipientKeyId: serializer.fromJson<String>(json['recipientKeyId']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      hopCount: serializer.fromJson<int>(json['hopCount']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'senderKeyId': serializer.toJson<String>(senderKeyId),
      'recipientKeyId': serializer.toJson<String>(recipientKeyId),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'hopCount': serializer.toJson<int>(hopCount),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  ChatRelayOutboxData copyWith({
    String? ownerId,
    String? messageId,
    String? incidentId,
    String? senderKeyId,
    String? recipientKeyId,
    String? payload,
    String? state,
    int? hopCount,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> lastError = const Value.absent(),
  }) => ChatRelayOutboxData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    incidentId: incidentId ?? this.incidentId,
    senderKeyId: senderKeyId ?? this.senderKeyId,
    recipientKeyId: recipientKeyId ?? this.recipientKeyId,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    hopCount: hopCount ?? this.hopCount,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  ChatRelayOutboxData copyWithCompanion(ChatRelayOutboxCompanion data) {
    return ChatRelayOutboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      senderKeyId: data.senderKeyId.present
          ? data.senderKeyId.value
          : this.senderKeyId,
      recipientKeyId: data.recipientKeyId.present
          ? data.recipientKeyId.value
          : this.recipientKeyId,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      hopCount: data.hopCount.present ? data.hopCount.value : this.hopCount,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatRelayOutboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('senderKeyId: $senderKeyId, ')
          ..write('recipientKeyId: $recipientKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('hopCount: $hopCount, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    incidentId,
    senderKeyId,
    recipientKeyId,
    payload,
    state,
    hopCount,
    retryCount,
    nextRetryAt,
    expiresAt,
    createdAt,
    updatedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatRelayOutboxData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.incidentId == this.incidentId &&
          other.senderKeyId == this.senderKeyId &&
          other.recipientKeyId == this.recipientKeyId &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.hopCount == this.hopCount &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastError == this.lastError);
}

class ChatRelayOutboxCompanion extends UpdateCompanion<ChatRelayOutboxData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> incidentId;
  final Value<String> senderKeyId;
  final Value<String> recipientKeyId;
  final Value<String> payload;
  final Value<String> state;
  final Value<int> hopCount;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const ChatRelayOutboxCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.senderKeyId = const Value.absent(),
    this.recipientKeyId = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.hopCount = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatRelayOutboxCompanion.insert({
    required String ownerId,
    required String messageId,
    required String incidentId,
    required String senderKeyId,
    required String recipientKeyId,
    required String payload,
    required String state,
    this.hopCount = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime expiresAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       incidentId = Value(incidentId),
       senderKeyId = Value(senderKeyId),
       recipientKeyId = Value(recipientKeyId),
       payload = Value(payload),
       state = Value(state),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChatRelayOutboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? incidentId,
    Expression<String>? senderKeyId,
    Expression<String>? recipientKeyId,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<int>? hopCount,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (senderKeyId != null) 'sender_key_id': senderKeyId,
      if (recipientKeyId != null) 'recipient_key_id': recipientKeyId,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (hopCount != null) 'hop_count': hopCount,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatRelayOutboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? incidentId,
    Value<String>? senderKeyId,
    Value<String>? recipientKeyId,
    Value<String>? payload,
    Value<String>? state,
    Value<int>? hopCount,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? expiresAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return ChatRelayOutboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      incidentId: incidentId ?? this.incidentId,
      senderKeyId: senderKeyId ?? this.senderKeyId,
      recipientKeyId: recipientKeyId ?? this.recipientKeyId,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      hopCount: hopCount ?? this.hopCount,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (senderKeyId.present) {
      map['sender_key_id'] = Variable<String>(senderKeyId.value);
    }
    if (recipientKeyId.present) {
      map['recipient_key_id'] = Variable<String>(recipientKeyId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (hopCount.present) {
      map['hop_count'] = Variable<int>(hopCount.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatRelayOutboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('senderKeyId: $senderKeyId, ')
          ..write('recipientKeyId: $recipientKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('hopCount: $hopCount, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatRelayInboxTable extends ChatRelayInbox
    with TableInfo<$ChatRelayInboxTable, ChatRelayInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatRelayInboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderKeyIdMeta = const VerificationMeta(
    'senderKeyId',
  );
  @override
  late final GeneratedColumn<String> senderKeyId = GeneratedColumn<String>(
    'sender_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientKeyIdMeta = const VerificationMeta(
    'recipientKeyId',
  );
  @override
  late final GeneratedColumn<String> recipientKeyId = GeneratedColumn<String>(
    'recipient_key_id',
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
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    incidentId,
    senderKeyId,
    recipientKeyId,
    payload,
    state,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_relay_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatRelayInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('sender_key_id')) {
      context.handle(
        _senderKeyIdMeta,
        senderKeyId.isAcceptableOrUnknown(
          data['sender_key_id']!,
          _senderKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderKeyIdMeta);
    }
    if (data.containsKey('recipient_key_id')) {
      context.handle(
        _recipientKeyIdMeta,
        recipientKeyId.isAcceptableOrUnknown(
          data['recipient_key_id']!,
          _recipientKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientKeyIdMeta);
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
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  ChatRelayInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatRelayInboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      senderKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_key_id'],
      )!,
      recipientKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_key_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $ChatRelayInboxTable createAlias(String alias) {
    return $ChatRelayInboxTable(attachedDatabase, alias);
  }
}

class ChatRelayInboxData extends DataClass
    implements Insertable<ChatRelayInboxData> {
  final String ownerId;
  final String messageId;
  final String incidentId;
  final String senderKeyId;
  final String recipientKeyId;
  final String payload;
  final String state;
  final DateTime receivedAt;
  const ChatRelayInboxData({
    required this.ownerId,
    required this.messageId,
    required this.incidentId,
    required this.senderKeyId,
    required this.recipientKeyId,
    required this.payload,
    required this.state,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['sender_key_id'] = Variable<String>(senderKeyId);
    map['recipient_key_id'] = Variable<String>(recipientKeyId);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  ChatRelayInboxCompanion toCompanion(bool nullToAbsent) {
    return ChatRelayInboxCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      incidentId: Value(incidentId),
      senderKeyId: Value(senderKeyId),
      recipientKeyId: Value(recipientKeyId),
      payload: Value(payload),
      state: Value(state),
      receivedAt: Value(receivedAt),
    );
  }

  factory ChatRelayInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatRelayInboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      senderKeyId: serializer.fromJson<String>(json['senderKeyId']),
      recipientKeyId: serializer.fromJson<String>(json['recipientKeyId']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'senderKeyId': serializer.toJson<String>(senderKeyId),
      'recipientKeyId': serializer.toJson<String>(recipientKeyId),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  ChatRelayInboxData copyWith({
    String? ownerId,
    String? messageId,
    String? incidentId,
    String? senderKeyId,
    String? recipientKeyId,
    String? payload,
    String? state,
    DateTime? receivedAt,
  }) => ChatRelayInboxData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    incidentId: incidentId ?? this.incidentId,
    senderKeyId: senderKeyId ?? this.senderKeyId,
    recipientKeyId: recipientKeyId ?? this.recipientKeyId,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  ChatRelayInboxData copyWithCompanion(ChatRelayInboxCompanion data) {
    return ChatRelayInboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      senderKeyId: data.senderKeyId.present
          ? data.senderKeyId.value
          : this.senderKeyId,
      recipientKeyId: data.recipientKeyId.present
          ? data.recipientKeyId.value
          : this.recipientKeyId,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatRelayInboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('senderKeyId: $senderKeyId, ')
          ..write('recipientKeyId: $recipientKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    incidentId,
    senderKeyId,
    recipientKeyId,
    payload,
    state,
    receivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatRelayInboxData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.incidentId == this.incidentId &&
          other.senderKeyId == this.senderKeyId &&
          other.recipientKeyId == this.recipientKeyId &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.receivedAt == this.receivedAt);
}

class ChatRelayInboxCompanion extends UpdateCompanion<ChatRelayInboxData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> incidentId;
  final Value<String> senderKeyId;
  final Value<String> recipientKeyId;
  final Value<String> payload;
  final Value<String> state;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const ChatRelayInboxCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.senderKeyId = const Value.absent(),
    this.recipientKeyId = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatRelayInboxCompanion.insert({
    required String ownerId,
    required String messageId,
    required String incidentId,
    required String senderKeyId,
    required String recipientKeyId,
    required String payload,
    required String state,
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       incidentId = Value(incidentId),
       senderKeyId = Value(senderKeyId),
       recipientKeyId = Value(recipientKeyId),
       payload = Value(payload),
       state = Value(state),
       receivedAt = Value(receivedAt);
  static Insertable<ChatRelayInboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? incidentId,
    Expression<String>? senderKeyId,
    Expression<String>? recipientKeyId,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (senderKeyId != null) 'sender_key_id': senderKeyId,
      if (recipientKeyId != null) 'recipient_key_id': recipientKeyId,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatRelayInboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? incidentId,
    Value<String>? senderKeyId,
    Value<String>? recipientKeyId,
    Value<String>? payload,
    Value<String>? state,
    Value<DateTime>? receivedAt,
    Value<int>? rowid,
  }) {
    return ChatRelayInboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      incidentId: incidentId ?? this.incidentId,
      senderKeyId: senderKeyId ?? this.senderKeyId,
      recipientKeyId: recipientKeyId ?? this.recipientKeyId,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (senderKeyId.present) {
      map['sender_key_id'] = Variable<String>(senderKeyId.value);
    }
    if (recipientKeyId.present) {
      map['recipient_key_id'] = Variable<String>(recipientKeyId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatRelayInboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('senderKeyId: $senderKeyId, ')
          ..write('recipientKeyId: $recipientKeyId, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatReceiptsTable extends ChatReceipts
    with TableInfo<$ChatReceiptsTable, ChatReceiptData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatReceiptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _incidentIdMeta = const VerificationMeta(
    'incidentId',
  );
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
    'incident_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transferMeta = const VerificationMeta(
    'transfer',
  );
  @override
  late final GeneratedColumn<String> transfer = GeneratedColumn<String>(
    'transfer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousKeyIdMeta = const VerificationMeta(
    'previousKeyId',
  );
  @override
  late final GeneratedColumn<String> previousKeyId = GeneratedColumn<String>(
    'previous_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptMeta = const VerificationMeta(
    'receipt',
  );
  @override
  late final GeneratedColumn<String> receipt = GeneratedColumn<String>(
    'receipt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    incidentId,
    transfer,
    previousKeyId,
    receipt,
    state,
    receivedAt,
    expiresAt,
    retryCount,
    nextRetryAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatReceiptData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
        _incidentIdMeta,
        incidentId.isAcceptableOrUnknown(data['incident_id']!, _incidentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('transfer')) {
      context.handle(
        _transferMeta,
        transfer.isAcceptableOrUnknown(data['transfer']!, _transferMeta),
      );
    } else if (isInserting) {
      context.missing(_transferMeta);
    }
    if (data.containsKey('previous_key_id')) {
      context.handle(
        _previousKeyIdMeta,
        previousKeyId.isAcceptableOrUnknown(
          data['previous_key_id']!,
          _previousKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousKeyIdMeta);
    }
    if (data.containsKey('receipt')) {
      context.handle(
        _receiptMeta,
        receipt.isAcceptableOrUnknown(data['receipt']!, _receiptMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  ChatReceiptData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatReceiptData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      incidentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_id'],
      )!,
      transfer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer'],
      )!,
      previousKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_key_id'],
      )!,
      receipt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
    );
  }

  @override
  $ChatReceiptsTable createAlias(String alias) {
    return $ChatReceiptsTable(attachedDatabase, alias);
  }
}

class ChatReceiptData extends DataClass implements Insertable<ChatReceiptData> {
  final String ownerId;
  final String messageId;
  final String incidentId;
  final String transfer;
  final String previousKeyId;
  final String? receipt;
  final String state;
  final DateTime receivedAt;
  final DateTime expiresAt;
  final int retryCount;
  final DateTime? nextRetryAt;
  const ChatReceiptData({
    required this.ownerId,
    required this.messageId,
    required this.incidentId,
    required this.transfer,
    required this.previousKeyId,
    this.receipt,
    required this.state,
    required this.receivedAt,
    required this.expiresAt,
    required this.retryCount,
    this.nextRetryAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['incident_id'] = Variable<String>(incidentId);
    map['transfer'] = Variable<String>(transfer);
    map['previous_key_id'] = Variable<String>(previousKeyId);
    if (!nullToAbsent || receipt != null) {
      map['receipt'] = Variable<String>(receipt);
    }
    map['state'] = Variable<String>(state);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    return map;
  }

  ChatReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ChatReceiptsCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      incidentId: Value(incidentId),
      transfer: Value(transfer),
      previousKeyId: Value(previousKeyId),
      receipt: receipt == null && nullToAbsent
          ? const Value.absent()
          : Value(receipt),
      state: Value(state),
      receivedAt: Value(receivedAt),
      expiresAt: Value(expiresAt),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
    );
  }

  factory ChatReceiptData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatReceiptData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      transfer: serializer.fromJson<String>(json['transfer']),
      previousKeyId: serializer.fromJson<String>(json['previousKeyId']),
      receipt: serializer.fromJson<String?>(json['receipt']),
      state: serializer.fromJson<String>(json['state']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'incidentId': serializer.toJson<String>(incidentId),
      'transfer': serializer.toJson<String>(transfer),
      'previousKeyId': serializer.toJson<String>(previousKeyId),
      'receipt': serializer.toJson<String?>(receipt),
      'state': serializer.toJson<String>(state),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
    };
  }

  ChatReceiptData copyWith({
    String? ownerId,
    String? messageId,
    String? incidentId,
    String? transfer,
    String? previousKeyId,
    Value<String?> receipt = const Value.absent(),
    String? state,
    DateTime? receivedAt,
    DateTime? expiresAt,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
  }) => ChatReceiptData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    incidentId: incidentId ?? this.incidentId,
    transfer: transfer ?? this.transfer,
    previousKeyId: previousKeyId ?? this.previousKeyId,
    receipt: receipt.present ? receipt.value : this.receipt,
    state: state ?? this.state,
    receivedAt: receivedAt ?? this.receivedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
  );
  ChatReceiptData copyWithCompanion(ChatReceiptsCompanion data) {
    return ChatReceiptData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      incidentId: data.incidentId.present
          ? data.incidentId.value
          : this.incidentId,
      transfer: data.transfer.present ? data.transfer.value : this.transfer,
      previousKeyId: data.previousKeyId.present
          ? data.previousKeyId.value
          : this.previousKeyId,
      receipt: data.receipt.present ? data.receipt.value : this.receipt,
      state: data.state.present ? data.state.value : this.state,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatReceiptData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('transfer: $transfer, ')
          ..write('previousKeyId: $previousKeyId, ')
          ..write('receipt: $receipt, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    incidentId,
    transfer,
    previousKeyId,
    receipt,
    state,
    receivedAt,
    expiresAt,
    retryCount,
    nextRetryAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatReceiptData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.incidentId == this.incidentId &&
          other.transfer == this.transfer &&
          other.previousKeyId == this.previousKeyId &&
          other.receipt == this.receipt &&
          other.state == this.state &&
          other.receivedAt == this.receivedAt &&
          other.expiresAt == this.expiresAt &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt);
}

class ChatReceiptsCompanion extends UpdateCompanion<ChatReceiptData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> incidentId;
  final Value<String> transfer;
  final Value<String> previousKeyId;
  final Value<String?> receipt;
  final Value<String> state;
  final Value<DateTime> receivedAt;
  final Value<DateTime> expiresAt;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<int> rowid;
  const ChatReceiptsCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.transfer = const Value.absent(),
    this.previousKeyId = const Value.absent(),
    this.receipt = const Value.absent(),
    this.state = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatReceiptsCompanion.insert({
    required String ownerId,
    required String messageId,
    required String incidentId,
    required String transfer,
    required String previousKeyId,
    this.receipt = const Value.absent(),
    required String state,
    required DateTime receivedAt,
    required DateTime expiresAt,
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       messageId = Value(messageId),
       incidentId = Value(incidentId),
       transfer = Value(transfer),
       previousKeyId = Value(previousKeyId),
       state = Value(state),
       receivedAt = Value(receivedAt),
       expiresAt = Value(expiresAt);
  static Insertable<ChatReceiptData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? incidentId,
    Expression<String>? transfer,
    Expression<String>? previousKeyId,
    Expression<String>? receipt,
    Expression<String>? state,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (incidentId != null) 'incident_id': incidentId,
      if (transfer != null) 'transfer': transfer,
      if (previousKeyId != null) 'previous_key_id': previousKeyId,
      if (receipt != null) 'receipt': receipt,
      if (state != null) 'state': state,
      if (receivedAt != null) 'received_at': receivedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatReceiptsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? incidentId,
    Value<String>? transfer,
    Value<String>? previousKeyId,
    Value<String?>? receipt,
    Value<String>? state,
    Value<DateTime>? receivedAt,
    Value<DateTime>? expiresAt,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<int>? rowid,
  }) {
    return ChatReceiptsCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      incidentId: incidentId ?? this.incidentId,
      transfer: transfer ?? this.transfer,
      previousKeyId: previousKeyId ?? this.previousKeyId,
      receipt: receipt ?? this.receipt,
      state: state ?? this.state,
      receivedAt: receivedAt ?? this.receivedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (transfer.present) {
      map['transfer'] = Variable<String>(transfer.value);
    }
    if (previousKeyId.present) {
      map['previous_key_id'] = Variable<String>(previousKeyId.value);
    }
    if (receipt.present) {
      map['receipt'] = Variable<String>(receipt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatReceiptsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('incidentId: $incidentId, ')
          ..write('transfer: $transfer, ')
          ..write('previousKeyId: $previousKeyId, ')
          ..write('receipt: $receipt, ')
          ..write('state: $state, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
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
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $BleRelayMessagesTable bleRelayMessages = $BleRelayMessagesTable(
    this,
  );
  late final $BleRelayAttemptsTable bleRelayAttempts = $BleRelayAttemptsTable(
    this,
  );
  late final $BleRelayReceiptsTable bleRelayReceipts = $BleRelayReceiptsTable(
    this,
  );
  late final $RescueInboxTable rescueInbox = $RescueInboxTable(this);
  late final $RescueResponseOutboxTable rescueResponseOutbox =
      $RescueResponseOutboxTable(this);
  late final $RescueResponseInboxTable rescueResponseInbox =
      $RescueResponseInboxTable(this);
  late final $RescueResponseJobsTable rescueResponseJobs =
      $RescueResponseJobsTable(this);
  late final $RescueResponseReplayTable rescueResponseReplay =
      $RescueResponseReplayTable(this);
  late final $ChatRelayOutboxTable chatRelayOutbox = $ChatRelayOutboxTable(
    this,
  );
  late final $ChatRelayInboxTable chatRelayInbox = $ChatRelayInboxTable(this);
  late final $ChatReceiptsTable chatReceipts = $ChatReceiptsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sosMessages,
    sosSyncQueue,
    bleOutbox,
    bleInbox,
    chatMessages,
    bleRelayMessages,
    bleRelayAttempts,
    bleRelayReceipts,
    rescueInbox,
    rescueResponseOutbox,
    rescueResponseInbox,
    rescueResponseJobs,
    rescueResponseReplay,
    chatRelayOutbox,
    chatRelayInbox,
    chatReceipts,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ble_relay_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ble_relay_attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ble_relay_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ble_relay_receipts', kind: UpdateKind.delete)],
    ),
  ]);
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
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String messageId,
      required String sosId,
      required String ownerId,
      required String senderId,
      Value<String?> recipientId,
      required String messageType,
      Value<String?> textContent,
      required DateTime createdAt,
      required String deliveryStatus,
      Value<String?> attachmentPath,
      Value<String?> attachmentMimeType,
      Value<String?> attachmentName,
      Value<String?> remoteMessageId,
      Value<String?> transportMetadata,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> messageId,
      Value<String> sosId,
      Value<String> ownerId,
      Value<String> senderId,
      Value<String?> recipientId,
      Value<String> messageType,
      Value<String?> textContent,
      Value<DateTime> createdAt,
      Value<String> deliveryStatus,
      Value<String?> attachmentPath,
      Value<String?> attachmentMimeType,
      Value<String?> attachmentName,
      Value<String?> remoteMessageId,
      Value<String?> transportMetadata,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveryStatus => $composableBuilder(
    column: $table.deliveryStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentPath => $composableBuilder(
    column: $table.attachmentPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteMessageId => $composableBuilder(
    column: $table.remoteMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transportMetadata => $composableBuilder(
    column: $table.transportMetadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveryStatus => $composableBuilder(
    column: $table.deliveryStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentPath => $composableBuilder(
    column: $table.attachmentPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteMessageId => $composableBuilder(
    column: $table.remoteMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transportMetadata => $composableBuilder(
    column: $table.transportMetadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
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

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deliveryStatus => $composableBuilder(
    column: $table.deliveryStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentPath => $composableBuilder(
    column: $table.attachmentPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteMessageId => $composableBuilder(
    column: $table.remoteMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transportMetadata => $composableBuilder(
    column: $table.transportMetadata,
    builder: (column) => column,
  );
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> sosId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String?> recipientId = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> deliveryStatus = const Value.absent(),
                Value<String?> attachmentPath = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<String?> attachmentName = const Value.absent(),
                Value<String?> remoteMessageId = const Value.absent(),
                Value<String?> transportMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                messageId: messageId,
                sosId: sosId,
                ownerId: ownerId,
                senderId: senderId,
                recipientId: recipientId,
                messageType: messageType,
                textContent: textContent,
                createdAt: createdAt,
                deliveryStatus: deliveryStatus,
                attachmentPath: attachmentPath,
                attachmentMimeType: attachmentMimeType,
                attachmentName: attachmentName,
                remoteMessageId: remoteMessageId,
                transportMetadata: transportMetadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String sosId,
                required String ownerId,
                required String senderId,
                Value<String?> recipientId = const Value.absent(),
                required String messageType,
                Value<String?> textContent = const Value.absent(),
                required DateTime createdAt,
                required String deliveryStatus,
                Value<String?> attachmentPath = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<String?> attachmentName = const Value.absent(),
                Value<String?> remoteMessageId = const Value.absent(),
                Value<String?> transportMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                messageId: messageId,
                sosId: sosId,
                ownerId: ownerId,
                senderId: senderId,
                recipientId: recipientId,
                messageType: messageType,
                textContent: textContent,
                createdAt: createdAt,
                deliveryStatus: deliveryStatus,
                attachmentPath: attachmentPath,
                attachmentMimeType: attachmentMimeType,
                attachmentName: attachmentName,
                remoteMessageId: remoteMessageId,
                transportMetadata: transportMetadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatMessagesTable,
                    ChatMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;
typedef $$BleRelayMessagesTableCreateCompanionBuilder =
    BleRelayMessagesCompanion Function({
      required String originMessageId,
      required String incidentId,
      required String originKeyId,
      required String originPublicKey,
      required String immutablePayload,
      required String wireEnvelope,
      required String immutableDigest,
      required String originSignature,
      required String authorizationScope,
      required String emergencyType,
      required DateTime createdAt,
      required DateTime expiresAt,
      required DateTime retentionDeadline,
      required int maxHops,
      required int incomingHopCount,
      required String incomingPath,
      required String incomingPeerId,
      required String previousHopKeyId,
      required String processingState,
      required int payloadBytes,
      required int storageBytes,
      required DateTime receivedAt,
      required DateTime persistedAt,
      Value<String?> finalReceiptState,
      Value<String?> finalRecipientKeyId,
      Value<String?> finalAuthorizationId,
      Value<String?> finalReceiptCorrelationId,
      Value<String?> finalRoutePeerDeviceId,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$BleRelayMessagesTableUpdateCompanionBuilder =
    BleRelayMessagesCompanion Function({
      Value<String> originMessageId,
      Value<String> incidentId,
      Value<String> originKeyId,
      Value<String> originPublicKey,
      Value<String> immutablePayload,
      Value<String> wireEnvelope,
      Value<String> immutableDigest,
      Value<String> originSignature,
      Value<String> authorizationScope,
      Value<String> emergencyType,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<DateTime> retentionDeadline,
      Value<int> maxHops,
      Value<int> incomingHopCount,
      Value<String> incomingPath,
      Value<String> incomingPeerId,
      Value<String> previousHopKeyId,
      Value<String> processingState,
      Value<int> payloadBytes,
      Value<int> storageBytes,
      Value<DateTime> receivedAt,
      Value<DateTime> persistedAt,
      Value<String?> finalReceiptState,
      Value<String?> finalRecipientKeyId,
      Value<String?> finalAuthorizationId,
      Value<String?> finalReceiptCorrelationId,
      Value<String?> finalRoutePeerDeviceId,
      Value<String?> lastError,
      Value<int> rowid,
    });

final class $$BleRelayMessagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $BleRelayMessagesTable, BleRelayMessage> {
  $$BleRelayMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$BleRelayAttemptsTable, List<BleRelayAttempt>>
  _bleRelayAttemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bleRelayAttempts,
    aliasName: 'ble_relay_messages__origin_message_id__ble_relay_attempts__origin_message_id',
  );

  $$BleRelayAttemptsTableProcessedTableManager get bleRelayAttemptsRefs {
    final manager =
        $$BleRelayAttemptsTableTableManager($_db, $_db.bleRelayAttempts).filter(
          (f) => f.originMessageId.originMessageId.sqlEquals(
            $_itemColumn<String>('origin_message_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _bleRelayAttemptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BleRelayReceiptsTable, List<BleRelayReceipt>>
  _bleRelayReceiptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bleRelayReceipts,
    aliasName: 'ble_relay_messages__origin_message_id__ble_relay_receipts__origin_message_id',
  );

  $$BleRelayReceiptsTableProcessedTableManager get bleRelayReceiptsRefs {
    final manager =
        $$BleRelayReceiptsTableTableManager($_db, $_db.bleRelayReceipts).filter(
          (f) => f.originMessageId.originMessageId.sqlEquals(
            $_itemColumn<String>('origin_message_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _bleRelayReceiptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BleRelayMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $BleRelayMessagesTable> {
  $$BleRelayMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originPublicKey => $composableBuilder(
    column: $table.originPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutablePayload => $composableBuilder(
    column: $table.immutablePayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wireEnvelope => $composableBuilder(
    column: $table.wireEnvelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originSignature => $composableBuilder(
    column: $table.originSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorizationScope => $composableBuilder(
    column: $table.authorizationScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get retentionDeadline => $composableBuilder(
    column: $table.retentionDeadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxHops => $composableBuilder(
    column: $table.maxHops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomingPeerId => $composableBuilder(
    column: $table.incomingPeerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
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

  ColumnFilters<String> get finalReceiptState => $composableBuilder(
    column: $table.finalReceiptState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalRecipientKeyId => $composableBuilder(
    column: $table.finalRecipientKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalReceiptCorrelationId => $composableBuilder(
    column: $table.finalReceiptCorrelationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalRoutePeerDeviceId => $composableBuilder(
    column: $table.finalRoutePeerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bleRelayAttemptsRefs(
    Expression<bool> Function($$BleRelayAttemptsTableFilterComposer f) f,
  ) {
    final $$BleRelayAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayAttempts,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.bleRelayAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bleRelayReceiptsRefs(
    Expression<bool> Function($$BleRelayReceiptsTableFilterComposer f) f,
  ) {
    final $$BleRelayReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayReceipts,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.bleRelayReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BleRelayMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $BleRelayMessagesTable> {
  $$BleRelayMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originPublicKey => $composableBuilder(
    column: $table.originPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutablePayload => $composableBuilder(
    column: $table.immutablePayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wireEnvelope => $composableBuilder(
    column: $table.wireEnvelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originSignature => $composableBuilder(
    column: $table.originSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorizationScope => $composableBuilder(
    column: $table.authorizationScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get retentionDeadline => $composableBuilder(
    column: $table.retentionDeadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxHops => $composableBuilder(
    column: $table.maxHops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomingPeerId => $composableBuilder(
    column: $table.incomingPeerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
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

  ColumnOrderings<String> get finalReceiptState => $composableBuilder(
    column: $table.finalReceiptState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalRecipientKeyId => $composableBuilder(
    column: $table.finalRecipientKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalReceiptCorrelationId => $composableBuilder(
    column: $table.finalReceiptCorrelationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalRoutePeerDeviceId => $composableBuilder(
    column: $table.finalRoutePeerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BleRelayMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleRelayMessagesTable> {
  $$BleRelayMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originPublicKey => $composableBuilder(
    column: $table.originPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immutablePayload => $composableBuilder(
    column: $table.immutablePayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wireEnvelope => $composableBuilder(
    column: $table.wireEnvelope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originSignature => $composableBuilder(
    column: $table.originSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorizationScope => $composableBuilder(
    column: $table.authorizationScope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get retentionDeadline => $composableBuilder(
    column: $table.retentionDeadline,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxHops =>
      $composableBuilder(column: $table.maxHops, builder: (column) => column);

  GeneratedColumn<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incomingPeerId => $composableBuilder(
    column: $table.incomingPeerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
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

  GeneratedColumn<String> get finalReceiptState => $composableBuilder(
    column: $table.finalReceiptState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalRecipientKeyId => $composableBuilder(
    column: $table.finalRecipientKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalReceiptCorrelationId => $composableBuilder(
    column: $table.finalReceiptCorrelationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalRoutePeerDeviceId => $composableBuilder(
    column: $table.finalRoutePeerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  Expression<T> bleRelayAttemptsRefs<T extends Object>(
    Expression<T> Function($$BleRelayAttemptsTableAnnotationComposer a) f,
  ) {
    final $$BleRelayAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayAttempts,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.bleRelayAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bleRelayReceiptsRefs<T extends Object>(
    Expression<T> Function($$BleRelayReceiptsTableAnnotationComposer a) f,
  ) {
    final $$BleRelayReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayReceipts,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.bleRelayReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BleRelayMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleRelayMessagesTable,
          BleRelayMessage,
          $$BleRelayMessagesTableFilterComposer,
          $$BleRelayMessagesTableOrderingComposer,
          $$BleRelayMessagesTableAnnotationComposer,
          $$BleRelayMessagesTableCreateCompanionBuilder,
          $$BleRelayMessagesTableUpdateCompanionBuilder,
          (BleRelayMessage, $$BleRelayMessagesTableReferences),
          BleRelayMessage,
          PrefetchHooks Function({
            bool bleRelayAttemptsRefs,
            bool bleRelayReceiptsRefs,
          })
        > {
  $$BleRelayMessagesTableTableManager(
    _$AppDatabase db,
    $BleRelayMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleRelayMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleRelayMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleRelayMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> originMessageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> originKeyId = const Value.absent(),
                Value<String> originPublicKey = const Value.absent(),
                Value<String> immutablePayload = const Value.absent(),
                Value<String> wireEnvelope = const Value.absent(),
                Value<String> immutableDigest = const Value.absent(),
                Value<String> originSignature = const Value.absent(),
                Value<String> authorizationScope = const Value.absent(),
                Value<String> emergencyType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> retentionDeadline = const Value.absent(),
                Value<int> maxHops = const Value.absent(),
                Value<int> incomingHopCount = const Value.absent(),
                Value<String> incomingPath = const Value.absent(),
                Value<String> incomingPeerId = const Value.absent(),
                Value<String> previousHopKeyId = const Value.absent(),
                Value<String> processingState = const Value.absent(),
                Value<int> payloadBytes = const Value.absent(),
                Value<int> storageBytes = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<DateTime> persistedAt = const Value.absent(),
                Value<String?> finalReceiptState = const Value.absent(),
                Value<String?> finalRecipientKeyId = const Value.absent(),
                Value<String?> finalAuthorizationId = const Value.absent(),
                Value<String?> finalReceiptCorrelationId = const Value.absent(),
                Value<String?> finalRoutePeerDeviceId = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleRelayMessagesCompanion(
                originMessageId: originMessageId,
                incidentId: incidentId,
                originKeyId: originKeyId,
                originPublicKey: originPublicKey,
                immutablePayload: immutablePayload,
                wireEnvelope: wireEnvelope,
                immutableDigest: immutableDigest,
                originSignature: originSignature,
                authorizationScope: authorizationScope,
                emergencyType: emergencyType,
                createdAt: createdAt,
                expiresAt: expiresAt,
                retentionDeadline: retentionDeadline,
                maxHops: maxHops,
                incomingHopCount: incomingHopCount,
                incomingPath: incomingPath,
                incomingPeerId: incomingPeerId,
                previousHopKeyId: previousHopKeyId,
                processingState: processingState,
                payloadBytes: payloadBytes,
                storageBytes: storageBytes,
                receivedAt: receivedAt,
                persistedAt: persistedAt,
                finalReceiptState: finalReceiptState,
                finalRecipientKeyId: finalRecipientKeyId,
                finalAuthorizationId: finalAuthorizationId,
                finalReceiptCorrelationId: finalReceiptCorrelationId,
                finalRoutePeerDeviceId: finalRoutePeerDeviceId,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String originMessageId,
                required String incidentId,
                required String originKeyId,
                required String originPublicKey,
                required String immutablePayload,
                required String wireEnvelope,
                required String immutableDigest,
                required String originSignature,
                required String authorizationScope,
                required String emergencyType,
                required DateTime createdAt,
                required DateTime expiresAt,
                required DateTime retentionDeadline,
                required int maxHops,
                required int incomingHopCount,
                required String incomingPath,
                required String incomingPeerId,
                required String previousHopKeyId,
                required String processingState,
                required int payloadBytes,
                required int storageBytes,
                required DateTime receivedAt,
                required DateTime persistedAt,
                Value<String?> finalReceiptState = const Value.absent(),
                Value<String?> finalRecipientKeyId = const Value.absent(),
                Value<String?> finalAuthorizationId = const Value.absent(),
                Value<String?> finalReceiptCorrelationId = const Value.absent(),
                Value<String?> finalRoutePeerDeviceId = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleRelayMessagesCompanion.insert(
                originMessageId: originMessageId,
                incidentId: incidentId,
                originKeyId: originKeyId,
                originPublicKey: originPublicKey,
                immutablePayload: immutablePayload,
                wireEnvelope: wireEnvelope,
                immutableDigest: immutableDigest,
                originSignature: originSignature,
                authorizationScope: authorizationScope,
                emergencyType: emergencyType,
                createdAt: createdAt,
                expiresAt: expiresAt,
                retentionDeadline: retentionDeadline,
                maxHops: maxHops,
                incomingHopCount: incomingHopCount,
                incomingPath: incomingPath,
                incomingPeerId: incomingPeerId,
                previousHopKeyId: previousHopKeyId,
                processingState: processingState,
                payloadBytes: payloadBytes,
                storageBytes: storageBytes,
                receivedAt: receivedAt,
                persistedAt: persistedAt,
                finalReceiptState: finalReceiptState,
                finalRecipientKeyId: finalRecipientKeyId,
                finalAuthorizationId: finalAuthorizationId,
                finalReceiptCorrelationId: finalReceiptCorrelationId,
                finalRoutePeerDeviceId: finalRoutePeerDeviceId,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BleRelayMessagesTable, BleRelayMessage>(table),
                  $$BleRelayMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bleRelayAttemptsRefs = false, bleRelayReceiptsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bleRelayAttemptsRefs) db.bleRelayAttempts,
                    if (bleRelayReceiptsRefs) db.bleRelayReceipts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bleRelayAttemptsRefs)
                        await $_getPrefetchedData<
                          BleRelayMessage,
                          $BleRelayMessagesTable,
                          BleRelayAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$BleRelayMessagesTableReferences
                              ._bleRelayAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BleRelayMessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).bleRelayAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) =>
                                    e.originMessageId == item.originMessageId,
                              ),
                          typedResults: items,
                        ),
                      if (bleRelayReceiptsRefs)
                        await $_getPrefetchedData<
                          BleRelayMessage,
                          $BleRelayMessagesTable,
                          BleRelayReceipt
                        >(
                          currentTable: table,
                          referencedTable: $$BleRelayMessagesTableReferences
                              ._bleRelayReceiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BleRelayMessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).bleRelayReceiptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) =>
                                    e.originMessageId == item.originMessageId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BleRelayMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleRelayMessagesTable,
      BleRelayMessage,
      $$BleRelayMessagesTableFilterComposer,
      $$BleRelayMessagesTableOrderingComposer,
      $$BleRelayMessagesTableAnnotationComposer,
      $$BleRelayMessagesTableCreateCompanionBuilder,
      $$BleRelayMessagesTableUpdateCompanionBuilder,
      (BleRelayMessage, $$BleRelayMessagesTableReferences),
      BleRelayMessage,
      PrefetchHooks Function({
        bool bleRelayAttemptsRefs,
        bool bleRelayReceiptsRefs,
      })
    >;
typedef $$BleRelayAttemptsTableCreateCompanionBuilder =
    BleRelayAttemptsCompanion Function({
      required String originMessageId,
      required String nextHopKeyId,
      required String attemptId,
      required String correlationId,
      required String nextHopDeviceId,
      required int outgoingHopCount,
      required String outgoingPath,
      required int storageBytes,
      required String state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> acceptedAt,
      Value<int> rowid,
    });
typedef $$BleRelayAttemptsTableUpdateCompanionBuilder =
    BleRelayAttemptsCompanion Function({
      Value<String> originMessageId,
      Value<String> nextHopKeyId,
      Value<String> attemptId,
      Value<String> correlationId,
      Value<String> nextHopDeviceId,
      Value<int> outgoingHopCount,
      Value<String> outgoingPath,
      Value<int> storageBytes,
      Value<String> state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> acceptedAt,
      Value<int> rowid,
    });

final class $$BleRelayAttemptsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BleRelayAttemptsTable, BleRelayAttempt> {
  $$BleRelayAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BleRelayMessagesTable _originMessageIdTable(_$AppDatabase db) =>
      db.bleRelayMessages.createAlias(
        'ble_relay_attempts__origin_message_id__ble_relay_messages__origin_message_id',
      );

  $$BleRelayMessagesTableProcessedTableManager get originMessageId {
    final $_column = $_itemColumn<String>('origin_message_id')!;

    final manager = $$BleRelayMessagesTableTableManager(
      $_db,
      $_db.bleRelayMessages,
    ).filter((f) => f.originMessageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_originMessageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BleRelayAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $BleRelayAttemptsTable> {
  $$BleRelayAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outgoingHopCount => $composableBuilder(
    column: $table.outgoingHopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outgoingPath => $composableBuilder(
    column: $table.outgoingPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
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

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BleRelayMessagesTableFilterComposer get originMessageId {
    final $$BleRelayMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableFilterComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $BleRelayAttemptsTable> {
  $$BleRelayAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outgoingHopCount => $composableBuilder(
    column: $table.outgoingHopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outgoingPath => $composableBuilder(
    column: $table.outgoingPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
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

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BleRelayMessagesTableOrderingComposer get originMessageId {
    final $$BleRelayMessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableOrderingComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleRelayAttemptsTable> {
  $$BleRelayAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outgoingHopCount => $composableBuilder(
    column: $table.outgoingHopCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outgoingPath => $composableBuilder(
    column: $table.outgoingPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
    builder: (column) => column,
  );

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

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );

  $$BleRelayMessagesTableAnnotationComposer get originMessageId {
    final $$BleRelayMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleRelayAttemptsTable,
          BleRelayAttempt,
          $$BleRelayAttemptsTableFilterComposer,
          $$BleRelayAttemptsTableOrderingComposer,
          $$BleRelayAttemptsTableAnnotationComposer,
          $$BleRelayAttemptsTableCreateCompanionBuilder,
          $$BleRelayAttemptsTableUpdateCompanionBuilder,
          (BleRelayAttempt, $$BleRelayAttemptsTableReferences),
          BleRelayAttempt,
          PrefetchHooks Function({bool originMessageId})
        > {
  $$BleRelayAttemptsTableTableManager(
    _$AppDatabase db,
    $BleRelayAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleRelayAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleRelayAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleRelayAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> originMessageId = const Value.absent(),
                Value<String> nextHopKeyId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<String> correlationId = const Value.absent(),
                Value<String> nextHopDeviceId = const Value.absent(),
                Value<int> outgoingHopCount = const Value.absent(),
                Value<String> outgoingPath = const Value.absent(),
                Value<int> storageBytes = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleRelayAttemptsCompanion(
                originMessageId: originMessageId,
                nextHopKeyId: nextHopKeyId,
                attemptId: attemptId,
                correlationId: correlationId,
                nextHopDeviceId: nextHopDeviceId,
                outgoingHopCount: outgoingHopCount,
                outgoingPath: outgoingPath,
                storageBytes: storageBytes,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String originMessageId,
                required String nextHopKeyId,
                required String attemptId,
                required String correlationId,
                required String nextHopDeviceId,
                required int outgoingHopCount,
                required String outgoingPath,
                required int storageBytes,
                required String state,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleRelayAttemptsCompanion.insert(
                originMessageId: originMessageId,
                nextHopKeyId: nextHopKeyId,
                attemptId: attemptId,
                correlationId: correlationId,
                nextHopDeviceId: nextHopDeviceId,
                outgoingHopCount: outgoingHopCount,
                outgoingPath: outgoingPath,
                storageBytes: storageBytes,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BleRelayAttemptsTable, BleRelayAttempt>(table),
                  $$BleRelayAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({originMessageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (originMessageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.originMessageId,
                        referencedTable: $$BleRelayAttemptsTableReferences
                            ._originMessageIdTable(db),
                        referencedColumn: $$BleRelayAttemptsTableReferences
                            ._originMessageIdTable(db)
                            .originMessageId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BleRelayAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleRelayAttemptsTable,
      BleRelayAttempt,
      $$BleRelayAttemptsTableFilterComposer,
      $$BleRelayAttemptsTableOrderingComposer,
      $$BleRelayAttemptsTableAnnotationComposer,
      $$BleRelayAttemptsTableCreateCompanionBuilder,
      $$BleRelayAttemptsTableUpdateCompanionBuilder,
      (BleRelayAttempt, $$BleRelayAttemptsTableReferences),
      BleRelayAttempt,
      PrefetchHooks Function({bool originMessageId})
    >;
typedef $$BleRelayReceiptsTableCreateCompanionBuilder =
    BleRelayReceiptsCompanion Function({
      required String semanticKey,
      required String receiptId,
      required String receiptType,
      required String originMessageId,
      required String incidentId,
      required String immutableDigest,
      required String signerKeyId,
      required String signerPublicKey,
      required String correlationId,
      Value<String?> attemptId,
      Value<String?> finalAuthorizationId,
      required String sourcePeerDeviceId,
      Value<String?> previousHopKeyId,
      Value<String?> previousHopDeviceId,
      required String payload,
      required String signature,
      required int storageBytes,
      required String state,
      required DateTime createdAt,
      required DateTime expiresAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BleRelayReceiptsTableUpdateCompanionBuilder =
    BleRelayReceiptsCompanion Function({
      Value<String> semanticKey,
      Value<String> receiptId,
      Value<String> receiptType,
      Value<String> originMessageId,
      Value<String> incidentId,
      Value<String> immutableDigest,
      Value<String> signerKeyId,
      Value<String> signerPublicKey,
      Value<String> correlationId,
      Value<String?> attemptId,
      Value<String?> finalAuthorizationId,
      Value<String> sourcePeerDeviceId,
      Value<String?> previousHopKeyId,
      Value<String?> previousHopDeviceId,
      Value<String> payload,
      Value<String> signature,
      Value<int> storageBytes,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$BleRelayReceiptsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BleRelayReceiptsTable, BleRelayReceipt> {
  $$BleRelayReceiptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BleRelayMessagesTable _originMessageIdTable(_$AppDatabase db) =>
      db.bleRelayMessages.createAlias(
        'ble_relay_receipts__origin_message_id__ble_relay_messages__origin_message_id',
      );

  $$BleRelayMessagesTableProcessedTableManager get originMessageId {
    final $_column = $_itemColumn<String>('origin_message_id')!;

    final manager = $$BleRelayMessagesTableTableManager(
      $_db,
      $_db.bleRelayMessages,
    ).filter((f) => f.originMessageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_originMessageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BleRelayReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $BleRelayReceiptsTable> {
  $$BleRelayReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptType => $composableBuilder(
    column: $table.receiptType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerKeyId => $composableBuilder(
    column: $table.signerKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerPublicKey => $composableBuilder(
    column: $table.signerPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePeerDeviceId => $composableBuilder(
    column: $table.sourcePeerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousHopDeviceId => $composableBuilder(
    column: $table.previousHopDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BleRelayMessagesTableFilterComposer get originMessageId {
    final $$BleRelayMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableFilterComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $BleRelayReceiptsTable> {
  $$BleRelayReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptType => $composableBuilder(
    column: $table.receiptType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerKeyId => $composableBuilder(
    column: $table.signerKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerPublicKey => $composableBuilder(
    column: $table.signerPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePeerDeviceId => $composableBuilder(
    column: $table.sourcePeerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousHopDeviceId => $composableBuilder(
    column: $table.previousHopDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BleRelayMessagesTableOrderingComposer get originMessageId {
    final $$BleRelayMessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableOrderingComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleRelayReceiptsTable> {
  $$BleRelayReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptId =>
      $composableBuilder(column: $table.receiptId, builder: (column) => column);

  GeneratedColumn<String> get receiptType => $composableBuilder(
    column: $table.receiptType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerKeyId => $composableBuilder(
    column: $table.signerKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerPublicKey => $composableBuilder(
    column: $table.signerPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get correlationId => $composableBuilder(
    column: $table.correlationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get finalAuthorizationId => $composableBuilder(
    column: $table.finalAuthorizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePeerDeviceId => $composableBuilder(
    column: $table.sourcePeerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousHopKeyId => $composableBuilder(
    column: $table.previousHopKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousHopDeviceId => $composableBuilder(
    column: $table.previousHopDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<int> get storageBytes => $composableBuilder(
    column: $table.storageBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BleRelayMessagesTableAnnotationComposer get originMessageId {
    final $$BleRelayMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originMessageId,
      referencedTable: $db.bleRelayMessages,
      getReferencedColumn: (t) => t.originMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BleRelayMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.bleRelayMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BleRelayReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleRelayReceiptsTable,
          BleRelayReceipt,
          $$BleRelayReceiptsTableFilterComposer,
          $$BleRelayReceiptsTableOrderingComposer,
          $$BleRelayReceiptsTableAnnotationComposer,
          $$BleRelayReceiptsTableCreateCompanionBuilder,
          $$BleRelayReceiptsTableUpdateCompanionBuilder,
          (BleRelayReceipt, $$BleRelayReceiptsTableReferences),
          BleRelayReceipt,
          PrefetchHooks Function({bool originMessageId})
        > {
  $$BleRelayReceiptsTableTableManager(
    _$AppDatabase db,
    $BleRelayReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleRelayReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleRelayReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleRelayReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> semanticKey = const Value.absent(),
                Value<String> receiptId = const Value.absent(),
                Value<String> receiptType = const Value.absent(),
                Value<String> originMessageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> immutableDigest = const Value.absent(),
                Value<String> signerKeyId = const Value.absent(),
                Value<String> signerPublicKey = const Value.absent(),
                Value<String> correlationId = const Value.absent(),
                Value<String?> attemptId = const Value.absent(),
                Value<String?> finalAuthorizationId = const Value.absent(),
                Value<String> sourcePeerDeviceId = const Value.absent(),
                Value<String?> previousHopKeyId = const Value.absent(),
                Value<String?> previousHopDeviceId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> storageBytes = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleRelayReceiptsCompanion(
                semanticKey: semanticKey,
                receiptId: receiptId,
                receiptType: receiptType,
                originMessageId: originMessageId,
                incidentId: incidentId,
                immutableDigest: immutableDigest,
                signerKeyId: signerKeyId,
                signerPublicKey: signerPublicKey,
                correlationId: correlationId,
                attemptId: attemptId,
                finalAuthorizationId: finalAuthorizationId,
                sourcePeerDeviceId: sourcePeerDeviceId,
                previousHopKeyId: previousHopKeyId,
                previousHopDeviceId: previousHopDeviceId,
                payload: payload,
                signature: signature,
                storageBytes: storageBytes,
                state: state,
                createdAt: createdAt,
                expiresAt: expiresAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String semanticKey,
                required String receiptId,
                required String receiptType,
                required String originMessageId,
                required String incidentId,
                required String immutableDigest,
                required String signerKeyId,
                required String signerPublicKey,
                required String correlationId,
                Value<String?> attemptId = const Value.absent(),
                Value<String?> finalAuthorizationId = const Value.absent(),
                required String sourcePeerDeviceId,
                Value<String?> previousHopKeyId = const Value.absent(),
                Value<String?> previousHopDeviceId = const Value.absent(),
                required String payload,
                required String signature,
                required int storageBytes,
                required String state,
                required DateTime createdAt,
                required DateTime expiresAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BleRelayReceiptsCompanion.insert(
                semanticKey: semanticKey,
                receiptId: receiptId,
                receiptType: receiptType,
                originMessageId: originMessageId,
                incidentId: incidentId,
                immutableDigest: immutableDigest,
                signerKeyId: signerKeyId,
                signerPublicKey: signerPublicKey,
                correlationId: correlationId,
                attemptId: attemptId,
                finalAuthorizationId: finalAuthorizationId,
                sourcePeerDeviceId: sourcePeerDeviceId,
                previousHopKeyId: previousHopKeyId,
                previousHopDeviceId: previousHopDeviceId,
                payload: payload,
                signature: signature,
                storageBytes: storageBytes,
                state: state,
                createdAt: createdAt,
                expiresAt: expiresAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BleRelayReceiptsTable, BleRelayReceipt>(table),
                  $$BleRelayReceiptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({originMessageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (originMessageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.originMessageId,
                        referencedTable: $$BleRelayReceiptsTableReferences
                            ._originMessageIdTable(db),
                        referencedColumn: $$BleRelayReceiptsTableReferences
                            ._originMessageIdTable(db)
                            .originMessageId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BleRelayReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleRelayReceiptsTable,
      BleRelayReceipt,
      $$BleRelayReceiptsTableFilterComposer,
      $$BleRelayReceiptsTableOrderingComposer,
      $$BleRelayReceiptsTableAnnotationComposer,
      $$BleRelayReceiptsTableCreateCompanionBuilder,
      $$BleRelayReceiptsTableUpdateCompanionBuilder,
      (BleRelayReceipt, $$BleRelayReceiptsTableReferences),
      BleRelayReceipt,
      PrefetchHooks Function({bool originMessageId})
    >;
typedef $$RescueInboxTableCreateCompanionBuilder =
    RescueInboxCompanion Function({
      required String ownerId,
      required String originMessageId,
      required String incidentId,
      required String originKeyId,
      required String immutableDigest,
      required String emergencyType,
      required String emergencyMessage,
      required bool includeLocation,
      Value<double?> latitude,
      Value<double?> longitude,
      required int incomingHopCount,
      required String incomingPath,
      required DateTime createdAt,
      required DateTime expiresAt,
      required DateTime receivedAt,
      required String state,
      Value<String?> acceptanceId,
      Value<DateTime?> acceptedAt,
      Value<int> rowid,
    });
typedef $$RescueInboxTableUpdateCompanionBuilder =
    RescueInboxCompanion Function({
      Value<String> ownerId,
      Value<String> originMessageId,
      Value<String> incidentId,
      Value<String> originKeyId,
      Value<String> immutableDigest,
      Value<String> emergencyType,
      Value<String> emergencyMessage,
      Value<bool> includeLocation,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int> incomingHopCount,
      Value<String> incomingPath,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<DateTime> receivedAt,
      Value<String> state,
      Value<String?> acceptanceId,
      Value<DateTime?> acceptedAt,
      Value<int> rowid,
    });

class $$RescueInboxTableFilterComposer
    extends Composer<_$AppDatabase, $RescueInboxTable> {
  $$RescueInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emergencyMessage => $composableBuilder(
    column: $table.emergencyMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeLocation => $composableBuilder(
    column: $table.includeLocation,
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

  ColumnFilters<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptanceId => $composableBuilder(
    column: $table.acceptanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RescueInboxTableOrderingComposer
    extends Composer<_$AppDatabase, $RescueInboxTable> {
  $$RescueInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emergencyMessage => $composableBuilder(
    column: $table.emergencyMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeLocation => $composableBuilder(
    column: $table.includeLocation,
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

  ColumnOrderings<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptanceId => $composableBuilder(
    column: $table.acceptanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RescueInboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $RescueInboxTable> {
  $$RescueInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emergencyType => $composableBuilder(
    column: $table.emergencyType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emergencyMessage => $composableBuilder(
    column: $table.emergencyMessage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeLocation => $composableBuilder(
    column: $table.includeLocation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get incomingHopCount => $composableBuilder(
    column: $table.incomingHopCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incomingPath => $composableBuilder(
    column: $table.incomingPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get acceptanceId => $composableBuilder(
    column: $table.acceptanceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );
}

class $$RescueInboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RescueInboxTable,
          RescueInboxData,
          $$RescueInboxTableFilterComposer,
          $$RescueInboxTableOrderingComposer,
          $$RescueInboxTableAnnotationComposer,
          $$RescueInboxTableCreateCompanionBuilder,
          $$RescueInboxTableUpdateCompanionBuilder,
          (
            RescueInboxData,
            BaseReferences<_$AppDatabase, $RescueInboxTable, RescueInboxData>,
          ),
          RescueInboxData,
          PrefetchHooks Function()
        > {
  $$RescueInboxTableTableManager(_$AppDatabase db, $RescueInboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RescueInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RescueInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RescueInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> originMessageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> originKeyId = const Value.absent(),
                Value<String> immutableDigest = const Value.absent(),
                Value<String> emergencyType = const Value.absent(),
                Value<String> emergencyMessage = const Value.absent(),
                Value<bool> includeLocation = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> incomingHopCount = const Value.absent(),
                Value<String> incomingPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> acceptanceId = const Value.absent(),
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueInboxCompanion(
                ownerId: ownerId,
                originMessageId: originMessageId,
                incidentId: incidentId,
                originKeyId: originKeyId,
                immutableDigest: immutableDigest,
                emergencyType: emergencyType,
                emergencyMessage: emergencyMessage,
                includeLocation: includeLocation,
                latitude: latitude,
                longitude: longitude,
                incomingHopCount: incomingHopCount,
                incomingPath: incomingPath,
                createdAt: createdAt,
                expiresAt: expiresAt,
                receivedAt: receivedAt,
                state: state,
                acceptanceId: acceptanceId,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String originMessageId,
                required String incidentId,
                required String originKeyId,
                required String immutableDigest,
                required String emergencyType,
                required String emergencyMessage,
                required bool includeLocation,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required int incomingHopCount,
                required String incomingPath,
                required DateTime createdAt,
                required DateTime expiresAt,
                required DateTime receivedAt,
                required String state,
                Value<String?> acceptanceId = const Value.absent(),
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueInboxCompanion.insert(
                ownerId: ownerId,
                originMessageId: originMessageId,
                incidentId: incidentId,
                originKeyId: originKeyId,
                immutableDigest: immutableDigest,
                emergencyType: emergencyType,
                emergencyMessage: emergencyMessage,
                includeLocation: includeLocation,
                latitude: latitude,
                longitude: longitude,
                incomingHopCount: incomingHopCount,
                incomingPath: incomingPath,
                createdAt: createdAt,
                expiresAt: expiresAt,
                receivedAt: receivedAt,
                state: state,
                acceptanceId: acceptanceId,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RescueInboxTable, RescueInboxData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RescueInboxTable,
                    RescueInboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RescueInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RescueInboxTable,
      RescueInboxData,
      $$RescueInboxTableFilterComposer,
      $$RescueInboxTableOrderingComposer,
      $$RescueInboxTableAnnotationComposer,
      $$RescueInboxTableCreateCompanionBuilder,
      $$RescueInboxTableUpdateCompanionBuilder,
      (
        RescueInboxData,
        BaseReferences<_$AppDatabase, $RescueInboxTable, RescueInboxData>,
      ),
      RescueInboxData,
      PrefetchHooks Function()
    >;
typedef $$RescueResponseOutboxTableCreateCompanionBuilder =
    RescueResponseOutboxCompanion Function({
      required String ownerId,
      required String messageId,
      required String incidentId,
      required String originMessageId,
      required String originKeyId,
      required String responderKeyId,
      required String payload,
      required String state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      required DateTime expiresAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> finalAckAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$RescueResponseOutboxTableUpdateCompanionBuilder =
    RescueResponseOutboxCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> incidentId,
      Value<String> originMessageId,
      Value<String> originKeyId,
      Value<String> responderKeyId,
      Value<String> payload,
      Value<String> state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> expiresAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> finalAckAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$RescueResponseOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $RescueResponseOutboxTable> {
  $$RescueResponseOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
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

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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

  ColumnFilters<DateTime> get finalAckAt => $composableBuilder(
    column: $table.finalAckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RescueResponseOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $RescueResponseOutboxTable> {
  $$RescueResponseOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
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

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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

  ColumnOrderings<DateTime> get finalAckAt => $composableBuilder(
    column: $table.finalAckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RescueResponseOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $RescueResponseOutboxTable> {
  $$RescueResponseOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originKeyId => $composableBuilder(
    column: $table.originKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
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

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finalAckAt => $composableBuilder(
    column: $table.finalAckAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$RescueResponseOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RescueResponseOutboxTable,
          RescueResponseOutboxData,
          $$RescueResponseOutboxTableFilterComposer,
          $$RescueResponseOutboxTableOrderingComposer,
          $$RescueResponseOutboxTableAnnotationComposer,
          $$RescueResponseOutboxTableCreateCompanionBuilder,
          $$RescueResponseOutboxTableUpdateCompanionBuilder,
          (
            RescueResponseOutboxData,
            BaseReferences<
              _$AppDatabase,
              $RescueResponseOutboxTable,
              RescueResponseOutboxData
            >,
          ),
          RescueResponseOutboxData,
          PrefetchHooks Function()
        > {
  $$RescueResponseOutboxTableTableManager(
    _$AppDatabase db,
    $RescueResponseOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RescueResponseOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RescueResponseOutboxTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RescueResponseOutboxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> originMessageId = const Value.absent(),
                Value<String> originKeyId = const Value.absent(),
                Value<String> responderKeyId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> finalAckAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseOutboxCompanion(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                originMessageId: originMessageId,
                originKeyId: originKeyId,
                responderKeyId: responderKeyId,
                payload: payload,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                finalAckAt: finalAckAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String incidentId,
                required String originMessageId,
                required String originKeyId,
                required String responderKeyId,
                required String payload,
                required String state,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                required DateTime expiresAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> finalAckAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseOutboxCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                originMessageId: originMessageId,
                originKeyId: originKeyId,
                responderKeyId: responderKeyId,
                payload: payload,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                finalAckAt: finalAckAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RescueResponseOutboxTable,
                    RescueResponseOutboxData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RescueResponseOutboxTable,
                    RescueResponseOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RescueResponseOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RescueResponseOutboxTable,
      RescueResponseOutboxData,
      $$RescueResponseOutboxTableFilterComposer,
      $$RescueResponseOutboxTableOrderingComposer,
      $$RescueResponseOutboxTableAnnotationComposer,
      $$RescueResponseOutboxTableCreateCompanionBuilder,
      $$RescueResponseOutboxTableUpdateCompanionBuilder,
      (
        RescueResponseOutboxData,
        BaseReferences<
          _$AppDatabase,
          $RescueResponseOutboxTable,
          RescueResponseOutboxData
        >,
      ),
      RescueResponseOutboxData,
      PrefetchHooks Function()
    >;
typedef $$RescueResponseInboxTableCreateCompanionBuilder =
    RescueResponseInboxCompanion Function({
      required String ownerId,
      required String messageId,
      required String incidentId,
      required String originMessageId,
      required String responderKeyId,
      required String immutableDigest,
      required String payload,
      required String state,
      required DateTime receivedAt,
      Value<DateTime?> processedAt,
      Value<int> rowid,
    });
typedef $$RescueResponseInboxTableUpdateCompanionBuilder =
    RescueResponseInboxCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> incidentId,
      Value<String> originMessageId,
      Value<String> responderKeyId,
      Value<String> immutableDigest,
      Value<String> payload,
      Value<String> state,
      Value<DateTime> receivedAt,
      Value<DateTime?> processedAt,
      Value<int> rowid,
    });

class $$RescueResponseInboxTableFilterComposer
    extends Composer<_$AppDatabase, $RescueResponseInboxTable> {
  $$RescueResponseInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
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

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RescueResponseInboxTableOrderingComposer
    extends Composer<_$AppDatabase, $RescueResponseInboxTable> {
  $$RescueResponseInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
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

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RescueResponseInboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $RescueResponseInboxTable> {
  $$RescueResponseInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originMessageId => $composableBuilder(
    column: $table.originMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responderKeyId => $composableBuilder(
    column: $table.responderKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );
}

class $$RescueResponseInboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RescueResponseInboxTable,
          RescueResponseInboxData,
          $$RescueResponseInboxTableFilterComposer,
          $$RescueResponseInboxTableOrderingComposer,
          $$RescueResponseInboxTableAnnotationComposer,
          $$RescueResponseInboxTableCreateCompanionBuilder,
          $$RescueResponseInboxTableUpdateCompanionBuilder,
          (
            RescueResponseInboxData,
            BaseReferences<
              _$AppDatabase,
              $RescueResponseInboxTable,
              RescueResponseInboxData
            >,
          ),
          RescueResponseInboxData,
          PrefetchHooks Function()
        > {
  $$RescueResponseInboxTableTableManager(
    _$AppDatabase db,
    $RescueResponseInboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RescueResponseInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RescueResponseInboxTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RescueResponseInboxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> originMessageId = const Value.absent(),
                Value<String> responderKeyId = const Value.absent(),
                Value<String> immutableDigest = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseInboxCompanion(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                originMessageId: originMessageId,
                responderKeyId: responderKeyId,
                immutableDigest: immutableDigest,
                payload: payload,
                state: state,
                receivedAt: receivedAt,
                processedAt: processedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String incidentId,
                required String originMessageId,
                required String responderKeyId,
                required String immutableDigest,
                required String payload,
                required String state,
                required DateTime receivedAt,
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseInboxCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                originMessageId: originMessageId,
                responderKeyId: responderKeyId,
                immutableDigest: immutableDigest,
                payload: payload,
                state: state,
                receivedAt: receivedAt,
                processedAt: processedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RescueResponseInboxTable,
                    RescueResponseInboxData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RescueResponseInboxTable,
                    RescueResponseInboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RescueResponseInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RescueResponseInboxTable,
      RescueResponseInboxData,
      $$RescueResponseInboxTableFilterComposer,
      $$RescueResponseInboxTableOrderingComposer,
      $$RescueResponseInboxTableAnnotationComposer,
      $$RescueResponseInboxTableCreateCompanionBuilder,
      $$RescueResponseInboxTableUpdateCompanionBuilder,
      (
        RescueResponseInboxData,
        BaseReferences<
          _$AppDatabase,
          $RescueResponseInboxTable,
          RescueResponseInboxData
        >,
      ),
      RescueResponseInboxData,
      PrefetchHooks Function()
    >;
typedef $$RescueResponseJobsTableCreateCompanionBuilder =
    RescueResponseJobsCompanion Function({
      required String ownerId,
      required String responseMessageId,
      required String nextHopKeyId,
      required String nextHopDeviceId,
      required String sessionBinding,
      required String state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$RescueResponseJobsTableUpdateCompanionBuilder =
    RescueResponseJobsCompanion Function({
      Value<String> ownerId,
      Value<String> responseMessageId,
      Value<String> nextHopKeyId,
      Value<String> nextHopDeviceId,
      Value<String> sessionBinding,
      Value<String> state,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$RescueResponseJobsTableFilterComposer
    extends Composer<_$AppDatabase, $RescueResponseJobsTable> {
  $$RescueResponseJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseMessageId => $composableBuilder(
    column: $table.responseMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionBinding => $composableBuilder(
    column: $table.sessionBinding,
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RescueResponseJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $RescueResponseJobsTable> {
  $$RescueResponseJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseMessageId => $composableBuilder(
    column: $table.responseMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionBinding => $composableBuilder(
    column: $table.sessionBinding,
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RescueResponseJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RescueResponseJobsTable> {
  $$RescueResponseJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get responseMessageId => $composableBuilder(
    column: $table.responseMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextHopKeyId => $composableBuilder(
    column: $table.nextHopKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextHopDeviceId => $composableBuilder(
    column: $table.nextHopDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionBinding => $composableBuilder(
    column: $table.sessionBinding,
    builder: (column) => column,
  );

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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$RescueResponseJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RescueResponseJobsTable,
          RescueResponseJob,
          $$RescueResponseJobsTableFilterComposer,
          $$RescueResponseJobsTableOrderingComposer,
          $$RescueResponseJobsTableAnnotationComposer,
          $$RescueResponseJobsTableCreateCompanionBuilder,
          $$RescueResponseJobsTableUpdateCompanionBuilder,
          (
            RescueResponseJob,
            BaseReferences<
              _$AppDatabase,
              $RescueResponseJobsTable,
              RescueResponseJob
            >,
          ),
          RescueResponseJob,
          PrefetchHooks Function()
        > {
  $$RescueResponseJobsTableTableManager(
    _$AppDatabase db,
    $RescueResponseJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RescueResponseJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RescueResponseJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RescueResponseJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> responseMessageId = const Value.absent(),
                Value<String> nextHopKeyId = const Value.absent(),
                Value<String> nextHopDeviceId = const Value.absent(),
                Value<String> sessionBinding = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseJobsCompanion(
                ownerId: ownerId,
                responseMessageId: responseMessageId,
                nextHopKeyId: nextHopKeyId,
                nextHopDeviceId: nextHopDeviceId,
                sessionBinding: sessionBinding,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String responseMessageId,
                required String nextHopKeyId,
                required String nextHopDeviceId,
                required String sessionBinding,
                required String state,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseJobsCompanion.insert(
                ownerId: ownerId,
                responseMessageId: responseMessageId,
                nextHopKeyId: nextHopKeyId,
                nextHopDeviceId: nextHopDeviceId,
                sessionBinding: sessionBinding,
                state: state,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RescueResponseJobsTable, RescueResponseJob>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $RescueResponseJobsTable,
                    RescueResponseJob
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RescueResponseJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RescueResponseJobsTable,
      RescueResponseJob,
      $$RescueResponseJobsTableFilterComposer,
      $$RescueResponseJobsTableOrderingComposer,
      $$RescueResponseJobsTableAnnotationComposer,
      $$RescueResponseJobsTableCreateCompanionBuilder,
      $$RescueResponseJobsTableUpdateCompanionBuilder,
      (
        RescueResponseJob,
        BaseReferences<
          _$AppDatabase,
          $RescueResponseJobsTable,
          RescueResponseJob
        >,
      ),
      RescueResponseJob,
      PrefetchHooks Function()
    >;
typedef $$RescueResponseReplayTableCreateCompanionBuilder =
    RescueResponseReplayCompanion Function({
      required String ownerId,
      required String messageId,
      required String immutableDigest,
      required DateTime firstSeenAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$RescueResponseReplayTableUpdateCompanionBuilder =
    RescueResponseReplayCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> immutableDigest,
      Value<DateTime> firstSeenAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$RescueResponseReplayTableFilterComposer
    extends Composer<_$AppDatabase, $RescueResponseReplayTable> {
  $$RescueResponseReplayTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RescueResponseReplayTableOrderingComposer
    extends Composer<_$AppDatabase, $RescueResponseReplayTable> {
  $$RescueResponseReplayTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RescueResponseReplayTableAnnotationComposer
    extends Composer<_$AppDatabase, $RescueResponseReplayTable> {
  $$RescueResponseReplayTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get immutableDigest => $composableBuilder(
    column: $table.immutableDigest,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$RescueResponseReplayTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RescueResponseReplayTable,
          RescueResponseReplayData,
          $$RescueResponseReplayTableFilterComposer,
          $$RescueResponseReplayTableOrderingComposer,
          $$RescueResponseReplayTableAnnotationComposer,
          $$RescueResponseReplayTableCreateCompanionBuilder,
          $$RescueResponseReplayTableUpdateCompanionBuilder,
          (
            RescueResponseReplayData,
            BaseReferences<
              _$AppDatabase,
              $RescueResponseReplayTable,
              RescueResponseReplayData
            >,
          ),
          RescueResponseReplayData,
          PrefetchHooks Function()
        > {
  $$RescueResponseReplayTableTableManager(
    _$AppDatabase db,
    $RescueResponseReplayTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RescueResponseReplayTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RescueResponseReplayTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RescueResponseReplayTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> immutableDigest = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseReplayCompanion(
                ownerId: ownerId,
                messageId: messageId,
                immutableDigest: immutableDigest,
                firstSeenAt: firstSeenAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String immutableDigest,
                required DateTime firstSeenAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => RescueResponseReplayCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                immutableDigest: immutableDigest,
                firstSeenAt: firstSeenAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RescueResponseReplayTable,
                    RescueResponseReplayData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RescueResponseReplayTable,
                    RescueResponseReplayData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RescueResponseReplayTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RescueResponseReplayTable,
      RescueResponseReplayData,
      $$RescueResponseReplayTableFilterComposer,
      $$RescueResponseReplayTableOrderingComposer,
      $$RescueResponseReplayTableAnnotationComposer,
      $$RescueResponseReplayTableCreateCompanionBuilder,
      $$RescueResponseReplayTableUpdateCompanionBuilder,
      (
        RescueResponseReplayData,
        BaseReferences<
          _$AppDatabase,
          $RescueResponseReplayTable,
          RescueResponseReplayData
        >,
      ),
      RescueResponseReplayData,
      PrefetchHooks Function()
    >;
typedef $$ChatRelayOutboxTableCreateCompanionBuilder =
    ChatRelayOutboxCompanion Function({
      required String ownerId,
      required String messageId,
      required String incidentId,
      required String senderKeyId,
      required String recipientKeyId,
      required String payload,
      required String state,
      Value<int> hopCount,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      required DateTime expiresAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$ChatRelayOutboxTableUpdateCompanionBuilder =
    ChatRelayOutboxCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> incidentId,
      Value<String> senderKeyId,
      Value<String> recipientKeyId,
      Value<String> payload,
      Value<String> state,
      Value<int> hopCount,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> expiresAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$ChatRelayOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $ChatRelayOutboxTable> {
  $$ChatRelayOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
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

  ColumnFilters<int> get hopCount => $composableBuilder(
    column: $table.hopCount,
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

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatRelayOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatRelayOutboxTable> {
  $$ChatRelayOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
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

  ColumnOrderings<int> get hopCount => $composableBuilder(
    column: $table.hopCount,
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

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatRelayOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatRelayOutboxTable> {
  $$ChatRelayOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get hopCount =>
      $composableBuilder(column: $table.hopCount, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ChatRelayOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatRelayOutboxTable,
          ChatRelayOutboxData,
          $$ChatRelayOutboxTableFilterComposer,
          $$ChatRelayOutboxTableOrderingComposer,
          $$ChatRelayOutboxTableAnnotationComposer,
          $$ChatRelayOutboxTableCreateCompanionBuilder,
          $$ChatRelayOutboxTableUpdateCompanionBuilder,
          (
            ChatRelayOutboxData,
            BaseReferences<
              _$AppDatabase,
              $ChatRelayOutboxTable,
              ChatRelayOutboxData
            >,
          ),
          ChatRelayOutboxData,
          PrefetchHooks Function()
        > {
  $$ChatRelayOutboxTableTableManager(
    _$AppDatabase db,
    $ChatRelayOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatRelayOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatRelayOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatRelayOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> senderKeyId = const Value.absent(),
                Value<String> recipientKeyId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> hopCount = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatRelayOutboxCompanion(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                senderKeyId: senderKeyId,
                recipientKeyId: recipientKeyId,
                payload: payload,
                state: state,
                hopCount: hopCount,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String incidentId,
                required String senderKeyId,
                required String recipientKeyId,
                required String payload,
                required String state,
                Value<int> hopCount = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                required DateTime expiresAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatRelayOutboxCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                senderKeyId: senderKeyId,
                recipientKeyId: recipientKeyId,
                payload: payload,
                state: state,
                hopCount: hopCount,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatRelayOutboxTable, ChatRelayOutboxData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatRelayOutboxTable,
                    ChatRelayOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatRelayOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatRelayOutboxTable,
      ChatRelayOutboxData,
      $$ChatRelayOutboxTableFilterComposer,
      $$ChatRelayOutboxTableOrderingComposer,
      $$ChatRelayOutboxTableAnnotationComposer,
      $$ChatRelayOutboxTableCreateCompanionBuilder,
      $$ChatRelayOutboxTableUpdateCompanionBuilder,
      (
        ChatRelayOutboxData,
        BaseReferences<
          _$AppDatabase,
          $ChatRelayOutboxTable,
          ChatRelayOutboxData
        >,
      ),
      ChatRelayOutboxData,
      PrefetchHooks Function()
    >;
typedef $$ChatRelayInboxTableCreateCompanionBuilder =
    ChatRelayInboxCompanion Function({
      required String ownerId,
      required String messageId,
      required String incidentId,
      required String senderKeyId,
      required String recipientKeyId,
      required String payload,
      required String state,
      required DateTime receivedAt,
      Value<int> rowid,
    });
typedef $$ChatRelayInboxTableUpdateCompanionBuilder =
    ChatRelayInboxCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> incidentId,
      Value<String> senderKeyId,
      Value<String> recipientKeyId,
      Value<String> payload,
      Value<String> state,
      Value<DateTime> receivedAt,
      Value<int> rowid,
    });

class $$ChatRelayInboxTableFilterComposer
    extends Composer<_$AppDatabase, $ChatRelayInboxTable> {
  $$ChatRelayInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
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

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatRelayInboxTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatRelayInboxTable> {
  $$ChatRelayInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
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

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatRelayInboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatRelayInboxTable> {
  $$ChatRelayInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderKeyId => $composableBuilder(
    column: $table.senderKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientKeyId => $composableBuilder(
    column: $table.recipientKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$ChatRelayInboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatRelayInboxTable,
          ChatRelayInboxData,
          $$ChatRelayInboxTableFilterComposer,
          $$ChatRelayInboxTableOrderingComposer,
          $$ChatRelayInboxTableAnnotationComposer,
          $$ChatRelayInboxTableCreateCompanionBuilder,
          $$ChatRelayInboxTableUpdateCompanionBuilder,
          (
            ChatRelayInboxData,
            BaseReferences<
              _$AppDatabase,
              $ChatRelayInboxTable,
              ChatRelayInboxData
            >,
          ),
          ChatRelayInboxData,
          PrefetchHooks Function()
        > {
  $$ChatRelayInboxTableTableManager(
    _$AppDatabase db,
    $ChatRelayInboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatRelayInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatRelayInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatRelayInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> senderKeyId = const Value.absent(),
                Value<String> recipientKeyId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatRelayInboxCompanion(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                senderKeyId: senderKeyId,
                recipientKeyId: recipientKeyId,
                payload: payload,
                state: state,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String incidentId,
                required String senderKeyId,
                required String recipientKeyId,
                required String payload,
                required String state,
                required DateTime receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChatRelayInboxCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                senderKeyId: senderKeyId,
                recipientKeyId: recipientKeyId,
                payload: payload,
                state: state,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatRelayInboxTable, ChatRelayInboxData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatRelayInboxTable,
                    ChatRelayInboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatRelayInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatRelayInboxTable,
      ChatRelayInboxData,
      $$ChatRelayInboxTableFilterComposer,
      $$ChatRelayInboxTableOrderingComposer,
      $$ChatRelayInboxTableAnnotationComposer,
      $$ChatRelayInboxTableCreateCompanionBuilder,
      $$ChatRelayInboxTableUpdateCompanionBuilder,
      (
        ChatRelayInboxData,
        BaseReferences<_$AppDatabase, $ChatRelayInboxTable, ChatRelayInboxData>,
      ),
      ChatRelayInboxData,
      PrefetchHooks Function()
    >;
typedef $$ChatReceiptsTableCreateCompanionBuilder =
    ChatReceiptsCompanion Function({
      required String ownerId,
      required String messageId,
      required String incidentId,
      required String transfer,
      required String previousKeyId,
      Value<String?> receipt,
      required String state,
      required DateTime receivedAt,
      required DateTime expiresAt,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<int> rowid,
    });
typedef $$ChatReceiptsTableUpdateCompanionBuilder =
    ChatReceiptsCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> incidentId,
      Value<String> transfer,
      Value<String> previousKeyId,
      Value<String?> receipt,
      Value<String> state,
      Value<DateTime> receivedAt,
      Value<DateTime> expiresAt,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<int> rowid,
    });

class $$ChatReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatReceiptsTable> {
  $$ChatReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transfer => $composableBuilder(
    column: $table.transfer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousKeyId => $composableBuilder(
    column: $table.previousKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receipt => $composableBuilder(
    column: $table.receipt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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
}

class $$ChatReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatReceiptsTable> {
  $$ChatReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transfer => $composableBuilder(
    column: $table.transfer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousKeyId => $composableBuilder(
    column: $table.previousKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receipt => $composableBuilder(
    column: $table.receipt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
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
}

class $$ChatReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatReceiptsTable> {
  $$ChatReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
    column: $table.incidentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transfer =>
      $composableBuilder(column: $table.transfer, builder: (column) => column);

  GeneratedColumn<String> get previousKeyId => $composableBuilder(
    column: $table.previousKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receipt =>
      $composableBuilder(column: $table.receipt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );
}

class $$ChatReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatReceiptsTable,
          ChatReceiptData,
          $$ChatReceiptsTableFilterComposer,
          $$ChatReceiptsTableOrderingComposer,
          $$ChatReceiptsTableAnnotationComposer,
          $$ChatReceiptsTableCreateCompanionBuilder,
          $$ChatReceiptsTableUpdateCompanionBuilder,
          (
            ChatReceiptData,
            BaseReferences<_$AppDatabase, $ChatReceiptsTable, ChatReceiptData>,
          ),
          ChatReceiptData,
          PrefetchHooks Function()
        > {
  $$ChatReceiptsTableTableManager(_$AppDatabase db, $ChatReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> incidentId = const Value.absent(),
                Value<String> transfer = const Value.absent(),
                Value<String> previousKeyId = const Value.absent(),
                Value<String?> receipt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatReceiptsCompanion(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                transfer: transfer,
                previousKeyId: previousKeyId,
                receipt: receipt,
                state: state,
                receivedAt: receivedAt,
                expiresAt: expiresAt,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String messageId,
                required String incidentId,
                required String transfer,
                required String previousKeyId,
                Value<String?> receipt = const Value.absent(),
                required String state,
                required DateTime receivedAt,
                required DateTime expiresAt,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatReceiptsCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                incidentId: incidentId,
                transfer: transfer,
                previousKeyId: previousKeyId,
                receipt: receipt,
                state: state,
                receivedAt: receivedAt,
                expiresAt: expiresAt,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatReceiptsTable, ChatReceiptData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatReceiptsTable,
                    ChatReceiptData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatReceiptsTable,
      ChatReceiptData,
      $$ChatReceiptsTableFilterComposer,
      $$ChatReceiptsTableOrderingComposer,
      $$ChatReceiptsTableAnnotationComposer,
      $$ChatReceiptsTableCreateCompanionBuilder,
      $$ChatReceiptsTableUpdateCompanionBuilder,
      (
        ChatReceiptData,
        BaseReferences<_$AppDatabase, $ChatReceiptsTable, ChatReceiptData>,
      ),
      ChatReceiptData,
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
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$BleRelayMessagesTableTableManager get bleRelayMessages =>
      $$BleRelayMessagesTableTableManager(_db, _db.bleRelayMessages);
  $$BleRelayAttemptsTableTableManager get bleRelayAttempts =>
      $$BleRelayAttemptsTableTableManager(_db, _db.bleRelayAttempts);
  $$BleRelayReceiptsTableTableManager get bleRelayReceipts =>
      $$BleRelayReceiptsTableTableManager(_db, _db.bleRelayReceipts);
  $$RescueInboxTableTableManager get rescueInbox =>
      $$RescueInboxTableTableManager(_db, _db.rescueInbox);
  $$RescueResponseOutboxTableTableManager get rescueResponseOutbox =>
      $$RescueResponseOutboxTableTableManager(_db, _db.rescueResponseOutbox);
  $$RescueResponseInboxTableTableManager get rescueResponseInbox =>
      $$RescueResponseInboxTableTableManager(_db, _db.rescueResponseInbox);
  $$RescueResponseJobsTableTableManager get rescueResponseJobs =>
      $$RescueResponseJobsTableTableManager(_db, _db.rescueResponseJobs);
  $$RescueResponseReplayTableTableManager get rescueResponseReplay =>
      $$RescueResponseReplayTableTableManager(_db, _db.rescueResponseReplay);
  $$ChatRelayOutboxTableTableManager get chatRelayOutbox =>
      $$ChatRelayOutboxTableTableManager(_db, _db.chatRelayOutbox);
  $$ChatRelayInboxTableTableManager get chatRelayInbox =>
      $$ChatRelayInboxTableTableManager(_db, _db.chatRelayInbox);
  $$ChatReceiptsTableTableManager get chatReceipts =>
      $$ChatReceiptsTableTableManager(_db, _db.chatReceipts);
}
