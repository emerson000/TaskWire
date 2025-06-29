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

  Future<void> reorderTaskInList(
    int? parentId,
    int taskId,
    int oldIndex,
    int newIndex,
  ) async {
    // Fetch the current list of tasks for the given parent, already sorted by order
    final tasks = await (parentId == null
        ? _repo.getRootTasks()
        : _repo.getSubtasks(parentId));

    if (oldIndex < 0 || oldIndex >= tasks.length || newIndex < 0 || newIndex >= tasks.length) {
      print("ReorderTaskInList: Invalid indices old: $oldIndex, new: $newIndex, length: ${tasks.length}");
      return;
    }

    // Find the task being moved
    final taskToMove = tasks[oldIndex];
    if (taskToMove.id != taskId) {
      print("ReorderTaskInList: Task ID mismatch. Expected: $taskId, Found: ${taskToMove.id}");
      return;
    }

    // Remove the task from its current position
    tasks.removeAt(oldIndex);

    // Insert it at the new position
    tasks.insert(newIndex, taskToMove);

    // Update the order values for all tasks in the list
    final updatedTasks = <domain.Task>[];
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final newOrder = i + 1; // Use 1-based ordering
      if (task.order != newOrder) {
        updatedTasks.add(task.copyWith(order: newOrder));
      }
    }

    // Update all tasks in the database
    if (updatedTasks.isNotEmpty) {
      await _repo.updateTaskOrderInBatch(updatedTasks);
    }
  }
}
