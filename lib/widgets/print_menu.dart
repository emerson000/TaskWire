import 'package:flutter/material.dart';

enum PrintMenuType {
  popup,
  menuAnchor,
}

class PrintMenu extends StatelessWidget {
  final VoidCallback onPrintLevel;
  final VoidCallback onPrintWithSubtasks;
  final VoidCallback onPrintIndividualSlips;
  final VoidCallback onPrintIndividualSlipsWithSubtasks;
  final PrintMenuType type;
  final String? tooltip;

  const PrintMenu({
    super.key,
    required this.onPrintLevel,
    required this.onPrintWithSubtasks,
    required this.onPrintIndividualSlips,
    required this.onPrintIndividualSlipsWithSubtasks,
    this.type = PrintMenuType.popup,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PrintMenuType.popup:
        return PopupMenuButton<String>(
          icon: const Icon(Icons.print, size: 20),
          tooltip: tooltip ?? 'Print options',
          onSelected: (value) {
            switch (value) {
              case 'checklist_level':
                onPrintLevel();
                break;
              case 'checklist_with_subtasks':
                onPrintWithSubtasks();
                break;
              case 'individual_slips':
                onPrintIndividualSlips();
                break;
              case 'individual_slips_with_subtasks':
                onPrintIndividualSlipsWithSubtasks();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'Checklist',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'checklist_level',
              child: Row(
                children: [
                  Icon(Icons.print, size: 16),
                  SizedBox(width: 8),
                  Text('Print Level'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'checklist_with_subtasks',
              child: Row(
                children: [
                  Icon(Icons.print_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Print Level & Subtasks'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'Individual Slips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'individual_slips',
              child: Row(
                children: [
                  Icon(Icons.receipt, size: 16),
                  SizedBox(width: 8),
                  Text('Print Individual Slips'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'individual_slips_with_subtasks',
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 16),
                  SizedBox(width: 8),
                  Text('Print Individual Slips & Subtasks'),
                ],
              ),
            ),
          ],
        );

      case PrintMenuType.menuAnchor:
        return MenuAnchor(
          builder: (
            BuildContext context,
            MenuController controller,
            Widget? child,
          ) {
            return IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              tooltip: tooltip ?? 'Print options',
            );
          },
          menuChildren: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Checklist',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            MenuItemButton(
              onPressed: onPrintLevel,
              child: const Text('Print Column'),
            ),
            MenuItemButton(
              onPressed: onPrintWithSubtasks,
              child: const Text('Print Column & Subtasks'),
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Individual Slips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            MenuItemButton(
              onPressed: onPrintIndividualSlips,
              child: const Text('Print Individual Slips'),
            ),
            MenuItemButton(
              onPressed: onPrintIndividualSlipsWithSubtasks,
              child: const Text('Print Individual Slips & Subtasks'),
            ),
          ],
        );
    }
  }
} 