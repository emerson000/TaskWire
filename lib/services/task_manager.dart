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
    int? parentId, // Changed to int? to align with domain model
    int taskId,    // ID of the task being moved
    int oldIndex,  // Original index in the list (0-based)
    int newIndex,  // New index in the list (0-based)
  ) async {
    // Fetch the current list of tasks for the given parent, already sorted by order
    final tasks = await (parentId == null
        ? _repo.getRootTasks()
        : _repo.getSubtasks(parentId));

    if (oldIndex < 0 || oldIndex >= tasks.length || newIndex < 0 || newIndex >= tasks.length) {
      // Index out of bounds, though newIndex can be tasks.length for moving to the end.
      // For simplicity, we'll assume newIndex is also within current bounds for now.
      // A more robust check might be needed if newIndex can be tasks.length.
      print("ReorderTaskInList: Invalid indices old: $oldIndex, new: $newIndex, length: ${tasks.length}");
      return;
    }

    // Find the task being moved. The list is 0-indexed, matching oldIndex.
    final taskToMove = tasks.removeAt(oldIndex);

    // Insert it at the new position.
    tasks.insert(newIndex, taskToMove);

    // Update the 'order' property for all tasks in this list.
    // The 'order' should now reflect their new position in the 'tasks' list.
    // We can use 1-based ordering for the database, or 0-based if preferred.
    // Let's use 1-based to match the repository's createTask logic.
    final List<domain.Task> updatedTasks = [];
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].order != (i + 1)) {
        updatedTasks.add(tasks[i].copyWith(order: i + 1));
      }
    }

    if (updatedTasks.isNotEmpty) {
      await _repo.updateTaskOrderInBatch(updatedTasks);
    }
  }
}
