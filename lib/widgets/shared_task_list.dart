import 'package:flutter/material.dart';
import '../models/task.dart';
import 'task_tile.dart';
import 'zero_state.dart';

class SharedTaskList extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final shouldShowAddTask = showAddTask && 
        addTaskParentId == parent?.id.toString();

    if (tasks.isEmpty && !shouldShowAddTask) {
      return ZeroState(
        parentTitle: parent?.title,
        onAddTask: () => onAddTask(
          parent?.id.toString(),
          parent?.title,
          columnIndex: isDesktop ? 0 : null,
        ),
        isDesktop: isDesktop,
      );
    }

    return ListView.builder(
      itemCount: tasks.length + (shouldShowAddTask ? 1 : 0),
      itemBuilder: (context, index) {
        if (shouldShowAddTask && index == tasks.length) {
          return AddTaskTile(
            parentId: parent?.id.toString(),
            parentTitle: parent?.title,
            onAddTask: onCreateTask,
            onAddMultipleTasks: onAddMultipleTasks,
            onCancel: onHideAddTask,
          );
        }

        final task = tasks[index];
        return DragTarget<Task>(
          onWillAcceptWithDetails: (details) => details.data.id != task.id,
          onAcceptWithDetails: (details) => onTaskDrop(details.data, task),
          builder: (context, candidateData, rejectedData) {
            return TaskTile(
              key: ValueKey(task.id),
              task: task,
              isEditing: editingTaskId == task.id,
              isSelected: isSelected?.call(task) ?? false,
              editController: editController,
              onTap: () => onTaskTap(task),
              onEdit: () => onStartEditing(task),
              onDelete: () => onDeleteTask(task.id),
              onCheckboxChanged: (_) => onUpdateTask(
                task.id,
                isCompleted: !task.isCompleted,
              ),
              onEditComplete: onFinishEditing,
              onEditCancel: onEditCancel,
              isDragTarget: candidateData.isNotEmpty,
              onDragAccept: (draggedTask) => onTaskDrop(draggedTask, task),
            );
          },
        );
      },
    );
  }
} 