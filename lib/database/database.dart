import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:taskwire/models/printer.dart';

part 'database.g.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PrinterEntry')
class Printers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => integer().map(const PrinterTypeConverter())();
  TextColumn get address => text()();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      print('Creating database with all tables...');
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      print('Migrating database from version $from to $to');
      if (from < 2) {
        print('Creating printers table...');
        await m.createTable(printers);
      }
    },
    beforeOpen: (details) async {
      print(
        'Database opened. Schema version: ${details.versionBefore} -> ${details.versionNow}',
      );
      // Ensure printers table exists
      await customStatement('''
        CREATE TABLE IF NOT EXISTS printers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER NOT NULL,
          address TEXT NOT NULL,
          last_seen DATETIME
        )
      ''');
    },
  );

  Future<List<Task>> getAllRootTasks() {
    return (select(tasks)..where((t) => t.parentId.isNull())).get();
  }

  Future<List<Task>> getSubtasks(int parentId) {
    return (select(tasks)..where((t) => t.parentId.equals(parentId))).get();
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
