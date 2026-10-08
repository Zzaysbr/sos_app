import 'package:drift/drift.dart';

class SosMessages extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get type => text()();

  TextColumn get message => text().nullable()();

  RealColumn get latitude => real().nullable()();

  RealColumn get longitude => real().nullable()();

  TextColumn get status => text()();

  TextColumn get syncState => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
