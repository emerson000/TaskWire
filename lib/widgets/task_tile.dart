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
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
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
    return Opacity(
      opacity: 0.5,
      child: _buildNormalTile(context),
    );
  }

  Widget _buildDragTarget(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.id != task.id,
      onAccept: (draggedTask) {
        onDragAccept?.call(draggedTask);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: _buildNormalTile(context),
        );
      },
    );
  }

  Widget _buildNormalTile(BuildContext context) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows || 
                     defaultTargetPlatform == TargetPlatform.macOS || 
                     defaultTargetPlatform == TargetPlatform.linux;
    
    Widget tileContent = ListTile(
      tileColor: isSelected ? Theme.of(context).colorScheme.surfaceContainer : null,
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: onCheckboxChanged,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      subtitle: task.hasSubtasks
          ? Text(
              '${task.subtaskCount} subtask${task.subtaskCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.hasSubtasks)
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
        ],
      ),
      onTap: onTap,
    );

    if (isDesktop) {
      return GestureDetector(
        onSecondaryTapDown: (TapDownDetails details) => _showContextMenu(context, details.globalPosition),
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
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
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
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
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
              Icon(
                Icons.delete,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
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
    void handleKeyEvent(RawKeyEvent event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        onEditCancel?.call();
      }
    }

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: onCheckboxChanged,
            ),
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

class AddTaskTile extends StatefulWidget {
  final String? parentId;
  final String? parentTitle;
  final Function(String taskTitle, String? parentId) onAddTask;
  final VoidCallback? onCancel;

  const AddTaskTile({
    super.key,
    this.parentId,
    this.parentTitle,
    required this.onAddTask,
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

  Future<void> _submitTask() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    try {
      await widget.onAddTask(_controller.text.trim(), widget.parentId);
      _controller.clear();
      _focusNode.requestFocus();
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  void _cancel() {
    _controller.clear();
    widget.onCancel?.call();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
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
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  hintText: widget.parentTitle != null
                      ? 'Add subtask'
                      : 'Add new task',
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isEmpty) {
                    _cancel();
                  } else {
                    _submitTask();
                  }
                },
              ),
            ),
            if (_isAdding)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _submitTask,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
