import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/task.dart' as domain;

class TaskRepository {
  final AppDatabase _database;

  TaskRepository(this._database);

  Future<List<domain.Task>> getRootTasks() async {
    // Modify the underlying DB query to sort by 'order'
    final query = _database.select(_database.tasks)
      ..where((t) => t.parentId.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.order)]);
    final dbTasks = await query.get();

    final domainTasks = <domain.Task>[];
    for (final dbTask in dbTasks) {
      final domainTask = await _convertToDomainTask(dbTask);
      domainTasks.add(domainTask);
    }
    return domainTasks;
  }

  Future<List<domain.Task>> getSubtasks(int parentId) async {
    // Modify the underlying DB query to sort by 'order'
    final query = _database.select(_database.tasks)
      ..where((t) => t.parentId.equals(parentId))
      ..orderBy([(t) => OrderingTerm(expression: t.order)]);
    final dbTasks = await query.get();

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
    // Determine the order for the new task
    final tasksInLevel = parentId == null
        ? await getRootTasks()
        : await getSubtasks(parentId);
    final nextOrder = tasksInLevel.isNotEmpty
        ? tasksInLevel.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1
        : 1;

    final companion = TasksCompanion.insert(
      title: title,
      parentId: parentId == null ? const Value.absent() : Value(parentId),
      order: Value(nextOrder), // Set the order for the new task
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
      // order is not updated here, it's handled by reorderTask
      updatedAt: Value(DateTime.now()),
    );

    await _database.updateTask(companion);
  }

  Future<void> deleteTask(int taskId) async {
    // Before deleting, get the task to know its parent and order
    final taskToDelete = await getTaskById(taskId);
    if (taskToDelete == null) return;

    await _database.deleteTaskAndDescendants(taskId);

    // Adjust order of subsequent tasks in the same list
    final siblings = taskToDelete.parentId == null
        ? await getRootTasks()
        : await getSubtasks(taskToDelete.parentId!);

    for (final sibling in siblings) {
      if (sibling.order > taskToDelete.order) {
        final updatedSibling = TasksCompanion(
          id: Value(sibling.id),
          order: Value(sibling.order - 1),
          updatedAt: Value(DateTime.now()),
        );
        await _database.updateTask(updatedSibling);
      }
    }
  }

  Future<void> moveTaskToParent(int taskId, int? newParentId) async {
    // Determine the order for the task in its new list
    final tasksInNewLevel = newParentId == null
        ? await getRootTasks()
        : await getSubtasks(newParentId);
    final nextOrder = tasksInNewLevel.isNotEmpty
        ? tasksInNewLevel.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1
        : 1;

    final oldTaskData = await getTaskById(taskId);
    if (oldTaskData == null) return; // Task to move not found
    final oldParentId = oldTaskData.parentId;
    final oldOrder = oldTaskData.order;

    final companion = TasksCompanion(
      id: Value(taskId),
      parentId: newParentId != null ? Value(newParentId) : const Value(null),
      order: Value(nextOrder), // Set new order in the new list
      updatedAt: Value(DateTime.now()),
    );
    await _database.updateTask(companion);

    // Adjust order in the old list
    final oldSiblings = oldParentId == null
        ? await (_database.select(_database.tasks)..where((t) => t.parentId.isNull())..orderBy([(t) => OrderingTerm(expression: t.order)])).get()
        : await (_database.select(_database.tasks)..where((t) => t.parentId.equals(oldParentId))..orderBy([(t) => OrderingTerm(expression: t.order)])).get();

    for (final dbSibling in oldSiblings) {
      if (dbSibling.id != taskId && dbSibling.order > oldOrder) {
        final updatedSiblingCompanion = TasksCompanion(
          id: Value(dbSibling.id),
          order: Value(dbSibling.order - 1),
          updatedAt: Value(DateTime.now()),
        );
        await _database.updateTask(updatedSiblingCompanion);
      }
    }
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
      order: dbTask.order, // Include order in domain task
    );
  }

  Future<void> reorderTask(int taskId, int? parentId, int newOrder) async {
    // This method is simplified. A robust solution would involve a transaction
    // and careful updates to avoid order conflicts.
    // For now, directly update the task's order.
    // More complex logic to shift other tasks will be in TaskManager or here.

    final companion = TasksCompanion(
      id: Value(taskId),
      order: Value(newOrder),
      updatedAt: Value(DateTime.now()),
    );
    await _database.updateTask(companion);
  }

  Future<void> updateTaskOrderInBatch(List<domain.Task> tasksToUpdate) async {
    // This is a more efficient way to update orders for multiple tasks.
    // It assumes the domain.Task objects already have their new correct 'order' values.
    final companions = tasksToUpdate.map((task) => TasksCompanion(
      id: Value(task.id),
      order: Value(task.order),
      updatedAt: Value(DateTime.now()),
    )).toList();

    // Drift's batch update capabilities can be used here if available,
    // or loop through individual updates.
    // For simplicity, looping:
    for (final companion in companions) {
      await _database.updateTask(companion);
    }
  }
}
