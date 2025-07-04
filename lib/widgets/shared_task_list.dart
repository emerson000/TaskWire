import 'package:flutter/material.dart';
import '../models/task.dart';
import 'task_tile.dart';
import 'zero_state.dart';

class SharedTaskList extends StatefulWidget {
  final List<Task> tasks;
  final Task? parent;
  final int? editingTaskId;
  final TextEditingController editController;
  final bool showAddTask;
  final String? addTaskParentId;
  final Function(Task) onTaskTap;
  final Function(Task) onStartEditing;
  final Function(int) onDeleteTask;
  final Function(int, {String? title, bool? isCompleted}) onUpdateTask;
  final Function() onFinishEditing;
  final VoidCallback? onEditCancel;
  final Function(Task, Task) onTaskDrop;
  final Function(String, String?) onCreateTask;
  final Function(List<String>, String?)? onAddMultipleTasks;
  final VoidCallback onHideAddTask;
  final Function(String?, String?, {int? columnIndex}) onAddTask;
  final bool isDesktop;
  final bool Function(Task)? isSelected;
  final int? targetColumnIndex;
  final int? columnIndex;
  final Function(String?, int, int)? onReorderTasks;
  final Function(List<Task>)? onOptimisticReorder;

  const SharedTaskList({
    super.key,
    required this.tasks,
    this.parent,
    this.editingTaskId,
    required this.editController,
    this.showAddTask = false,
    this.addTaskParentId,
    required this.onTaskTap,
    required this.onStartEditing,
    required this.onDeleteTask,
    required this.onUpdateTask,
    required this.onFinishEditing,
    this.onEditCancel,
    required this.onTaskDrop,
    required this.onCreateTask,
    this.onAddMultipleTasks,
    required this.onHideAddTask,
    required this.onAddTask,
    this.isDesktop = false,
    this.isSelected,
    this.targetColumnIndex,
    this.columnIndex,
    this.onReorderTasks,
    this.onOptimisticReorder,
  });

  @override
  State<SharedTaskList> createState() => _SharedTaskListState();
}

class _SharedTaskListState extends State<SharedTaskList> {
  List<Task> _displayTasks = [];

  @override
  void initState() {
    super.initState();
    _displayTasks = List.from(widget.tasks);
  }

  @override
  void didUpdateWidget(SharedTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks != oldWidget.tasks) {
      _displayTasks = List.from(widget.tasks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowAddTask = widget.isDesktop 
        ? widget.showAddTask && widget.targetColumnIndex == widget.columnIndex
        : widget.showAddTask && widget.addTaskParentId == widget.parent?.id.toString();

    if (_displayTasks.isEmpty && !shouldShowAddTask) {
      return ZeroState(
        parentTitle: widget.parent?.title,
        onAddTask: () => widget.onAddTask(
          widget.parent?.id.toString(),
          widget.parent?.title,
          columnIndex: widget.isDesktop ? widget.columnIndex : null,
        ),
        isDesktop: widget.isDesktop,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _displayTasks.length,
            onReorder: (oldIndex, newIndex) {
              if (widget.onReorderTasks != null) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                
                setState(() {
                  final task = _displayTasks.removeAt(oldIndex);
                  _displayTasks.insert(newIndex, task);
                });
                
                if (widget.onOptimisticReorder != null) {
                  widget.onOptimisticReorder!(_displayTasks);
                }
                
                widget.onReorderTasks!(widget.parent?.id.toString(), oldIndex, newIndex);
              }
            },
            itemBuilder: (context, index) {
              final task = _displayTasks[index];
              return DragTarget<Task>(
                key: ValueKey(task.id),
                onWillAcceptWithDetails: (details) => details.data.id != task.id,
                onAcceptWithDetails: (details) => widget.onTaskDrop(details.data, task),
                builder: (context, candidateData, rejectedData) {
                  return TaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    isEditing: widget.editingTaskId == task.id,
                    isSelected: widget.isSelected?.call(task) ?? false,
                    editController: widget.editController,
                    onTap: () => widget.onTaskTap(task),
                    onEdit: () => widget.onStartEditing(task),
                    onDelete: () => widget.onDeleteTask(task.id),
                    onCheckboxChanged: (_) => widget.onUpdateTask(
                      task.id,
                      isCompleted: !task.isCompleted,
                    ),
                    onEditComplete: widget.onFinishEditing,
                    onEditCancel: widget.onEditCancel,
                    isDragTarget: candidateData.isNotEmpty,
                    onDragAccept: (draggedTask) => widget.onTaskDrop(draggedTask, task),
                    reorderIndex: index,
                  );
                },
              );
            },
          ),
        ),
        if (shouldShowAddTask)
          AddTaskTile(
            parentId: widget.parent?.id.toString(),
            parentTitle: widget.parent?.title,
            onAddTask: widget.onCreateTask,
            onAddMultipleTasks: widget.onAddMultipleTasks,
            onCancel: widget.onHideAddTask,
          ),
      ],
    );
  }
} 