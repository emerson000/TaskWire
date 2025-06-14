import '../models/task.dart';

class TaskManager {
  List<Task> _rootTasks = [];
  static int _taskCounter = 0;

  List<Task> get rootTasks => List.unmodifiable(_rootTasks);

  String _generateTaskId() {
    _taskCounter++;
    return 'task_$_taskCounter';
  }

  Task createTask(String title, {String? parentId}) {
    final task = Task(
      id: _generateTaskId(),
      title: title,
    );

    if (parentId != null) {
      final parent = findTaskById(parentId);
      if (parent != null) {
        parent.addSubtask(task);
      } else {
        throw ArgumentError('Parent task not found: $parentId');
      }
    } else {
      _rootTasks.add(task);
    }

    return task;
  }

  void deleteTask(String taskId) {
    final task = findTaskById(taskId);
    if (task == null) return;

    if (task.parentId != null) {
      final parent = findTaskById(task.parentId!);
      parent?.removeSubtask(task);
    } else {
      _rootTasks.remove(task);
    }
  }

  void updateTask(String taskId, {String? title, bool? isCompleted}) {
    final task = findTaskById(taskId);
    if (task == null) return;

    if (title != null) task.title = title;
    if (isCompleted != null) task.isCompleted = isCompleted;
    task.updatedAt = DateTime.now();
  }

  Task? findTaskById(String taskId) {
    for (Task task in _rootTasks) {
      Task? found = task.findTaskById(taskId);
      if (found != null) return found;
    }
    return null;
  }

  void moveTaskToParent(String taskId, String? newParentId) {
    final task = findTaskById(taskId);
    if (task == null) return;

    if (task.parentId != null) {
      final oldParent = findTaskById(task.parentId!);
      oldParent?.removeSubtask(task);
    } else {
      _rootTasks.remove(task);
    }

    if (newParentId != null) {
      final newParent = findTaskById(newParentId);
      if (newParent != null) {
        if (_wouldCreateCycle(taskId, newParentId)) {
          throw ArgumentError('Cannot move task: would create a cycle');
        }
        newParent.addSubtask(task);
      } else {
        throw ArgumentError('New parent task not found: $newParentId');
      }
    } else {
      task.parentId = null;
      _rootTasks.add(task);
    }
  }

  bool _wouldCreateCycle(String taskId, String potentialParentId) {
    final task = findTaskById(taskId);
    if (task == null) return false;

    final descendants = task.getAllDescendants();
    return descendants.any((descendant) => descendant.id == potentialParentId);
  }

  List<Task> getTasksAtLevel(String? parentId) {
    if (parentId == null) {
      return List.from(_rootTasks);
    }

    final parent = findTaskById(parentId);
    return parent?.subtasks ?? [];
  }

  void reorderTasks(String? parentId, int oldIndex, int newIndex) {
    List<Task> tasks =
        parentId == null ? _rootTasks : findTaskById(parentId)?.subtasks ?? [];

    if (oldIndex < 0 ||
        oldIndex >= tasks.length ||
        newIndex < 0 ||
        newIndex >= tasks.length) {
      return;
    }

    final task = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, task);
  }

  void loadSampleData() {
    _rootTasks.clear();
    _taskCounter = 0;

    final task1 = createTask('Plan vacation');
    final task2 = createTask('Work project');
    final task3 = createTask('Personal goals');

    createTask('Research destinations', parentId: task1.id);
    createTask('Book flights', parentId: task1.id);
    final accommodation = createTask('Find accommodation', parentId: task1.id);
    createTask('Hotels', parentId: accommodation.id);
    createTask('Airbnb options', parentId: accommodation.id);

    createTask('Complete feature X', parentId: task2.id);
    final testing = createTask('Testing phase', parentId: task2.id);
    createTask('Unit tests', parentId: testing.id);
    createTask('Integration tests', parentId: testing.id);
    createTask('Deploy to production', parentId: task2.id);

    createTask('Exercise routine', parentId: task3.id);
    final learning = createTask('Learn new skill', parentId: task3.id);
    createTask('Choose online course', parentId: learning.id);
    createTask('Practice daily', parentId: learning.id);
  }
}
