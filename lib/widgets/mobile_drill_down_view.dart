import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import 'task_tile.dart';
import 'breadcrumb_navigation.dart';
import 'print_menu.dart';
import 'zero_state.dart';

class MobileDrillDownView extends StatefulWidget {
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
  final VoidCallback onHideAddTask;
  final bool showAddTask;
  final String? addTaskParentId;
  final String? addTaskParentTitle;
  final VoidCallback? onRefresh;
  final int? refreshKey;
  final Function(Task?, int)? onParentChange;

  const MobileDrillDownView({
    super.key,
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
    required this.onHideAddTask,
    required this.showAddTask,
    this.addTaskParentId,
    this.addTaskParentTitle,
    this.onRefresh,
    this.refreshKey,
    this.onParentChange,
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
    return widget.taskManager.getTasksAtLevel(_currentParent?.id.toString());
  }

  void _refreshTasks() {
    _currentTasksFuture = _getCurrentTasks();
  }

  Future<void> _printCurrentLevel() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id.toString(),
      );

      if (!mounted) return;

      final levelTitle = _currentParent?.title ?? 'All Tasks';
      final hierarchyPath = _buildHierarchyPath();
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: levelTitle,
        hierarchyPath: hierarchyPath,
        includeSubtasks: false,
        context: context,
        printType: 'checklist',
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
          content: Text('Error printing level: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printCurrentLevelWithSubtasks() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id.toString(),
      );

      if (!mounted) return;

      final levelTitle = _currentParent?.title ?? 'All Tasks';
      final hierarchyPath = _buildHierarchyPath();
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: levelTitle,
        hierarchyPath: hierarchyPath,
        includeSubtasks: true,
        context: context,
        printType: 'checklist',
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
          content: Text('Error printing level with subtasks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printIndividualSlips() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id.toString(),
      );

      if (!mounted) return;

      final hierarchyPath = _buildHierarchyPathForIndividualSlips();
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: hierarchyPath,
        includeSubtasks: false,
        context: context,
        printType: 'individual_slips',
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
          content: Text('Error printing individual slips: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printIndividualSlipsWithSubtasks() async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        _currentParent?.id.toString(),
      );

      if (!mounted) return;

      final hierarchyPath = _buildHierarchyPathForIndividualSlips();
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: hierarchyPath,
        includeSubtasks: true,
        context: context,
        printType: 'individual_slips',
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
          content: Text('Error printing individual slips with subtasks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _buildHierarchyPath() {
    if (_currentParent == null) {
      return 'All Tasks';
    }
    
    final pathParts = <String>[];
    
    for (int i = 0; i < _breadcrumbs.length - 1; i++) {
      final task = _breadcrumbs[i];
      if (task != null) {
        pathParts.add(task.title);
      }
    }
    
    if (pathParts.isEmpty) {
      return 'All Tasks';
    }
    
    return pathParts.join(' > ');
  }

  String _buildHierarchyPathForIndividualSlips() {
    if (_currentParent == null) {
      return 'All Tasks';
    }
    
    final pathParts = <String>[];
    
    for (final task in _breadcrumbs) {
      if (task != null) {
        pathParts.add(task.title);
      }
    }
    
    if (pathParts.isEmpty) {
      return 'All Tasks';
    }
    
    return pathParts.join(' > ');
  }

  @override
  void initState() {
    super.initState();
    _refreshTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onParentChange?.call(null, 0);
    });
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
    widget.onParentChange?.call(parentTask, _breadcrumbs.length - 1);
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
    widget.onParentChange?.call(targetParent, targetParent != null ? _breadcrumbs.indexOf(targetParent) : 0);
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PrintMenu(
                      onPrintLevel: _printCurrentLevel,
                      onPrintWithSubtasks: _printCurrentLevelWithSubtasks,
                      onPrintIndividualSlips: _printIndividualSlips,
                      onPrintIndividualSlipsWithSubtasks: _printIndividualSlipsWithSubtasks,
                      type: PrintMenuType.popup,
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () =>
                          widget.onAddTask(_currentParent?.id.toString(), _currentParent?.title, columnIndex: null),
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
                    ).colorScheme.primaryContainer.withValues(alpha: 0.1),
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
                      return tasks.isEmpty && !(widget.showAddTask && widget.addTaskParentId == _currentParent?.id.toString())
                          ? ZeroState(
                              parentTitle: _currentParent?.title,
                              onAddTask: () => widget.onAddTask(
                                _currentParent?.id.toString(),
                                _currentParent?.title,
                                columnIndex: null,
                              ),
                              isDesktop: false,
                            )
                          : ListView.builder(
                              itemCount: tasks.length + (widget.showAddTask && widget.addTaskParentId == _currentParent?.id.toString() ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (widget.showAddTask && widget.addTaskParentId == _currentParent?.id.toString() && index == tasks.length) {
                                  return AddTaskTile(
                                    parentId: _currentParent?.id.toString(),
                                    parentTitle: _currentParent?.title,
                                    onAddTask: widget.onCreateTask,
                                    onCancel: widget.onHideAddTask,
                                  );
                                }
                                
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
                                      onEditCancel: widget.onEditCancel,
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
