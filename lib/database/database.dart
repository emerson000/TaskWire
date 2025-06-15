import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.drop(tasks);
        await m.createAll();
      }
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
