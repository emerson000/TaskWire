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
  final TextEditingController _newTaskController = TextEditingController();
  bool _showAddTask = false;
  int _refreshCounter = 0;

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
    _newTaskController.dispose();
    super.dispose();
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= _desktopBreakpoint;
  }

  Future<void> _addTask(String? parentId) async {
    if (_newTaskController.text.trim().isEmpty) return;

    try {
      await _taskManager.createTask(
        _newTaskController.text.trim(),
        parentId: parentId != null ? int.parse(parentId) : null,
      );
      _newTaskController.clear();
      setState(() {
        _showAddTask = false;
        _refreshCounter++;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating task: $e');
      }
    }
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
          _showAddTaskDialog(null);
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
      editingTaskId: _editingTaskId,
      editController: _editController,
      onAddTask: _showAddTaskDialog,
    );
  }

  Widget _buildMobileView() {
    return MobileDrillDownView(
      taskManager: _taskManager,
      onUpdateTask: _updateTask,
      onDeleteTask: _deleteTask,
      onStartEditing: _startEditing,
      onFinishEditing: _finishEditing,
      editingTaskId: _editingTaskId,
      editController: _editController,
      onAddTask: _showAddTaskDialog,
      refreshKey: _refreshCounter,
    );
  }

  Future<void> _showAddTaskDialog(String? parentId) async {
    Task? parentTask;
    if (parentId != null) {
      parentTask = await _taskManager.findTaskById(int.parse(parentId));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          parentTask != null
              ? 'Add Subtask to "${parentTask.title}"'
              : 'Add New Task',
        ),
        content: TextField(
          controller: _newTaskController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: parentTask != null
                ? 'Enter subtask title'
                : 'Enter task title',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) async {
            await _addTask(parentId);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newTaskController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addTask(parentId);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
