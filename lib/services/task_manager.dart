import '../models/task.dart' as domain;
import '../repositories/task_repository.dart';
import '../database/database.dart';

class TaskManager {
  late final TaskRepository _repository;

  TaskManager() {
    final database = AppDatabase();
    _repository = TaskRepository(database);
  }

  Future<List<domain.Task>> get rootTasks async =>
      await _repository.getRootTasks();

  Future<domain.Task> createTask(String title, {int? parentId}) async {
    if (parentId != null) {
      final parent = await _repository.getTaskById(parentId);
      if (parent == null) {
        throw ArgumentError('Parent task not found: $parentId');
      }
    }

    return await _repository.createTask(title, parentId: parentId);
  }

  Future<void> deleteTask(int taskId) async {
    await _repository.deleteTask(taskId);
  }

  Future<void> updateTask(
    int taskId, {
    String? title,
    bool? isCompleted,
  }) async {
    await _repository.updateTask(
      taskId,
      title: title,
      isCompleted: isCompleted,
    );
  }

  Future<domain.Task?> findTaskById(int taskId) async {
    return await _repository.getTaskById(taskId);
  }

  Future<void> moveTaskToParent(int taskId, int? newParentId) async {
    if (newParentId != null) {
      if (await _wouldCreateCycle(taskId, newParentId)) {
        throw ArgumentError('Cannot move task: would create a cycle');
      }

      final newParent = await _repository.getTaskById(newParentId);
      if (newParent == null) {
        throw ArgumentError('New parent task not found: $newParentId');
      }
    }

    await _repository.moveTaskToParent(taskId, newParentId);
  }

  Future<bool> _wouldCreateCycle(int taskId, int newParentId) async {
    if (taskId == newParentId) return true;

    final descendants = await _repository.getAllDescendants(taskId);
    return descendants.any((task) => task.id == newParentId);
  }

  Future<List<domain.Task>> getTasksAtLevel(String? parentId) async {
    if (parentId == null) {
      return await _repository.getRootTasks();
    }

    return await _repository.getSubtasks(int.parse(parentId));
  }

  Future<void> reorderTasks(
    String? parentId,
    int oldIndex,
    int newIndex,
  ) async {
    final tasks = await getTasksAtLevel(parentId);

    if (oldIndex < 0 ||
        oldIndex >= tasks.length ||
        newIndex < 0 ||
        newIndex >= tasks.length) {
      return;
    }

    final task = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, task);
  }
}
