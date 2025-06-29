class Task {
  int id;
  String title;
  bool isCompleted;
  int? parentId;
  List<Task> subtasks;
  DateTime createdAt;
  DateTime updatedAt;
  int order; // New field for task order

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.parentId,
    List<Task>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.order = 0, // Default order
  }) : subtasks = subtasks ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get subtaskCount => subtasks.length;

  void addSubtask(Task subtask) {
    subtask.parentId = id;
    subtasks.add(subtask);
    updatedAt = DateTime.now();
  }

  void removeSubtask(Task subtask) {
    subtasks.remove(subtask);
    subtask.parentId = null;
    updatedAt = DateTime.now();
  }

  Task? findTaskById(int taskId) {
    if (id == taskId) return this;

    for (Task subtask in subtasks) {
      Task? found = subtask.findTaskById(taskId);
      if (found != null) return found;
    }

    return null;
  }

  List<Task> getAllDescendants() {
    List<Task> descendants = [];
    for (Task subtask in subtasks) {
      descendants.add(subtask);
      descendants.addAll(subtask.getAllDescendants());
    }
    return descendants;
  }

  Task copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    int? parentId,
    List<Task>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      parentId: parentId ?? this.parentId,
      subtasks: subtasks ?? List.from(this.subtasks),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Task(id: $id, title: $title, isCompleted: $isCompleted, parentId: $parentId, order: $order, subtasks: ${subtasks.length})';
  }
}
