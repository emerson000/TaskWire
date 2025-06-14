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

  Future<List<Task>> get _currentTasks {
    return widget.taskManager.getTasksAtLevel(_currentParent?.id?.toString());
  }

  void _navigateToSubtasks(Task parentTask) {
    setState(() {
      _currentParent = parentTask;
      _breadcrumbs.add(parentTask);
    });
  }

  void _navigateUp(Task? targetParent) {
    setState(() {
      _currentParent = targetParent;

      final targetIndex = _breadcrumbs.indexOf(targetParent);
      if (targetIndex != -1) {
        _breadcrumbs = _breadcrumbs.sublist(0, targetIndex + 1);
      }
    });
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) {
    if (draggedTask.id == targetTask.id) return;

    try {
      widget.taskManager.moveTaskToParent(draggedTask.id, targetTask.id);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${draggedTask.title}" moved to "${targetTask.title}"',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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

  Future<void> _moveTaskToParent(Task draggedTask) async {
    if (_currentParent == null) return;

    try {
      widget.taskManager.moveTaskToParent(
        draggedTask.id,
        _currentParent!.parentId,
      );
      setState(() {});

      final grandparentTask = _currentParent!.parentId != null
          ? await widget.taskManager.findTaskById(_currentParent!.parentId!)
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            grandparentTask != null
                ? '"${draggedTask.title}" moved to "${grandparentTask.title}"'
                : '"${draggedTask.title}" moved to root level',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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
        return Column(
          children: [
            BreadcrumbNavigation(
              breadcrumbs: _breadcrumbs,
              onNavigate: _navigateUp,
            ),
            if (_currentParent != null)
              DragTarget<Task>(
                onWillAccept: (data) =>
                    data != null && data.parentId == _currentParent!.id,
                onAccept: (draggedTask) => _moveTaskToParent(draggedTask),
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty
                          ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subtasks of "${_currentParent!.title}"',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (_isDragging)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Move to "${_currentParent!.title}"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: candidateData.isNotEmpty
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      fontWeight: candidateData.isNotEmpty
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
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
                  );
                },
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.1),
                ),
                child: FutureBuilder<List<Task>>(
                  future: _currentTasks,
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
                              onTap: task.hasSubtasks
                                  ? () => _navigateToSubtasks(task)
                                  : null,
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
        );
      },
    );
  }
}
