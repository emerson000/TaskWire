import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../widgets/task_tile.dart';
import '../widgets/breadcrumb_navigation.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final TaskManager _taskManager = TaskManager();
  Task? _currentParent;
  List<Task?> _breadcrumbs = [null];
  String? _editingTaskId;
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _newTaskController = TextEditingController();
  bool _showAddTask = false;

  @override
  void initState() {
    super.initState();
    _taskManager.loadSampleData();
  }

  @override
  void dispose() {
    _editController.dispose();
    _newTaskController.dispose();
    super.dispose();
  }

  List<Task> get _currentTasks {
    return _taskManager.getTasksAtLevel(_currentParent?.id);
  }

  void _navigateToSubtasks(Task parentTask) {
    setState(() {
      _currentParent = parentTask;
      _breadcrumbs.add(parentTask);
      _editingTaskId = null;
      _showAddTask = false;
    });
  }

  void _navigateUp(Task? targetParent) {
    setState(() {
      _currentParent = targetParent;

      final targetIndex = _breadcrumbs.indexOf(targetParent);
      if (targetIndex != -1) {
        _breadcrumbs = _breadcrumbs.sublist(0, targetIndex + 1);
      }

      _editingTaskId = null;
      _showAddTask = false;
    });
  }

  void _addTask() {
    if (_newTaskController.text.trim().isEmpty) return;

    try {
      _taskManager.createTask(
        _newTaskController.text.trim(),
        parentId: _currentParent?.id,
      );
      _newTaskController.clear();
      setState(() {
        _showAddTask = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating task: $e');
      }
    }
  }

  void _deleteTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _taskManager.deleteTask(task.id);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _startEditing(Task task) {
    _editController.text = task.title;
    setState(() {
      _editingTaskId = task.id;
    });
  }

  void _finishEditing() {
    if (_editingTaskId != null && _editController.text.trim().isNotEmpty) {
      _taskManager.updateTask(
        _editingTaskId!,
        title: _editController.text.trim(),
      );
    }
    setState(() {
      _editingTaskId = null;
    });
  }

  void _toggleTaskCompletion(Task task) {
    _taskManager.updateTask(task.id, isCompleted: !task.isCompleted);
    setState(() {});
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) {
    if (draggedTask.id == targetTask.id) return;

    try {
      _taskManager.moveTaskToParent(draggedTask.id, targetTask.id);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('"${draggedTask.title}" moved to "${targetTask.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cannot move task: ${e.toString().replaceAll('ArgumentError: ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _currentTasks;

    return Scaffold(
      body: Column(
        children: [
          BreadcrumbNavigation(
            breadcrumbs: _breadcrumbs,
            onNavigate: _navigateUp,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.1),
              ),
              child: ListView.builder(
                itemCount: tasks.length + (_showAddTask ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_showAddTask && index == tasks.length) {
                    return _buildAddTaskTile();
                  }

                  final task = tasks[index];
                  return DragTarget<Task>(
                    onWillAccept: (data) => data != null && data.id != task.id,
                    onAccept: (draggedTask) => _onTaskDrop(draggedTask, task),
                    builder: (context, candidateData, rejectedData) {
                      return TaskTile(
                        key: ValueKey(task.id),
                        task: task,
                        isEditing: _editingTaskId == task.id,
                        editController: _editController,
                        onTap: task.hasSubtasks
                            ? () => _navigateToSubtasks(task)
                            : null,
                        onEdit: () => _startEditing(task),
                        onDelete: () => _deleteTask(task),
                        onCheckboxChanged: (_) => _toggleTaskCompletion(task),
                        onEditComplete: _finishEditing,
                        isDragTarget: candidateData.isNotEmpty,
                        onDragAccept: (draggedTask) =>
                            _onTaskDrop(draggedTask, task),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showAddTask = true;
          });
        },
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAddTaskTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _newTaskController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _currentParent != null
                    ? 'Add subtask to "${_currentParent!.title}"'
                    : 'Add new task',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              onSubmitted: (_) => _addTask(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _addTask,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _newTaskController.clear();
              setState(() {
                _showAddTask = false;
              });
            },
          ),
        ],
      ),
    );
  }
}
