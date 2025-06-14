import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import 'task_tile.dart';
import 'breadcrumb_navigation.dart';

class MobileDrillDownView extends StatefulWidget {
  final TaskManager taskManager;
  final Function(int, {String? title, bool? isCompleted}) onUpdateTask;
  final Function(int) onDeleteTask;
  final Function(Task) onStartEditing;
  final Function() onFinishEditing;
  final int? editingTaskId;
  final TextEditingController editController;
  final Function(String?) onAddTask;

  const MobileDrillDownView({
    super.key,
    required this.taskManager,
    required this.onUpdateTask,
    required this.onDeleteTask,
    required this.onStartEditing,
    required this.onFinishEditing,
    this.editingTaskId,
    required this.editController,
    required this.onAddTask,
  });

  @override
  State<MobileDrillDownView> createState() => _MobileDrillDownViewState();
}

class _MobileDrillDownViewState extends State<MobileDrillDownView> {
  Task? _currentParent;
  List<Task?> _breadcrumbs = [null];
  bool _isDragging = false;
  Future<List<Task>>? _currentTasksFuture;

  Future<List<Task>> _getCurrentTasks() {
    return widget.taskManager.getTasksAtLevel(_currentParent?.id?.toString());
  }

  void _refreshTasks() {
    _currentTasksFuture = _getCurrentTasks();
  }

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _navigateToSubtasks(Task parentTask) {
    setState(() {
      _currentParent = parentTask;
      _breadcrumbs.add(parentTask);
      _refreshTasks();
    });
  }

  void _navigateUp(Task? targetParent) {
    setState(() {
      _currentParent = targetParent;

      final targetIndex = _breadcrumbs.indexOf(targetParent);
      if (targetIndex != -1) {
        _breadcrumbs = _breadcrumbs.sublist(0, targetIndex + 1);
      }
      _refreshTasks();
    });
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) async {
    if (draggedTask.id == targetTask.id) return;

    try {
      await widget.taskManager.moveTaskToParent(draggedTask.id, targetTask.id);
      
      if (mounted) {
        setState(() {
          _refreshTasks();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${draggedTask.title}" moved to "${targetTask.title}"',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot move task: ${e.toString().replaceAll('ArgumentError: ', '')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onBreadcrumbDrop(Task draggedTask, Task? targetParent) async {
    try {
      await widget.taskManager.moveTaskToParent(draggedTask.id, targetParent?.id);
      
      if (mounted) {
        setState(() {
          _refreshTasks();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetParent != null
                  ? '"${draggedTask.title}" moved to "${targetParent.title}"'
                  : '"${draggedTask.title}" moved to root level',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot move task: ${e.toString().replaceAll('ArgumentError: ', '')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAccept: (_) {
        if (!_isDragging) {
          setState(() {
            _isDragging = true;
          });
        }
        return false;
      },
      onLeave: (_) {
        setState(() {
          _isDragging = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return SizedBox.expand(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreadcrumbNavigation(
                breadcrumbs: _breadcrumbs,
                onNavigate: _navigateUp,
                onTaskDrop: _onBreadcrumbDrop,
                isDragging: _isDragging,
              ),
              if (_currentParent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Subtasks of "${_currentParent!.title}"',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            widget.onAddTask(_currentParent!.id.toString()),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Subtask'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.1),
                  ),
                  child: FutureBuilder<List<Task>>(
                    future: _currentTasksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final tasks = snapshot.data!;
                      return ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return DragTarget<Task>(
                            onWillAccept: (data) =>
                                data != null && data.id != task.id,
                            onAccept: (draggedTask) =>
                                _onTaskDrop(draggedTask, task),
                            builder: (context, candidateData, rejectedData) {
                              return TaskTile(
                                key: ValueKey(task.id),
                                task: task,
                                isEditing: widget.editingTaskId == task.id,
                                editController: widget.editController,
                                onTap: () => _navigateToSubtasks(task),
                                onEdit: () => widget.onStartEditing(task),
                                onDelete: () => widget.onDeleteTask(task.id),
                                onCheckboxChanged: (_) => widget.onUpdateTask(
                                  task.id,
                                  isCompleted: !task.isCompleted,
                                ),
                                onEditComplete: widget.onFinishEditing,
                                isDragTarget: candidateData.isNotEmpty,
                                onDragAccept: (draggedTask) =>
                                    _onTaskDrop(draggedTask, task),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
