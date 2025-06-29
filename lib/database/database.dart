import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:taskwire/models/printer.dart';
import 'package:taskwire/services/logging_service.dart';

part 'database.g.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get order => integer().withDefault(const Constant(0))();
}

@DataClassName('PrinterEntry')
class Printers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => integer().map(const PrinterTypeConverter())();
  TextColumn get address => text()();
  BoolColumn get isConnected => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PrinterTypeConverter extends TypeConverter<PrinterType, int> {
  const PrinterTypeConverter();
  @override
  PrinterType fromSql(int fromDb) {
    return PrinterType.values[fromDb];
  }

  @override
  int toSql(PrinterType value) {
    return value.index;
  }
}

@DriftDatabase(tables: [Tasks, Printers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5; // Incremented schema version

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      LoggingService.info('Creating database with all tables...');
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      LoggingService.info('Migrating database from version $from to $to');
      if (from < 4) {
        // This check might be redundant if schema version 4 already created printers table
        // but it's harmless.
        LoggingService.info('Ensuring printers table exists (migration from <4 to $to)...');
        await m.createTable(printers);
      }
      if (from < 5) {
        LoggingService.info('Adding order column to tasks table (migration from <5 to $to)...');
        await m.addColumn(tasks, tasks.order);
        // Initialize order for existing tasks.
        // A simple way is to use their ID, or createdAt time if available and reliable.
        // Using ID is simpler and guarantees uniqueness for existing items.
        await customStatement('UPDATE tasks SET "order" = id WHERE "order" = 0;');
      }
    },
    beforeOpen: (details) async {
      LoggingService.info(
        'Database opened. Schema version: ${details.versionBefore} -> ${details.versionNow}',
      );
      await customStatement('''
        CREATE TABLE IF NOT EXISTS printers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER NOT NULL,
          address TEXT NOT NULL,
          is_connected BOOLEAN NOT NULL DEFAULT 0,
          last_seen DATETIME
        )
      ''');
    },
  );

  Future<List<Task>> getAllRootTasks() {
    return (select(tasks)
          ..where((t) => t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
  }

  Future<List<Task>> getSubtasks(int parentId) {
    return (select(tasks)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
  }

  Future<Task?> getTaskById(int taskId) {
    return (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
  }

  Future<List<Task>> getAllDescendants(int taskId) async {
    final descendants = <Task>[];
    final directChildren = await getSubtasks(taskId);

    for (final child in directChildren) {
      descendants.add(child);
      descendants.addAll(await getAllDescendants(child.id));
    }

    return descendants;
  }

  Future<int> insertTask(TasksCompanion task) {
    return into(tasks).insert(task);
  }

  Future<bool> updateTask(TasksCompanion task) async {
    final existing = await getTaskById(task.id.value);
    if (existing == null) return false;

    final updatedTask = TasksCompanion(
      id: task.id,
      title: task.title.present ? task.title : Value(existing.title),
      isCompleted: task.isCompleted.present
          ? task.isCompleted
          : Value(existing.isCompleted),
      parentId: task.parentId.present
          ? task.parentId
          : Value(existing.parentId),
      createdAt: task.createdAt.present
          ? task.createdAt
          : Value(existing.createdAt),
      updatedAt: task.updatedAt.present
          ? task.updatedAt
          : Value(existing.updatedAt),
    );

    return update(tasks).replace(updatedTask);
  }

  Future<int> deleteTask(int taskId) {
    return (delete(tasks)..where((t) => t.id.equals(taskId))).go();
  }

  Future<int> deleteTaskAndDescendants(int taskId) async {
    final descendants = await getAllDescendants(taskId);
    int deletedCount = 0;

    for (final descendant in descendants) {
      deletedCount += await deleteTask(descendant.id);
    }

    deletedCount += await deleteTask(taskId);
    return deletedCount;
  }

  Future<List<PrinterEntry>> get allPrinters => select(printers).get();

  Future<String> addPrinter(PrintersCompanion printer) {
    into(printers).insert(printer, mode: InsertMode.insertOrReplace);
    return Future.value(printer.id.value);
  }

  Future<void> deletePrinter(String id) =>
      (delete(printers)..where((p) => p.id.equals(id))).go();

  Future<void> updatePrinter(PrinterEntry printer) =>
      update(printers).replace(printer);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      Directory dbFolder;
      try {
        dbFolder = await getApplicationDocumentsDirectory();
      } catch (e) {
        final tempDir = await getTemporaryDirectory();
        dbFolder = Directory(p.join(tempDir.path, 'app_data'));
        if (!await dbFolder.exists()) {
          await dbFolder.create(recursive: true);
        }
      }

      final file = File(p.join(dbFolder.path, 'taskwire.db'));
      return NativeDatabase(file);
    } catch (e) {
      rethrow;
    }
  });
}
