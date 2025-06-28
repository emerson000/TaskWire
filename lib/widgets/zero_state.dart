import 'package:flutter/material.dart';

class ZeroState extends StatelessWidget {
  final String? parentTitle;
  final VoidCallback onAddTask;
  final bool isDesktop;

  const ZeroState({
    super.key,
    this.parentTitle,
    required this.onAddTask,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 120 : 80,
                height: isDesktop ? 120 : 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.task_alt,
                  size: isDesktop ? 60 : 40,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                parentTitle != null ? 'No subtasks yet' : 'No tasks yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                parentTitle != null 
                  ? 'Get started by adding subtasks to "${parentTitle}"'
                  : 'Create your first task to get organized',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAddTask,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  parentTitle != null ? 'Add Subtask' : 'Add Task',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 