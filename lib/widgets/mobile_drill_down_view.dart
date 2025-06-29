import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import 'breadcrumb_navigation.dart';
import 'print_menu.dart';
import 'task_view_mixin.dart';
import 'shared_task_list.dart';

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
  });

  @override
  State<MobileDrillDownView> createState() => _MobileDrillDownViewState();
}

class _MobileDrillDownViewState extends State<MobileDrillDownView> 
    with TaskViewMixin {
  Task? _currentParent;
  List<Task?> _breadcrumbs = [null];
  bool _isDragging = false;
  Future<List<Task>>? _currentTasksFuture;

  @override
  TaskManager get taskManager => widget.taskManager;

  @override
  PrinterService get printerService => widget.printerService;

  Future<List<Task>> _getCurrentTasks() {
    return widget.taskManager.getTasksAtLevel(_currentParent?.id.toString());
  }

  void _refreshTasks() {
    _currentTasksFuture = _getCurrentTasks();
  }

  Future<void> _printCurrentLevel() async {
    await printLevel(
      parent: _currentParent,
      hierarchyPath: buildHierarchyPath(_breadcrumbs),
      includeSubtasks: false,
      printType: 'checklist',
    );
  }

  Future<void> _printCurrentLevelWithSubtasks() async {
    await printLevel(
      parent: _currentParent,
      hierarchyPath: buildHierarchyPath(_breadcrumbs),
      includeSubtasks: true,
      printType: 'checklist',
    );
  }

  Future<void> _printIndividualSlips() async {
    await printLevel(
      parent: _currentParent,
      hierarchyPath: buildHierarchyPath(_breadcrumbs, includeCurrentLevel: true),
      includeSubtasks: false,
      printType: 'individual_slips',
    );
  }

  Future<void> _printIndividualSlipsWithSubtasks() async {
    await printLevel(
      parent: _currentParent,
      hierarchyPath: buildHierarchyPath(_breadcrumbs, includeCurrentLevel: true),
      includeSubtasks: true,
      printType: 'individual_slips',
    );
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
    await handleTaskDrop(
      draggedTask: draggedTask,
      targetTask: targetTask,
      onRefresh: () => setState(() => _refreshTasks()),
    );
  }

  void _onBreadcrumbDrop(Task draggedTask, Task? targetParent) async {
    await handleParentDrop(
      draggedTask: draggedTask,
      targetParent: targetParent,
      onRefresh: () => setState(() => _refreshTasks()),
    );
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
                      return SharedTaskList(
                        tasks: tasks,
                        parent: _currentParent,
                        editingTaskId: widget.editingTaskId,
                        editController: widget.editController,
                        showAddTask: widget.showAddTask,
                        addTaskParentId: widget.addTaskParentId,
                        onTaskTap: _navigateToSubtasks,
                        onStartEditing: widget.onStartEditing,
                        onDeleteTask: widget.onDeleteTask,
                        onUpdateTask: widget.onUpdateTask,
                        onFinishEditing: widget.onFinishEditing,
                        onEditCancel: widget.onEditCancel,
                        onTaskDrop: _onTaskDrop,
                        onCreateTask: widget.onCreateTask,
                        onAddMultipleTasks: widget.onAddMultipleTasks,
                        onHideAddTask: widget.onHideAddTask,
                        onAddTask: widget.onAddTask,
                        isDesktop: false,
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
