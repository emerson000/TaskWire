import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';

mixin TaskViewMixin<T extends StatefulWidget> on State<T> {
  TaskManager get taskManager;
  PrinterService get printerService;

  Future<void> printLevel({
    required Task? parent,
    required String hierarchyPath,
    required bool includeSubtasks,
    required String printType,
  }) async {
    try {
      final tasks = await taskManager.getTasksAtLevel(parent?.id.toString());
      final levelTitle = parent?.title ?? 'All Tasks';
      
      if (!mounted) return;
      
      final result = await printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: levelTitle,
        hierarchyPath: hierarchyPath,
        includeSubtasks: includeSubtasks,
        context: context,
        printType: printType,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(printType, includeSubtasks, e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getErrorMessage(String printType, bool includeSubtasks, dynamic error) {
    final action = printType == 'individual_slips' 
        ? 'printing individual slips'
        : 'printing level';
    final suffix = includeSubtasks ? ' with subtasks' : '';
    return 'Error $action$suffix: $error';
  }

  Future<void> handleTaskDrop({
    required Task draggedTask,
    required Task targetTask,
    required VoidCallback onRefresh,
  }) async {
    if (draggedTask.id == targetTask.id) return;

    try {
      await taskManager.moveTaskToParent(draggedTask.id, targetTask.id);

      if (mounted) {
        onRefresh();
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

  Future<void> handleParentDrop({
    required Task draggedTask,
    required Task? targetParent,
    required VoidCallback onRefresh,
  }) async {
    try {
      await taskManager.moveTaskToParent(draggedTask.id, targetParent?.id);

      if (mounted) {
        onRefresh();
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

  String buildHierarchyPath(List<Task?> hierarchy, {bool includeCurrentLevel = false}) {
    final pathParts = <String>[];
    final endIndex = includeCurrentLevel ? hierarchy.length : hierarchy.length - 1;
    
    for (int i = 0; i < endIndex; i++) {
      final task = hierarchy[i];
      if (task != null) {
        pathParts.add(task.title);
      }
    }
    
    return pathParts.isEmpty ? 'All Tasks' : pathParts.join(' > ');
  }
} 