import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import '../services/preference_service.dart';
import '../services/logging_service.dart';
import 'print_menu.dart';
import 'task_view_mixin.dart';
import 'shared_task_list.dart';

class DesktopColumnView extends StatefulWidget {
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
  final bool showAddTask;
  final String? addTaskParentId;
  final String? addTaskParentTitle;
  final int? addTaskColumnIndex;
  final VoidCallback onHideAddTask;
  final Function(Task?, int)? onColumnChange;
  final int? refreshKey;

  const DesktopColumnView({
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
    required this.showAddTask,
    this.addTaskParentId,
    this.addTaskParentTitle,
    this.addTaskColumnIndex,
    required this.onHideAddTask,
    this.onColumnChange,
    this.refreshKey,
  });

  @override
  State<DesktopColumnView> createState() => _DesktopColumnViewState();
}

class _DesktopColumnViewState extends State<DesktopColumnView> 
    with TaskViewMixin {
  List<Task?> _columnHierarchy = [null];
  final Map<int, double> _columnWidths = <int, double>{};
  final Map<int, bool> _resizeHandleHovered = <int, bool>{};
  final ScrollController _scrollController = ScrollController();
  final double _defaultColumnWidth = 300.0;
  static const double _minColumnWidth = 200.0;
  static const double _maxColumnWidth = 600.0;
  final Map<int, bool> _resizeHandleDragging = <int, bool>{};
  final Map<String, List<Task>> _optimisticTasks = {};

  @override
  TaskManager get taskManager => widget.taskManager;

  @override
  PrinterService get printerService => widget.printerService;

  @override
  void didUpdateWidget(covariant DesktopColumnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _validateAndCleanupHierarchy();
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadColumnWidths();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onColumnChange?.call(null, 0);
    });
  }

  Future<void> _loadColumnWidths() async {
    try {
      final savedWidths = await PreferenceService.getAllColumnWidths();
      setState(() {
        _columnWidths.addAll(savedWidths);
      });
    } catch (e) {
      LoggingService.error('Error loading column widths: $e');
    }
  }

  Future<void> _saveColumnWidth(int columnIndex, double width) async {
    try {
      await PreferenceService.saveColumnWidth(columnIndex, width);
    } catch (e) {
      // Silently handle save errors
    }
  }

  Future<void> _navigateToSubtasks(Task parentTask) async {
    final existingIndex = _columnHierarchy.indexWhere(
      (task) => task?.id == parentTask.id,
    );

    if (existingIndex != -1) {
      _columnHierarchy = _columnHierarchy.sublist(0, existingIndex + 1);
    } else {
      final newHierarchy = <Task?>[null];

      var currentTask = await widget.taskManager.findTaskById(parentTask.id);
      final ancestors = <Task>[];
      if (currentTask != null) {
        while (currentTask?.parentId != null) {
          final parent = await widget.taskManager.findTaskById(
            currentTask!.parentId!,
          );
          if (parent != null) {
            ancestors.insert(0, parent);
            currentTask = parent;
          } else {
            break;
          }
        }
      }
      newHierarchy.addAll(ancestors);
      newHierarchy.add(parentTask);
      _columnHierarchy = newHierarchy;

      _resetColumnWidths();
    }

    widget.onColumnChange?.call(parentTask, _columnHierarchy.length - 1);

    if (existingIndex == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      });
    }
  }

  void _navigateToColumn(int columnIndex) {
    setState(() {
      _columnHierarchy = _columnHierarchy.sublist(0, columnIndex + 1);
      _resetColumnWidths();
    });
    final currentParent = _columnHierarchy[columnIndex];
    widget.onColumnChange?.call(currentParent, columnIndex);
  }

  void _resetColumnWidths() {
    // Don't clear the widths when resetting, just keep the current ones
  }

  Future<void> _printColumn(Task? parent) async {
    final columnIndex = _columnHierarchy.indexOf(parent);
    await printLevel(
      parent: parent,
      hierarchyPath: buildHierarchyPath(_columnHierarchy.sublist(0, columnIndex + 1)),
      includeSubtasks: false,
      printType: 'checklist',
    );
  }

  Future<void> _printColumnWithSubtasks(Task? parent) async {
    final columnIndex = _columnHierarchy.indexOf(parent);
    await printLevel(
      parent: parent,
      hierarchyPath: buildHierarchyPath(_columnHierarchy.sublist(0, columnIndex + 1)),
      includeSubtasks: true,
      printType: 'checklist',
    );
  }

  Future<void> _printIndividualSlips(Task? parent) async {
    final columnIndex = _columnHierarchy.indexOf(parent);
    await printLevel(
      parent: parent,
      hierarchyPath: buildHierarchyPath(_columnHierarchy.sublist(0, columnIndex + 1), includeCurrentLevel: true),
      includeSubtasks: false,
      printType: 'individual_slips',
    );
  }

  Future<void> _printIndividualSlipsWithSubtasks(Task? parent) async {
    final columnIndex = _columnHierarchy.indexOf(parent);
    await printLevel(
      parent: parent,
      hierarchyPath: buildHierarchyPath(_columnHierarchy.sublist(0, columnIndex + 1), includeCurrentLevel: true),
      includeSubtasks: true,
      printType: 'individual_slips',
    );
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) async {
    if (await _wouldCreateRecursion(draggedTask, targetTask)) {
      _showRecursionError();
      return;
    }
    
    _optimisticTasks.clear();
    await handleTaskDrop(
      draggedTask: draggedTask,
      targetTask: targetTask,
      onRefresh: () => setState(() {}),
    );
  }

  void _onParentDrop(Task draggedTask, Task? targetParent) async {
    if (await _wouldCreateRecursion(draggedTask, targetParent)) {
      _showRecursionError();
      return;
    }
    
    _optimisticTasks.clear();
    await handleParentDrop(
      draggedTask: draggedTask,
      targetParent: targetParent,
      onRefresh: () => setState(() {}),
    );
  }

  Future<bool> _wouldCreateRecursion(Task draggedTask, Task? targetParent) async {
    if (targetParent == null) return false;
    if (draggedTask.id == targetParent.id) return true;
    
    var currentParent = targetParent;
    while (currentParent.parentId != null) {
      if (currentParent.parentId == draggedTask.id) {
        return true;
      }
      final parent = await widget.taskManager.findTaskById(currentParent.parentId!);
      if (parent == null) break;
      currentParent = parent;
    }
    
    return false;
  }

  void _showRecursionError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cannot move task: would create a circular reference',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _onReorderTasks(String? parentId, int oldIndex, int newIndex) async {
    await widget.taskManager.reorderTasks(parentId, oldIndex, newIndex);
    _optimisticTasks.remove(parentId);
    setState(() {});
  }

  void _onOptimisticReorder(String? parentId, List<Task> reorderedTasks) {
    if (parentId != null) {
      _optimisticTasks[parentId] = reorderedTasks;
    } else {
      _optimisticTasks['null'] = reorderedTasks;
    }
    setState(() {});
  }

  Future<List<Widget>> _buildColumns() async {
    List<Widget> columns = [];

    for (int i = 0; i < _columnHierarchy.length; i++) {
      final parent = _columnHierarchy[i];
      final tasks = await widget.taskManager.getTasksAtLevel(
        parent?.id.toString(),
      );
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
        columns.add(_buildResizeHandle(i));
      }
    }

    return columns;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: Scrollbar(
              scrollbarOrientation: ScrollbarOrientation.bottom,
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: FutureBuilder<List<Widget>>(
                  future: _buildColumns(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required List<Task> tasks,
    required Task? parent,
    required int columnIndex,
    required bool isLastColumn,
  }) {
    final parentId = parent?.id.toString();
    final optimisticTasks = _optimisticTasks[parentId ?? 'null'];
    final displayTasks = optimisticTasks ?? tasks;
    
    return SizedBox(
      width: _columnWidths[columnIndex] ?? _defaultColumnWidth,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumnHeader(parent, columnIndex),
          Expanded(
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) => _onParentDrop(details.data, parent),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: SharedTaskList(
                    tasks: displayTasks,
                    parent: parent,
                    editingTaskId: widget.editingTaskId,
                    editController: widget.editController,
                    showAddTask: widget.showAddTask,
                    addTaskParentId: widget.addTaskColumnIndex == columnIndex 
                        ? parent?.id.toString() 
                        : null,
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
                    isDesktop: true,
                    isSelected: (task) => _columnHierarchy.contains(task),
                    targetColumnIndex: widget.addTaskColumnIndex,
                    columnIndex: columnIndex,
                    onReorderTasks: (parentId, oldIndex, newIndex) => 
                        _onReorderTasks(parentId, oldIndex, newIndex),
                    onOptimisticReorder: (reorderedTasks) => 
                        _onOptimisticReorder(parentId, reorderedTasks),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (columnIndex > 0)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _navigateToColumn(columnIndex - 1),
              tooltip: 'Go back',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8.0,
                children: [
                  Text(
                    parent?.title ?? 'All Tasks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (parent != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        '${parent.subtaskCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PrintMenu(
            onPrintLevel: () => _printColumn(parent),
            onPrintWithSubtasks: () => _printColumnWithSubtasks(parent),
            onPrintIndividualSlips: () => _printIndividualSlips(parent),
            onPrintIndividualSlipsWithSubtasks: () =>
                _printIndividualSlipsWithSubtasks(parent),
            type: PrintMenuType.menuAnchor,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => widget.onAddTask(
              null,
              parent?.id.toString(),
              columnIndex: columnIndex,
            ),
            tooltip: parent != null
                ? 'Add subtask to ${parent.title}'
                : 'Add new task',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(int columnIndex) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _resizeHandleHovered[columnIndex] = true),
      onExit: (_) => setState(() => _resizeHandleHovered[columnIndex] = false),
      child: Tooltip(
        message: 'Drag to resize • Double-click to reset',
        child: GestureDetector(
          onPanStart: (_) => setState(() => _resizeHandleDragging[columnIndex] = true),
          onPanEnd: (_) {
            setState(() => _resizeHandleDragging[columnIndex] = false);
            final currentWidth =
                _columnWidths[columnIndex] ?? _defaultColumnWidth;
            _saveColumnWidth(columnIndex, currentWidth);
          },
          onPanUpdate: (details) {
            setState(() {
              final currentWidth =
                  _columnWidths[columnIndex] ?? _defaultColumnWidth;
              final newWidth = (currentWidth + details.delta.dx).clamp(
                _minColumnWidth,
                _maxColumnWidth,
              );
              _columnWidths[columnIndex] = newWidth;
            });
          },
          onDoubleTap: () {
            setState(() {
              _columnWidths.remove(columnIndex);
              PreferenceService.clearColumnWidth(columnIndex);
            });
          },
          child: Container(
            width: 24,
            color: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 1,
                    height: double.infinity,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _resizeHandleDragging[columnIndex] == true ? 3 : 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _resizeHandleHovered[columnIndex] == true
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                          : _resizeHandleDragging[columnIndex] == true
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _validateAndCleanupHierarchy() async {
    final validHierarchy = <Task?>[null];
    
    for (int i = 1; i < _columnHierarchy.length; i++) {
      final task = _columnHierarchy[i];
      if (task != null) {
        final existingTask = await widget.taskManager.findTaskById(task.id);
        if (existingTask != null) {
          validHierarchy.add(existingTask);
        } else {
          break;
        }
      }
    }
    
    if (validHierarchy.length != _columnHierarchy.length) {
      _columnHierarchy = validHierarchy;
      final currentParent = _columnHierarchy.isNotEmpty ? _columnHierarchy.last : null;
      final currentIndex = _columnHierarchy.length - 1;
      widget.onColumnChange?.call(currentParent, currentIndex);
    }
  }
}
