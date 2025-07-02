import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final bool isEditing;
  final bool isSelected;
  final TextEditingController? editController;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(bool?)? onCheckboxChanged;
  final VoidCallback? onEditComplete;
  final VoidCallback? onEditCancel;
  final bool isDragTarget;
  final Function(Task)? onDragAccept;
  final Function(Task)? onReorderDragStart;
  final Function(Task, Task)? onReorderDragAccept;
  final int? reorderIndex;

  const TaskTile({
    super.key,
    required this.task,
    this.isEditing = false,
    this.isSelected = false,
    this.editController,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCheckboxChanged,
    this.onEditComplete,
    this.onEditCancel,
    this.isDragTarget = false,
    this.onDragAccept,
    this.onReorderDragStart,
    this.onReorderDragAccept,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return _buildEditingTile(context);
    }

    return _buildDraggableWidget(context);
  }

  Widget _buildDraggableWidget(BuildContext context) {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    if (isWindows) {
      return Draggable<Task>(
        data: task,
        feedback: _buildDragFeedback(context),
        childWhenDragging: _buildChildWhenDragging(context),
        child: _buildDragTarget(context),
      );
    } else {
      return LongPressDraggable<Task>(
        data: task,
        feedback: _buildDragFeedback(context),
        childWhenDragging: _buildChildWhenDragging(context),
        child: _buildDragTarget(context),
      );
    }
  }

  Widget _buildDragFeedback(BuildContext context) {
    return Material(
      elevation: 4.0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(
              task.isCompleted
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            if (task.hasSubtasks) ...[
              const SizedBox(width: 8),
              _buildSubtaskIndicator(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildWhenDragging(BuildContext context) {
    return Opacity(opacity: 0.5, child: _buildNormalTile(context));
  }

  Widget _buildDragTarget(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.id != task.id,
      onAcceptWithDetails: (details) {
        onDragAccept?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: _buildNormalTile(context),
        );
      },
    );
  }

  Widget _buildNormalTile(BuildContext context) {
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    Widget tileContent = _TaskTileContent(
      task: task,
      isSelected: isSelected,
      onCheckboxChanged: onCheckboxChanged,
      onEdit: onEdit,
      onTap: onTap,
      onReorderDragStart: onReorderDragStart,
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.surfaceContainer
          : null,
      reorderIndex: reorderIndex,
    );

    if (isDesktop) {
      return GestureDetector(
        onSecondaryTapDown: (TapDownDetails details) =>
            _showContextMenu(context, details.globalPosition),
        child: tileContent,
      );
    } else {
      return Dismissible(
        key: Key('task_${task.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: Theme.of(context).colorScheme.error,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          onDelete?.call();
          return false;
        },
        child: tileContent,
      );
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect menuPosition = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    );

    showMenu<String>(
      context: context,
      position: menuPosition,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: const Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'edit':
          onEdit?.call();
          break;
        case 'delete':
          onDelete?.call();
          break;
      }
    });
  }

  Widget _buildEditingTile(BuildContext context) {
    void handleKeyEvent(KeyEvent event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        onEditCancel?.call();
      }
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Checkbox(value: task.isCompleted, onChanged: onCheckboxChanged),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: editController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onSubmitted: (value) => onEditComplete?.call(),
                onEditingComplete: () => onEditComplete?.call(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => onEditComplete?.call(),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onEditCancel?.call(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtaskIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        '${task.subtaskCount}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _TaskTileContent extends StatefulWidget {
  final Task task;
  final bool isSelected;
  final Function(bool?)? onCheckboxChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final Function(Task)? onReorderDragStart;
  final Color? backgroundColor;
  final int? reorderIndex;

  const _TaskTileContent({
    required this.task,
    required this.isSelected,
    this.onCheckboxChanged,
    this.onEdit,
    this.onTap,
    this.onReorderDragStart,
    this.backgroundColor,
    this.reorderIndex,
  });

  @override
  State<_TaskTileContent> createState() => _TaskTileContentState();
}

class _TaskTileContentState extends State<_TaskTileContent> {
  bool _isTileHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isTileHovered = true),
          onExit: (_) => setState(() => _isTileHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  widget.reorderIndex != null
                      ? ReorderableDragStartListener(
                          index: widget.reorderIndex!,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: _isTileHovered
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: _isTileHovered ? 1.0 : 0.0,
                              child: Icon(
                                Icons.drag_handle,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: _isTileHovered
                                ? Theme.of(context).colorScheme.surfaceContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _isTileHovered ? 1.0 : 0.0,
                            child: Icon(
                              Icons.drag_handle,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: widget.task.isCompleted,
                    onChanged: widget.onCheckboxChanged,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            decoration: widget.task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.task.isCompleted
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (widget.task.hasSubtasks)
                          Text(
                            '${widget.task.subtaskCount} subtask${widget.task.subtaskCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.task.hasSubtasks)
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: widget.onEdit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddTaskTile extends StatefulWidget {
  final String? parentId;
  final String? parentTitle;
  final Function(String taskTitle, String? parentId) onAddTask;
  final Function(List<String> taskTitles, String? parentId)? onAddMultipleTasks;
  final VoidCallback? onCancel;

  const AddTaskTile({
    super.key,
    this.parentId,
    this.parentTitle,
    required this.onAddTask,
    this.onAddMultipleTasks,
    this.onCancel,
  });

  @override
  State<AddTaskTile> createState() => _AddTaskTileState();
}

class _AddTaskTileState extends State<AddTaskTile> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _parseMultiLineText(String text) {
    final lines = text.split('\n');
    final tasks = <String>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty) {
        final cleanedLine = _cleanMarkdownBullets(trimmedLine);
        if (cleanedLine.isNotEmpty) {
          tasks.add(cleanedLine);
        }
      }
    }

    return tasks;
  }

  String _cleanMarkdownBullets(String text) {
    return text
        .replaceAll(RegExp(r'^[\s]*[-*+]\s*\[[\sXx]\]\s*'), '')
        .replaceAll(RegExp(r'^[\s]*[-*+]\s*'), '')
        .replaceAll(RegExp(r'^[\s]*\d+\.\s*'), '')
        .trim();
  }

  Future<void> _submitTask() async {
    if (_controller.text.trim().isEmpty) return;

    final text = _controller.text.trim();
    final tasks = _parseMultiLineText(text);

    if (tasks.length == 1) {
      await _createSingleTask(tasks.first);
    } else if (tasks.length > 1) {
      await _promptForMultipleTasks(tasks);
    }
  }

  Future<void> _createSingleTask(String taskTitle) async {
    setState(() {
      _isAdding = true;
    });

    try {
      await widget.onAddTask(taskTitle, widget.parentId);
      _controller.clear();
      _focusNode.requestFocus();
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  Future<void> _promptForMultipleTasks(List<String> taskTitles) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Multiple Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The pasted text contains ${taskTitles.length} lines. Would you like to create ${taskTitles.length} separate tasks?',
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: taskTitles
                      .map(
                        (taskTitle) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $taskTitle'),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Tasks'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isAdding = true;
      });

      try {
        if (widget.onAddMultipleTasks != null) {
          await widget.onAddMultipleTasks!(taskTitles, widget.parentId);
        } else {
          for (final taskTitle in taskTitles) {
            await widget.onAddTask(taskTitle, widget.parentId);
          }
        }
        _controller.clear();
        _focusNode.requestFocus();
      } finally {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  void _cancel() {
    _controller.clear();
    widget.onCancel?.call();
  }

  void _handleTextFieldKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _submitTask();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleTextFieldKeyEvent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                enabled: !_isAdding,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  hintText: widget.parentTitle != null
                      ? 'Add subtask'
                      : 'Add new task',
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_isAdding)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(icon: const Icon(Icons.check), onPressed: _submitTask),
              IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
            ],
          ],
        ),
      ),
    );
  }
}
