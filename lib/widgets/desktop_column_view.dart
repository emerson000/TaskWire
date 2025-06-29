import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import '../services/preference_service.dart';
import '../services/logging_service.dart';
import 'task_tile.dart';
import 'print_menu.dart';
import 'zero_state.dart';

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

class _DesktopColumnViewState extends State<DesktopColumnView> {
  List<Task?> _columnHierarchy = [null];
  final ScrollController _scrollController = ScrollController();
  final Map<int, double> _columnWidths = <int, double>{};
  static const double _defaultColumnWidth = 350.0;
  static const double _minColumnWidth = 200.0;
  static const double _maxColumnWidth = 600.0;
  final Map<int, bool> _resizeHandleHovered = <int, bool>{};
  final Map<int, bool> _resizeHandleDragging = <int, bool>{};

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
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        parent?.id.toString(),
      );

      final columnTitle = parent?.title ?? 'All Tasks';
      final columnIndex = _columnHierarchy.indexOf(parent);
      final hierarchyPath = _buildHierarchyPath(columnIndex);
      
      if (!mounted) return;
      
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: columnTitle,
        hierarchyPath: hierarchyPath,
        includeSubtasks: false,
        context: context,
        printType: 'checklist',
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing column: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printColumnWithSubtasks(Task? parent) async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        parent?.id.toString(),
      );

      final columnTitle = parent?.title ?? 'All Tasks';
      final columnIndex = _columnHierarchy.indexOf(parent);
      final hierarchyPath = _buildHierarchyPath(columnIndex);
      
      if (!mounted) return;
      
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: columnTitle,
        hierarchyPath: hierarchyPath,
        includeSubtasks: true,
        context: context,
        printType: 'checklist',
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing column with subtasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printIndividualSlips(Task? parent) async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        parent?.id.toString(),
      );

      final columnIndex = _columnHierarchy.indexOf(parent);
      final hierarchyPath = _buildHierarchyPathForIndividualSlips(columnIndex);
      
      if (!mounted) return;
      
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: hierarchyPath,
        includeSubtasks: false,
        context: context,
        printType: 'individual_slips',
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing individual slips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printIndividualSlipsWithSubtasks(Task? parent) async {
    try {
      final tasks = await widget.taskManager.getTasksAtLevel(
        parent?.id.toString(),
      );

      final columnIndex = _columnHierarchy.indexOf(parent);
      final hierarchyPath = _buildHierarchyPathForIndividualSlips(columnIndex);
      
      if (!mounted) return;
      
      final result = await widget.printerService.printTasksWithPrinterSelection(
        tasks: tasks,
        levelTitle: hierarchyPath,
        includeSubtasks: true,
        context: context,
        printType: 'individual_slips',
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing individual slips with subtasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _buildHierarchyPath(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= _columnHierarchy.length) {
      return 'All Tasks';
    }

    final pathParts = <String>[];

    for (int i = 0; i < columnIndex; i++) {
      final task = _columnHierarchy[i];
      if (task != null) {
        pathParts.add(task.title);
      }
    }

    if (pathParts.isEmpty) {
      return 'All Tasks';
    }

    return pathParts.join(' > ');
  }

  String _buildHierarchyPathForIndividualSlips(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= _columnHierarchy.length) {
      return 'All Tasks';
    }

    final pathParts = <String>[];

    for (int i = 0; i <= columnIndex; i++) {
      final task = _columnHierarchy[i];
      if (task != null) {
        pathParts.add(task.title);
      }
    }

    if (pathParts.isEmpty) {
      return 'All Tasks';
    }

    return pathParts.join(' > ');
  }

  void _onTaskDrop(Task draggedTask, Task targetTask) {
    if (draggedTask.id == targetTask.id) return;

    try {
      widget.taskManager.moveTaskToParent(draggedTask.id, targetTask.id);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${draggedTask.title}" moved to "${targetTask.title}"',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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
              onAcceptWithDetails: (details) {
                try {
                  widget.taskManager.moveTaskToParent(
                    details.data.id,
                    parent?.id,
                  );
                  setState(() {});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        parent != null
                            ? '"${details.data.title}" moved to "${parent.title}"'
                            : '"${details.data.title}" moved to root level',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot move task: ${e.toString().replaceAll('ArgumentError: ', '')}',
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.1)
                        : null,
                  ),
                  child:
                      tasks.isEmpty &&
                          !(widget.showAddTask &&
                              widget.addTaskColumnIndex == columnIndex)
                      ? ZeroState(
                          parentTitle: parent?.title,
                          onAddTask: () => widget.onAddTask(
                            parent?.id.toString(),
                            parent?.title,
                            columnIndex: columnIndex,
                          ),
                          isDesktop: true,
                        )
                      : ReorderableListView.builder(
                          itemCount: tasks.length +
                              (widget.showAddTask &&
                                      widget.addTaskColumnIndex == columnIndex
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            // Key is crucial for ReorderableListView
                            if (widget.showAddTask &&
                                widget.addTaskColumnIndex == columnIndex &&
                                index == tasks.length) {
                              return AddTaskTile(
                                key: const ValueKey('add_task_tile_in_column'), // Unique key
                                parentId: parent?.id.toString(),
                                parentTitle: parent?.title,
                                onAddTask: widget.onCreateTask,
                                onAddMultipleTasks: widget.onAddMultipleTasks,
                                onCancel: widget.onHideAddTask,
                              );
                            }

                            final task = tasks[index];
                            final isSelected = _columnHierarchy.contains(task);
                            // Each item in ReorderableListView must have a unique Key.
                            // TaskTile itself is draggable for reparenting.
                            // The ReorderableListView handles the reorder drag.
                            return DragTarget<Task>(
                              key: ValueKey(task.id), // Ensure key is here for ReorderableListView
                              onWillAcceptWithDetails: (details) =>
                                  details.data.id != task.id && details.data.parentId != task.id, // Prevent dropping on self or direct parent
                              onAcceptWithDetails: (details) =>
                                  _onTaskDrop(details.data, task), // This is for reparenting
                              builder: (context, candidateData, rejectedData) {
                                return TaskTile(
                                  // Do not pass ValueKey(task.id) here if already on DragTarget parent
                                  task: task,
                                  isEditing: widget.editingTaskId == task.id,
                                  isSelected: isSelected,
                                  editController: widget.editController,
                                  onTap: () async =>
                                      await _navigateToSubtasks(task),
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
                                      _onTaskDrop(draggedTask, task), // For reparenting
                                  isReorderable: true, // Enable reorder handle
                                  reorderableListViewIndex: index, // Pass index
                                );
                              },
                            );
                          },
                          buildDefaultDragHandles: false, // Disable default handles
                          onReorder: (int oldIndex, int newIndex) async {
                            // Adjust newIndex if dragging an item downwards past the AddTaskTile
                            // This check is important because AddTaskTile is not a "real" task for reordering.
                            final hasAddTaskTile = widget.showAddTask && widget.addTaskColumnIndex == columnIndex;
                            final numActualTasks = tasks.length;

                            if (oldIndex >= numActualTasks) return; // Dragged AddTaskTile, should not happen with buildDefaultDragHandles=false

                            if (hasAddTaskTile && newIndex > numActualTasks) {
                              newIndex = numActualTasks;
                            }

                            // If newIndex is greater than oldIndex, it means the item is moved down.
                            // The ReorderableListView's newIndex is based on the visual list.
                            // If an item is dragged downwards past other items, newIndex will be one greater
                            // than its final list position because the item itself is removed before being reinserted.
                            if (newIndex > oldIndex) {
                                newIndex -= 1;
                            }

                            // Ensure newIndex is within the bounds of actual tasks
                            if (newIndex >= numActualTasks) {
                                newIndex = numActualTasks -1;
                            }
                            if (newIndex < 0) newIndex = 0;

                            final taskToMove = tasks[oldIndex];
                            await widget.taskManager.reorderTaskInList(
                              parent?.id,
                              taskToMove.id,
                              oldIndex,
                              newIndex,
                            );
                            setState(() {
                              // The FutureBuilder will refetch and rebuild,
                              // or we can manually update the local 'tasks' list for immediate feedback
                              // For simplicity, relying on FutureBuilder refresh triggered by setState.
                            });
                          },
                          // Optional: Add a proxy decorator for custom drag feedback if needed
                          // proxyDecorator: (Widget child, int index, Animation<double> animation) { ... }
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
