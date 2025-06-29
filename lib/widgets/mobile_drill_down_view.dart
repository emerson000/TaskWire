import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import 'task_tile.dart';
import 'breadcrumb_navigation.dart';
import 'print_menu.dart';
import 'zero_state.dart';
import '../services/logging_service.dart';

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
  final Function(List<String>, String?)? onAddMultipleTasks;
  final VoidCallback onHideAddTask;
  final bool showAddTask;
  final String? addTaskParentId;
  final String? addTaskParentTitle;
  final VoidCallback? onRefresh;
  final int? refreshKey;
  final Function(Task?, int)? onParentChange;
  final VoidCallback? onReorder;

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
    this.onAddMultipleTasks,
    required this.onHideAddTask,
    required this.showAddTask,
    this.addTaskParentId,
    this.addTaskParentTitle,
    this.onRefresh,
    this.refreshKey,
    this.onParentChange,
    this.onReorder,
  });

  @override
  State<MobileDrillDownView> createState() => _MobileDrillDownViewState();
}

class _MobileDrillDownViewState extends State<MobileDrillDownView> {
  Task? _currentParent;
  List<Task?> _breadcrumbs = [null];
  bool _isDragging = false;
  List<Task>? _tasks;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onParentChange?.call(_currentParent, 0);
    });
  }

  @override
  void didUpdateWidget(covariant MobileDrillDownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey && !_isLoading) {
      _fetchTasks();
    }
  }

  Future<void> _fetchTasks() async {
    if (_isLoading) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tasks =
          await widget.taskManager.getTasksAtLevel(_currentParent?.id.toString());
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      LoggingService.error('Error fetching mobile tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  void _navigateToSubtasks(Task parentTask) {
    setState(() {
      if (!_breadcrumbs.contains(parentTask)) {
        _breadcrumbs.add(parentTask);
      }
      _currentParent = parentTask;
      _fetchTasks();
      widget.onParentChange?.call(_currentParent, _breadcrumbs.length - 1);
    });
  }

  void _navigateUp(int index) {
    setState(() {
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
      _currentParent = _breadcrumbs[index];
      _fetchTasks();
      widget.onParentChange?.call(_currentParent, index);
    });
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) async {
    if (draggedTask.id == targetTask.id) return;

    try {
      await widget.taskManager.moveTaskToParent(draggedTask.id, targetTask.id);

      if (mounted) {
        setState(() {
          _fetchTasks();
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

  Future<void> _onBreadcrumbDrop(Task draggedTask, Task? targetParent) async {
    try {
      await widget.taskManager.moveTaskToParent(
        draggedTask.id,
        targetParent?.id,
      );

      if (mounted) {
        setState(() {
          _fetchTasks();
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
      onWillAcceptWithDetails: (details) {
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
                onNavigate: (task) => _navigateUp(_breadcrumbs.indexOf(task)),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _tasks == null
                          ? Center(child: Text('Error loading tasks.'))
                          : _tasks!.isEmpty &&
                                  !(widget.showAddTask &&
                                      widget.addTaskParentId ==
                                          _currentParent?.id.toString())
                              ? ZeroState(
                                  parentTitle: _currentParent?.title,
                                  onAddTask: () => widget.onAddTask(
                                    _currentParent?.id.toString(),
                                    _currentParent?.title,
                                    columnIndex: null,
                                  ),
                                  isDesktop: false,
                                )
                              : ReorderableListView.builder(
                                  key: ValueKey('reorderable_list_mobile_${_currentParent?.id ?? 'root'}'),
                                  itemCount: _tasks!.length +
                                      (widget.showAddTask &&
                                              widget.addTaskParentId ==
                                                  _currentParent?.id.toString()
                                          ? 1
                                          : 0),
                                  itemBuilder: (context, index) {
                                    if (widget.showAddTask &&
                                        widget.addTaskParentId ==
                                            _currentParent?.id.toString() &&
                                        index == _tasks!.length) {
                                      return AddTaskTile(
                                        key: const ValueKey(
                                            'add_task_tile_mobile'),
                                        parentId: _currentParent?.id.toString(),
                                        parentTitle: _currentParent?.title,
                                        onAddTask: widget.onCreateTask,
                                        onAddMultipleTasks:
                                            widget.onAddMultipleTasks,
                                        onCancel: widget.onHideAddTask,
                                      );
                                    }

                                    final task = _tasks![index];
                                    return DragTarget<Task>(
                                      key: ValueKey(task.id),
                                      onWillAcceptWithDetails: (details) =>
                                          details.data.id != task.id,
                                      onAcceptWithDetails: (details) =>
                                          _onTaskDrop(details.data, task),
                                      builder: (context, candidateData,
                                          rejectedData) {
                                        return TaskTile(
                                          task: task,
                                          isEditing:
                                              widget.editingTaskId == task.id,
                                          editController:
                                              widget.editController,
                                          onTap: () =>
                                              _navigateToSubtasks(task),
                                          onEdit: () =>
                                              widget.onStartEditing(task),
                                          onDelete: () =>
                                              widget.onDeleteTask(task.id),
                                          onCheckboxChanged: (_) =>
                                              widget.onUpdateTask(
                                            task.id,
                                            isCompleted: !task.isCompleted,
                                          ),
                                          onEditComplete:
                                              widget.onFinishEditing,
                                          onEditCancel: widget.onEditCancel,
                                          isDragTarget:
                                              candidateData.isNotEmpty,
                                          onDragAccept: (draggedTask) =>
                                              _onTaskDrop(draggedTask, task),
                                          isReorderable: true,
                                          reorderableListViewIndex: index,
                                        );
                                      },
                                    );
                                  },
                                  buildDefaultDragHandles: false,
                                  onReorder:
                                      (int oldIndex, int newIndex) {
                                    final tasks = _tasks!;
                                    final hasAddTaskTile = widget.showAddTask &&
                                        widget.addTaskParentId ==
                                            _currentParent?.id.toString();
                                    final numActualTasks = tasks.length;

                                    if (oldIndex >= numActualTasks) return;

                                    if (hasAddTaskTile &&
                                        newIndex > numActualTasks) {
                                      newIndex = numActualTasks;
                                    }

                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }

                                    if (newIndex >= numActualTasks) {
                                      newIndex = numActualTasks - 1;
                                    }
                                    if (newIndex < 0) newIndex = 0;

                                    final taskToMove = tasks[oldIndex];

                                    setState(() {
                                      final newTaskList = List<Task>.from(tasks);
                                      newTaskList.removeAt(oldIndex);
                                      newTaskList.insert(newIndex, taskToMove);
                                      _tasks = newTaskList;
                                    });

                                    widget.taskManager
                                        .reorderTaskInList(
                                      _currentParent?.id,
                                      taskToMove.id,
                                      oldIndex,
                                      newIndex,
                                    )
                                        .then((_) {
                                      widget.onReorder?.call();
                                    }).catchError((e, s) {
                                      LoggingService.error(
                                          'Failed to reorder task: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: const Text(
                                              'Error updating order'),
                                          backgroundColor: Colors.red,
                                        ));
                                        _fetchTasks();
                                      }
                                    });
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
