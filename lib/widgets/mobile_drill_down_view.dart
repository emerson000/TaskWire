import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/printer.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import 'task_tile.dart';
import 'breadcrumb_navigation.dart';

class MobileDrillDownView extends StatefulWidget {
  final TaskManager taskManager;
  final PrinterService printerService;
  final Function(int, {String? title, bool? isCompleted}) onUpdateTask;
  final Function(int) onDeleteTask;
  final Function(Task) onStartEditing;
  final Function() onFinishEditing;
  final int? editingTaskId;
  final TextEditingController editController;
  final Function(String?) onAddTask;
  final VoidCallback? onRefresh;
  final int? refreshKey;

  const MobileDrillDownView({
    super.key,
    required this.taskManager,
    required this.printerService,
    required this.onUpdateTask,
    required this.onDeleteTask,
    required this.onStartEditing,
    required this.onFinishEditing,
    this.editingTaskId,
    required this.editController,
    required this.onAddTask,
    this.onRefresh,
    this.refreshKey,
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

  Future<void> _printCurrentLevel() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id?.toString(),
      );

      final printers = await widget.printerService.getPrinters();
      if (printers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printers available. Please add a printer first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final connectedPrinters = printers.where((p) => p.isConnected).toList();
      if (connectedPrinters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No connected printers. Please connect a printer first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? selectedPrinterId;
      if (connectedPrinters.length == 1) {
        selectedPrinterId = connectedPrinters.first.id;
      } else {
        selectedPrinterId = await _showPrinterSelectionDialog(
          connectedPrinters,
        );
        if (selectedPrinterId == null) return;
      }

      final levelTitle = _currentParent?.title ?? 'All Tasks';
      final success = await widget.printerService.printColumn(
        selectedPrinterId!,
        tasks,
        columnTitle: levelTitle,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Level "${levelTitle}" printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to print level'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing level: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printCurrentLevelWithSubtasks() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id?.toString(),
      );

      final printers = await widget.printerService.getPrinters();
      if (printers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printers available. Please add a printer first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final connectedPrinters = printers.where((p) => p.isConnected).toList();
      if (connectedPrinters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No connected printers. Please connect a printer first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? selectedPrinterId;
      if (connectedPrinters.length == 1) {
        selectedPrinterId = connectedPrinters.first.id;
      } else {
        selectedPrinterId = await _showPrinterSelectionDialog(
          connectedPrinters,
        );
        if (selectedPrinterId == null) return;
      }

      final levelTitle = _currentParent?.title ?? 'All Tasks';
      final success = await widget.printerService.printColumnWithSubtasks(
        selectedPrinterId!,
        tasks,
        columnTitle: levelTitle,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Level "${levelTitle}" with subtasks printed successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to print level with subtasks'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing level with subtasks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showPrinterSelectionDialog(List<Printer> printers) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: printers
              .map(
                (printer) => ListTile(
                  title: Text(printer.name),
                  subtitle: Text(
                    '${printer.type.name.toUpperCase()}: ${printer.address}',
                  ),
                  onTap: () => Navigator.of(context).pop(printer.id),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  @override
  void didUpdateWidget(MobileDrillDownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.taskManager != oldWidget.taskManager ||
        widget.editingTaskId != oldWidget.editingTaskId ||
        widget.refreshKey != oldWidget.refreshKey) {
      setState(() {
        _refreshTasks();
      });
    }
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
      await widget.taskManager.moveTaskToParent(
        draggedTask.id,
        targetParent?.id,
      );

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentParent != null
                            ? 'Subtasks of "${_currentParent!.title}"'
                            : 'All Tasks',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.print, size: 20),
                      tooltip: 'Print options',
                      onSelected: (value) {
                        switch (value) {
                          case 'print_level':
                            _printCurrentLevel();
                            break;
                          case 'print_with_subtasks':
                            _printCurrentLevelWithSubtasks();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'print_level',
                          child: Row(
                            children: [
                              Icon(Icons.print, size: 16),
                              SizedBox(width: 8),
                              Text('Print Level'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'print_with_subtasks',
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Print Level & Subtasks'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () =>
                          widget.onAddTask(_currentParent?.id?.toString()),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        _currentParent != null ? 'Add Subtask' : 'Add Task',
                      ),
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
