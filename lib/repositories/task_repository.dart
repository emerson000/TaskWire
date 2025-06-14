import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/task.dart' as domain;

class TaskRepository {
  final AppDatabase _database;

  TaskRepository(this._database);

  Future<List<domain.Task>> getRootTasks() async {
    final dbTasks = await _database.getAllRootTasks();
    final domainTasks = <domain.Task>[];

    for (final dbTask in dbTasks) {
      final domainTask = await _convertToDomainTask(dbTask);
      domainTasks.add(domainTask);
    }

    return domainTasks;
  }

  Future<List<domain.Task>> getSubtasks(int parentId) async {
    final dbTasks = await _database.getSubtasks(parentId);
    final domainTasks = <domain.Task>[];

    for (final dbTask in dbTasks) {
      final domainTask = await _convertToDomainTask(dbTask);
      domainTasks.add(domainTask);
    }

    return domainTasks;
  }

  Future<domain.Task?> getTaskById(int taskId) async {
    final dbTask = await _database.getTaskById(taskId);
    if (dbTask == null) return null;

    return await _convertToDomainTask(dbTask);
  }

  Future<domain.Task> createTask(String title, {int? parentId}) async {
    final companion = TasksCompanion.insert(
      title: title,
      parentId: parentId == null ? const Value.absent() : Value(parentId),
    );

    final id = await _database.insertTask(companion);
    final dbTask = await _database.getTaskById(id);
    return await _convertToDomainTask(dbTask!);
  }

  Future<void> updateTask(
    int taskId, {
    String? title,
    bool? isCompleted,
  }) async {
    final dbTask = await _database.getTaskById(taskId);
    if (dbTask == null) return;

    final companion = TasksCompanion(
      id: Value(taskId),
      title: title != null ? Value(title) : const Value.absent(),
      isCompleted: isCompleted != null
          ? Value(isCompleted)
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await _database.updateTask(companion);
  }

  Future<void> deleteTask(int taskId) async {
    await _database.deleteTaskAndDescendants(taskId);
  }

  Future<void> moveTaskToParent(int taskId, int? newParentId) async {
    final companion = TasksCompanion(
      id: Value(taskId),
      parentId: newParentId != null ? Value(newParentId) : const Value(null),
      updatedAt: Value(DateTime.now()),
    );

    await _database.updateTask(companion);
  }

  Future<List<domain.Task>> getAllDescendants(int taskId) async {
    final dbTasks = await _database.getAllDescendants(taskId);
    final domainTasks = <domain.Task>[];

    for (final dbTask in dbTasks) {
      final domainTask = await _convertToDomainTask(dbTask);
      domainTasks.add(domainTask);
    }

    return domainTasks;
  }

  Future<domain.Task> _convertToDomainTask(Task dbTask) async {
    final subtasks = await getSubtasks(dbTask.id);

    return domain.Task(
      id: dbTask.id,
      title: dbTask.title,
      isCompleted: dbTask.isCompleted,
      parentId: dbTask.parentId,
      subtasks: subtasks,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
    );
  }
}
