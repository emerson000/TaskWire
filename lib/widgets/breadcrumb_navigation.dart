import 'package:flutter/material.dart';
import '../models/task.dart';

class BreadcrumbNavigation extends StatelessWidget {
  final List<Task?> breadcrumbs;
  final Function(Task?) onNavigate;

  const BreadcrumbNavigation({
    super.key,
    required this.breadcrumbs,
    required this.onNavigate,
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

      items.add(
        GestureDetector(
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
        ),
      );

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
