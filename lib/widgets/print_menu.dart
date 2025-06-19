import 'package:flutter/material.dart';

enum PrintMenuType {
  popup,
  menuAnchor,
}

class PrintMenu extends StatelessWidget {
  final VoidCallback onPrintLevel;
  final VoidCallback onPrintWithSubtasks;
  final PrintMenuType type;
  final String? tooltip;

  const PrintMenu({
    super.key,
    required this.onPrintLevel,
    required this.onPrintWithSubtasks,
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
              case 'print_level':
                onPrintLevel();
                break;
              case 'print_with_subtasks':
                onPrintWithSubtasks();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'print_level',
              child: Row(
                children: [
                  Icon(Icons.print, size: 16),
                  SizedBox(width: 8),
                  Text('Print Level'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'print_with_subtasks',
              child: Row(
                children: [
                  Icon(Icons.print_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Print Level & Subtasks'),
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
            MenuItemButton(
              onPressed: onPrintLevel,
              child: const Text('Print Column'),
            ),
            MenuItemButton(
              onPressed: onPrintWithSubtasks,
              child: const Text('Print Column & Subtasks'),
            ),
          ],
        );
    }
  }
} 