import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import '../models/task.dart';
import '../services/task_manager.dart';
import '../services/printer_service.dart';
import '../repositories/printer_repository.dart';
import '../widgets/desktop_column_view.dart';
import '../widgets/mobile_drill_down_view.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final TaskManager _taskManager = getIt.get<TaskManager>();
  final PrinterService _printerService = PrinterService(
    getIt.get<PrinterRepository>(),
  );
  int? _editingTaskId;
  final TextEditingController _editController = TextEditingController();
  bool _showAddTask = false;
  String? _addTaskParentId;
  String? _addTaskParentTitle;
  int? _addTaskColumnIndex;
  int _refreshCounter = 0;
  Task? _currentParent;
  int _currentColumnIndex = 0;

  static const double _desktopBreakpoint = 800.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {});
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= _desktopBreakpoint;
  }

  Future<void> _addTask(String taskTitle, String? parentId) async {
    if (taskTitle.trim().isEmpty) {
      _hideAddTaskInline();
      return;
    }

    try {
      await _taskManager.createTask(
        taskTitle.trim(),
        parentId: parentId != null ? int.parse(parentId) : null,
      );
      setState(() {
        _refreshCounter++;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating task: $e');
      }
    }
  }

  void _showAddTaskInline(String? parentId, String? parentTitle, {int? columnIndex}) {
    setState(() {
      _showAddTask = true;
      _addTaskParentId = parentId;
      _addTaskParentTitle = parentTitle;
      _addTaskColumnIndex = columnIndex;
    });
  }

  void _hideAddTaskInline() {
    setState(() {
      _showAddTask = false;
      _addTaskParentId = null;
      _addTaskParentTitle = null;
      _addTaskColumnIndex = null;
    });
  }

  void _updateCurrentColumn(Task? parent, int columnIndex) {
    setState(() {
      _currentParent = parent;
      _currentColumnIndex = columnIndex;
    });
  }

  Future<void> _deleteTask(int taskId) async {
    final task = await _taskManager.findTaskById(taskId);
    if (task == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _taskManager.deleteTask(taskId);
              setState(() {
                _refreshCounter++;
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _startEditing(Task task) {
    _editController.text = task.title;
    setState(() {
      _editingTaskId = task.id;
    });
  }

  Future<void> _finishEditing() async {
    if (_editingTaskId != null && _editController.text.trim().isNotEmpty) {
      await _taskManager.updateTask(
        _editingTaskId!,
        title: _editController.text.trim(),
      );
    }
    setState(() {
      _editingTaskId = null;
      _refreshCounter++;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingTaskId = null;
    });
  }

  Future<void> _updateTask(
    int taskId, {
    String? title,
    bool? isCompleted,
  }) async {
    await _taskManager.updateTask(
      taskId,
      title: title,
      isCompleted: isCompleted,
    );
    setState(() {
      _refreshCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Scaffold(
      body: isDesktop ? _buildDesktopView() : _buildMobileView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTaskInline(_currentParent?.id.toString(), _currentParent?.title, columnIndex: _currentColumnIndex);
        },
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDesktopView() {
    return DesktopColumnView(
      taskManager: _taskManager,
      printerService: _printerService,
      onUpdateTask: _updateTask,
      onDeleteTask: _deleteTask,
      onStartEditing: _startEditing,
      onFinishEditing: _finishEditing,
      onEditCancel: _cancelEditing,
      editingTaskId: _editingTaskId,
      editController: _editController,
      onAddTask: _showAddTaskInline,
      onCreateTask: _addTask,
      showAddTask: _showAddTask,
      addTaskParentId: _addTaskParentId,
      addTaskParentTitle: _addTaskParentTitle,
      addTaskColumnIndex: _addTaskColumnIndex,
      onHideAddTask: _hideAddTaskInline,
      onColumnChange: _updateCurrentColumn,
      refreshKey: _refreshCounter,
    );
  }

  Widget _buildMobileView() {
    return MobileDrillDownView(
      taskManager: _taskManager,
      printerService: _printerService,
      onUpdateTask: _updateTask,
      onDeleteTask: _deleteTask,
      onStartEditing: _startEditing,
      onFinishEditing: _finishEditing,
      onEditCancel: _cancelEditing,
      editingTaskId: _editingTaskId,
      editController: _editController,
      onAddTask: _showAddTaskInline,
      onCreateTask: _addTask,
      onHideAddTask: _hideAddTaskInline,
      showAddTask: _showAddTask,
      addTaskParentId: _addTaskParentId,
      addTaskParentTitle: _addTaskParentTitle,
      refreshKey: _refreshCounter,
      onParentChange: _updateCurrentColumn,
    );
  }
}
