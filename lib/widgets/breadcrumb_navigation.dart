import 'package:flutter/material.dart';
import '../models/task.dart';

class BreadcrumbNavigation extends StatelessWidget {
  final List<Task?> breadcrumbs;
  final Function(Task?) onNavigate;
  final Function(Task, Task?)? onTaskDrop;
  final bool isDragging;

  const BreadcrumbNavigation({
    super.key,
    required this.breadcrumbs,
    required this.onNavigate,
    this.onTaskDrop,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
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

      Widget breadcrumbContent = GestureDetector(
        onTap: isLast ? null : () => onNavigate(task),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isLast
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            task?.title ?? 'Home',
            style: TextStyle(
              color: isLast
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.primary,
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
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
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : null,
                borderRadius: BorderRadius.circular(6.0),
                border: candidateData.isNotEmpty
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.0,
                      )
                    : null,
              ),
              child: breadcrumbContent,
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
