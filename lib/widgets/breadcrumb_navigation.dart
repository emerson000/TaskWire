import 'package:flutter/material.dart';
import '../models/task.dart';

class BreadcrumbNavigation extends StatelessWidget {
  final List<Task?> breadcrumbs;
  final Function(Task?) onNavigate;
  final Function(Task, Task?)? onTaskDrop;
  final bool isDragging;
  final int currentPageIndex;

  const BreadcrumbNavigation({
    super.key,
    required this.breadcrumbs,
    required this.onNavigate,
    this.onTaskDrop,
    this.isDragging = false,
    this.currentPageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDragging 
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDragging 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).dividerColor,
            width: isDragging ? 2.0 : 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbItems(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreadcrumbItems(BuildContext context) {
    List<Widget> items = [];

    for (int i = 0; i < breadcrumbs.length; i++) {
      final task = breadcrumbs[i];
      final isLast = i == breadcrumbs.length - 1;
      final isCurrentPage = i == currentPageIndex;

      Widget breadcrumbContent = GestureDetector(
        onTap: isLast ? null : () => onNavigate(task),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isCurrentPage
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            task?.title ?? 'Home',
            style: TextStyle(
              color: isCurrentPage
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.primary,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

      Widget breadcrumbItem;
      if (onTaskDrop != null && !isLast) {
        breadcrumbItem = DragTarget<Task>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) => onTaskDrop!(details.data, task),
          builder: (context, candidateData, rejectedData) {
            final isDragTarget = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: isDragTarget
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6)
                    : isDragging
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
                        : null,
                borderRadius: BorderRadius.circular(8.0),
                border: isDragTarget
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      )
                    : isDragging
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 1.0,
                            style: BorderStyle.solid,
                          )
                        : null,
                boxShadow: isDragTarget
                    ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8.0,
                          spreadRadius: 2.0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  breadcrumbContent,
                  if (isDragTarget)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      } else {
        breadcrumbItem = breadcrumbContent;
      }

      items.add(breadcrumbItem);

      if (!isLast) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }

    return items;
  }
}
