import 'package:drift/drift.dart';

class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get album => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get content => text()();
  TextColumn get songKey => text().nullable()();
  IntColumn get capo => integer().nullable()();
  IntColumn get tempo => integer().nullable()();
  IntColumn get category => integer().withDefault(const Constant(10))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastOpenedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Artists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

class SongArtists extends Table {
  TextColumn get songId => text().references(Songs, #id)();
  TextColumn get artistId => text().references(Artists, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {songId, artistId};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

class SongTags extends Table {
  TextColumn get songId => text().references(Songs, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {songId, tagId};
}
