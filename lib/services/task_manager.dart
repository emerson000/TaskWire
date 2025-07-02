import '../models/task.dart' as domain;
import '../repositories/task_repository.dart';

class TaskManager {
  final TaskRepository _repo;

  TaskManager(this._repo);

  Future<List<domain.Task>> get rootTasks async => await _repo.getRootTasks();

  Future<domain.Task> createTask(String title, {int? parentId}) async {
    if (parentId != null) {
      final parent = await _repo.getTaskById(parentId);
      if (parent == null) {
        throw ArgumentError('Parent task not found: $parentId');
      }
    }

    return await _repo.createTask(title, parentId: parentId);
  }

  Future<void> deleteTask(int taskId) async {
    await _repo.deleteTask(taskId);
  }

  Future<void> updateTask(
    int taskId, {
    String? title,
    bool? isCompleted,
  }) async {
    await _repo.updateTask(taskId, title: title, isCompleted: isCompleted);
  }

  Future<domain.Task?> findTaskById(int taskId) async {
    return await _repo.getTaskById(taskId);
  }

  Future<void> moveTaskToParent(int taskId, int? newParentId) async {
    if (newParentId != null) {
      if (await _wouldCreateCycle(taskId, newParentId)) {
        throw ArgumentError('Cannot move task: would create a cycle');
      }

      final newParent = await _repo.getTaskById(newParentId);
      if (newParent == null) {
        throw ArgumentError('New parent task not found: $newParentId');
      }
    }

    await _repo.moveTaskToParent(taskId, newParentId);
  }

  Future<bool> _wouldCreateCycle(int taskId, int newParentId) async {
    if (taskId == newParentId) return true;

    final descendants = await _repo.getAllDescendants(taskId);
    return descendants.any((task) => task.id == newParentId);
  }

  Future<List<domain.Task>> getTasksAtLevel(String? parentId) async {
    if (parentId == null) {
      return await _repo.getRootTasks();
    }

    return await _repo.getSubtasks(int.parse(parentId));
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
        newIndex >= tasks.length ||
        oldIndex == newIndex) {
      return;
    }

    final task = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, task);

    await _repo.reorderTasks(tasks, parentId: parentId != null ? int.parse(parentId) : null);
  }
}
