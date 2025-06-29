import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';

abstract class TaskViewCallbacks {
  Function(int, {String? title, bool? isCompleted}) get onUpdateTask;
  Function(int) get onDeleteTask;
  Function(Task) get onStartEditing;
  Function() get onFinishEditing;
  VoidCallback? get onEditCancel;
  Function(String?, String?, {int? columnIndex}) get onAddTask;
  Function(String, String?) get onCreateTask;
  Function(List<String>, String?)? get onAddMultipleTasks;
  VoidCallback get onHideAddTask;
}

abstract class TaskViewState {
  TaskManager get taskManager;
  PrinterService get printerService;
  int? get editingTaskId;
  TextEditingController get editController;
  bool get showAddTask;
  String? get addTaskParentId;
  String? get addTaskParentTitle;
  int? get refreshKey;
}

class TaskViewConfig {
  final TaskManager taskManager;
  final PrinterService printerService;
  final Function(int, {String? title, bool? isCompleted}) onUpdateTask;
  final Function(int) onDeleteTask;
  final Function(Task) onStartEditing;
  final Function() onFinishEditing;
  final VoidCallback? onEditCancel;
  final int? editingTaskId;
  final TextEditingController editController;
  final Function(String?, String?, {int? columnIndex}) onAddTask;
  final Function(String, String?) onCreateTask;
  final Function(List<String>, String?)? onAddMultipleTasks;
  final VoidCallback onHideAddTask;
  final bool showAddTask;
  final String? addTaskParentId;
  final String? addTaskParentTitle;
  final int? refreshKey;

  const TaskViewConfig({
    required this.taskManager,
    required this.printerService,
    required this.onUpdateTask,
    required this.onDeleteTask,
    required this.onStartEditing,
    required this.onFinishEditing,
    this.onEditCancel,
    this.editingTaskId,
    required this.editController,
    required this.onAddTask,
    required this.onCreateTask,
    this.onAddMultipleTasks,
    required this.onHideAddTask,
    required this.showAddTask,
    this.addTaskParentId,
    this.addTaskParentTitle,
    this.refreshKey,
  });
} 