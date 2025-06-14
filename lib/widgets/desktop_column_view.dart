import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import 'task_tile.dart';

class DesktopColumnView extends StatefulWidget {
  final TaskManager taskManager;
  final Function(String, {String? title, bool? isCompleted}) onUpdateTask;
  final Function(String) onDeleteTask;
  final Function(Task) onStartEditing;
  final Function() onFinishEditing;
  final String? editingTaskId;
  final TextEditingController editController;
  final Function(String?) onAddTask;

  const DesktopColumnView({
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
  State<DesktopColumnView> createState() => _DesktopColumnViewState();
}

class _DesktopColumnViewState extends State<DesktopColumnView> {
  List<Task?> _columnHierarchy = [null];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToSubtasks(Task parentTask) {
    setState(() {
      final existingIndex = _columnHierarchy.indexOf(parentTask);
      if (existingIndex != -1) {
        // Task already exists in hierarchy, trim to that point
        _columnHierarchy = _columnHierarchy.sublist(0, existingIndex + 1);
      } else {
        // Check if this is a root-level task (parent is null)
        if (parentTask.parentId == null) {
          // Reset hierarchy for root-level tasks
          _columnHierarchy = [null];
        } else {
          // For nested tasks, find the correct insertion point
          // Remove any columns that are not ancestors of this task
          List<Task?> newHierarchy = [null];
          Task? currentTask = parentTask;
          List<Task> ancestors = [];

          // Build ancestor chain
          while (currentTask != null) {
            ancestors.insert(0, currentTask);
            currentTask = currentTask.parentId != null
                ? widget.taskManager.findTaskById(currentTask.parentId!)
                : null;
          }

          // Add ancestors to hierarchy (excluding the target task itself)
          for (int i = 0; i < ancestors.length - 1; i++) {
            newHierarchy.add(ancestors[i]);
          }

          _columnHierarchy = newHierarchy;
        }
        _columnHierarchy.add(parentTask);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _navigateToColumn(int columnIndex) {
    setState(() {
      _columnHierarchy = _columnHierarchy.sublist(0, columnIndex + 1);
    });
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) {
    if (draggedTask.id == targetTask.id) return;

    try {
      widget.taskManager.moveTaskToParent(draggedTask.id, targetTask.id);
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
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildColumns(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildColumns() {
    List<Widget> columns = [];

    for (int i = 0; i < _columnHierarchy.length; i++) {
      final parent = _columnHierarchy[i];
      final tasks = widget.taskManager.getTasksAtLevel(parent?.id);
      final isLastColumn = i == _columnHierarchy.length - 1;

      columns.add(
        _buildColumn(
          tasks: tasks,
          parent: parent,
          columnIndex: i,
          isLastColumn: isLastColumn,
        ),
      );

      if (!isLastColumn) {
        columns.add(
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        );
      }
    }

    return columns;
  }

  Widget _buildColumn({
    required List<Task> tasks,
    required Task? parent,
    required int columnIndex,
    required bool isLastColumn,
  }) {
    return Container(
      width: 350,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumnHeader(parent, columnIndex),
          Expanded(
            child: DragTarget<Task>(
              onWillAccept: (data) => data != null,
              onAccept: (draggedTask) {
                try {
                  widget.taskManager
                      .moveTaskToParent(draggedTask.id, parent?.id);
                  setState(() {});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(parent != null
                          ? '"${draggedTask.title}" moved to "${parent.title}"'
                          : '"${draggedTask.title}" moved to root level'),
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
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.1)
                        : null,
                  ),
                  child: ListView.builder(
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
                                isCompleted: !task.isCompleted),
                            onEditComplete: widget.onFinishEditing,
                            isDragTarget: candidateData.isNotEmpty,
                            onDragAccept: (draggedTask) =>
                                _onTaskDrop(draggedTask, task),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(Task? parent, int columnIndex) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (columnIndex > 0)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _navigateToColumn(columnIndex - 1),
              tooltip: 'Go back',
            ),
          Expanded(
            child: Text(
              parent?.title ?? 'All Tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (parent != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '${parent.subtaskCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => widget.onAddTask(parent?.id),
            tooltip: parent != null
                ? 'Add subtask to ${parent.title}'
                : 'Add new task',
          ),
        ],
      ),
    );
  }
}
