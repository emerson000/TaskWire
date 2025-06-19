import 'package:taskwire/models/printer.dart';
import 'package:taskwire/models/task.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_usb/print_usb.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:flutter_usb_printer/flutter_usb_printer.dart';

enum PrintErrorType {
  noPrinters,
  noConnectedPrinters,
  cancelled,
  printFailed,
  exception,
}

class PrintResult {
  final bool success;
  final String? successMessage;
  final String? errorMessage;
  final PrintErrorType? errorType;

  const PrintResult({
    required this.success,
    this.successMessage,
    this.errorMessage,
    this.errorType,
  });
}

class PrinterService {
  final PrinterRepository _repository;
  final FlutterUsbPrinter _flutterUsbPrinter;

  PrinterService(this._repository) : _flutterUsbPrinter = FlutterUsbPrinter();

  Future<List<Printer>> getPrinters() {
    return _repository.getPrinters();
  }

  Future<void> addPrinter(Printer printer) {
    return _repository.addPrinter(printer);
  }

  Future<void> removePrinter(String printerId) {
    return _repository.removePrinter(printerId);
  }

  Future<List<Printer>> scanForPrinters() async {
    if (Platform.isAndroid) {
      return await _scanAndroidUsbPrinters();
    } else if (Platform.isWindows) {
      return await _scanWindowsUsbPrinters();
    } else {
      return await _scanMockPrinters();
    }
  }

  Future<List<Printer>> _scanAndroidUsbPrinters() async {
    try {
      final devices = await FlutterUsbPrinter.getUSBDeviceList();
      return devices
          .map(
            (device) => Printer(
              name: device['productName'] ?? 'Unknown USB Device',
              type: PrinterType.usb,
              address:
                  "${device['vendorId']}:${device['productId']}", // Storing vendor and product id
              lastSeen: DateTime.now(),
            ),
          )
          .toList();
    } catch (e) {
      print('Error scanning USB printers on Android: $e');
      return [];
    }
  }

  Future<List<Printer>> _scanWindowsUsbPrinters() async {
    try {
      final devices = await PrintUsb.getList();
      return devices
          .map(
            (device) => Printer(
              name: device.name,
              type: PrinterType.usb,
              address: device.name,
              lastSeen: DateTime.now(),
            ),
          )
          .toList();
    } catch (e) {
      print('Error scanning USB printers: $e');
      return [];
    }
  }

  Future<List<Printer>> _scanMockPrinters() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      Printer(
        name: 'Mock Network Printer 1',
        type: PrinterType.network,
        address: '192.168.1.101',
      ),
      Printer(
        name: 'Mock USB Printer',
        type: PrinterType.usb,
        address: 'USB001',
      ),
      Printer(
        name: 'Mock Network Printer 2',
        type: PrinterType.network,
        address: '192.168.1.102',
      ),
    ];
  }

  Future<bool> connectToPrinter(String printerId) async {
    try {
      final printers = await _repository.getPrinters();
      final printer = printers.firstWhere((p) => p.id == printerId);

      if (printer.type == PrinterType.usb) {
        if (Platform.isWindows) {
          final connected = await PrintUsb.connect(name: printer.address);
          if (connected) {
            printer.isConnected = true;
            await _repository.updatePrinter(printer);
          }
          return connected;
        } else if (Platform.isAndroid) {
          final parts = printer.address.split(':');
          if (parts.length != 2) return false;
          final vendorId = int.tryParse(parts[0]);
          final productId = int.tryParse(parts[1]);

          if (vendorId == null || productId == null) return false;

          final connected = await _flutterUsbPrinter.connect(
            vendorId,
            productId,
          );
          if (connected == true) {
            printer.isConnected = true;
            await _repository.updatePrinter(printer);
          }
          return connected ?? false;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
      printer.isConnected = true;
      await _repository.updatePrinter(printer);
      return true;
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  Future<bool> printJob(String printerId, List<int> bytes) async {
    try {
      final printers = await _repository.getPrinters();
      final printer = printers.firstWhere((p) => p.id == printerId);

      final connected = await connectToPrinter(printerId);
      if (!connected) {
        throw Exception('Failed to connect to printer');
      }

      if (printer.type == PrinterType.usb) {
        if (Platform.isWindows) {
          final devices = await PrintUsb.getList();
          final device = devices.firstWhere(
            (d) => d.name == printer.address,
            orElse: () => throw Exception('USB printer not found'),
          );

          final success = await PrintUsb.printBytes(
            bytes: bytes,
            device: device,
          );
          return success;
        } else if (Platform.isAndroid) {
          final data = Uint8List.fromList(bytes);
          await _flutterUsbPrinter.write(data);
          return true;
        }
      } else {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
      return false;
    } catch (e) {
      print('Error printing job: $e');
      return false;
    }
  }

  Future<bool> testPrint(String printerId) async {
    try {
      final testBytes = await _generateTestReceiptBytes();
      return await printJob(printerId, testBytes);
    } catch (e) {
      print('Error in test print: $e');
      return false;
    }
  }

  Future<bool> printColumn(
    String printerId,
    List<Task> tasks, {
    String? columnTitle,
  }) async {
    try {
      final columnBytes = await _generateColumnReceiptBytes(tasks, columnTitle);
      return await printJob(printerId, columnBytes);
    } catch (e) {
      print('Error in print column: $e');
      return false;
    }
  }

  Future<bool> printColumnWithSubtasks(
    String printerId,
    List<Task> tasks, {
    String? columnTitle,
  }) async {
    try {
      final columnBytes = await _generateColumnWithSubtasksReceiptBytes(
        tasks,
        columnTitle,
      );
      return await printJob(printerId, columnBytes);
    } catch (e) {
      print('Error in print column with subtasks: $e');
      return false;
    }
  }

  Future<List<int>> _generateColumnWithSubtasksReceiptBytes(
    List<Task> tasks,
    String? columnTitle,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    generator.setGlobalFont(PosFontType.fontA);

    List<int> bytes = [];
    bytes += generator.reset();

    final title = columnTitle ?? 'TaskWire Column';
    bytes += generator.text(
      title,
      styles: PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    bytes += generator.text(
      'Tasks: ${tasks.length}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    bytes += generator.hr(len: 42);

    if (tasks.isEmpty) {
      bytes += generator.text(
        'No tasks in this column',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      );
    } else {
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        bytes += generator.text(
          '[${task.isCompleted ? 'X' : ' '}] ${task.title}',
          styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            bold: task.isCompleted,
          ),
        );

        if (task.subtaskCount > 0) {
          bytes += generator.text(
            '   Subtasks: ${task.subtaskCount}',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              align: PosAlign.right,
            ),
          );

          bytes += await _addSubtasksToReceipt(generator, task.subtasks, 1);
        }

        if (i < tasks.length - 1) {
          bytes += generator.text('');
        }
      }
    }

    bytes += generator.hr(len: 42);
    bytes += generator.text(
      'Generated by TaskWire',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _addSubtasksToReceipt(
    Generator generator,
    List<Task> subtasks,
    int level,
  ) async {
    List<int> bytes = [];
    for (final subtask in subtasks) {
      final indent = '  ' * level;
      bytes += generator.text(
        '$indent[${subtask.isCompleted ? 'X' : ' '}] ${subtask.title}',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: subtask.isCompleted,
        ),
      );

      if (subtask.subtaskCount > 0) {
        bytes += await _addSubtasksToReceipt(
          generator,
          subtask.subtasks,
          level + 1,
        );
      }
    }
    return bytes;
  }

  Future<List<int>> _generateColumnReceiptBytes(
    List<Task> tasks,
    String? columnTitle,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    generator.setGlobalFont(PosFontType.fontA);

    List<int> bytes = [];
    bytes += generator.reset();

    final title = columnTitle ?? 'TaskWire Column';
    bytes += generator.text(
      title,
      styles: PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    bytes += generator.text(
      'Tasks: ${tasks.length}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    bytes += generator.hr(len: 42);

    if (tasks.isEmpty) {
      bytes += generator.text(
        'No tasks in this column',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      );
    } else {
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        bytes += generator.text(
          '[${task.isCompleted ? 'X' : ' '}] ${task.title}',
          styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            bold: task.isCompleted,
          ),
        );

        if (task.subtaskCount > 0) {
          bytes += generator.text(
            '   Subtasks: ${task.subtaskCount}',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              align: PosAlign.right,
            ),
          );
        }

        if (i < tasks.length - 1) {
          bytes += generator.text('');
        }
      }
    }

    bytes += generator.hr(len: 42);
    bytes += generator.text(
      'Generated by TaskWire',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _generateTestReceiptBytes() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text(
      'TaskWire PrinterTTTest',
      styles: PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
      ),
    );
    bytes += generator.text(
      'Date: ${DateTime.now()}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );
    bytes += generator.cut();
    return bytes;
  }

  Future<void> disconnectPrinter(String printerId) async {
    try {
      final printers = await _repository.getPrinters();
      final printer = printers.firstWhere((p) => p.id == printerId);

      printer.isConnected = false;
      await _repository.updatePrinter(printer);
    } catch (e) {
      print('Error disconnecting printer: $e');
    }
  }

  Future<PrintResult> printTasksWithPrinterSelection({
    required List<Task> tasks,
    required String? levelTitle,
    required bool includeSubtasks,
    required BuildContext context,
  }) async {
    try {
      final printers = await getPrinters();
      if (printers.isEmpty) {
        return PrintResult(
          success: false,
          errorMessage: 'No printers available. Please add a printer first.',
          errorType: PrintErrorType.noPrinters,
        );
      }

      final connectedPrinters = printers.where((p) => p.isConnected).toList();
      if (connectedPrinters.isEmpty) {
        return PrintResult(
          success: false,
          errorMessage: 'No connected printers. Please connect a printer first.',
          errorType: PrintErrorType.noConnectedPrinters,
        );
      }

      String? selectedPrinterId;
      if (connectedPrinters.length == 1) {
        selectedPrinterId = connectedPrinters.first.id;
      } else {
        selectedPrinterId = await _showPrinterSelectionDialog(
          context,
          connectedPrinters,
        );
        if (selectedPrinterId == null) {
          return PrintResult(
            success: false,
            errorMessage: 'No printer selected.',
            errorType: PrintErrorType.cancelled,
          );
        }
      }

      final success = includeSubtasks
          ? await printColumnWithSubtasks(selectedPrinterId!, tasks, columnTitle: levelTitle)
          : await printColumn(selectedPrinterId!, tasks, columnTitle: levelTitle);

      if (success) {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        return PrintResult(
          success: true,
          successMessage: 'Level "$levelTitle" $actionText printed successfully',
        );
      } else {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        return PrintResult(
          success: false,
          errorMessage: 'Failed to print level $actionText',
          errorType: PrintErrorType.printFailed,
        );
      }
    } catch (e) {
      final actionText = includeSubtasks ? 'with subtasks' : '';
      return PrintResult(
        success: false,
        errorMessage: 'Error printing level $actionText: $e',
        errorType: PrintErrorType.exception,
      );
    }
  }

  Future<String?> _showPrinterSelectionDialog(
    BuildContext context,
    List<Printer> printers,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: printers
              .map(
                (printer) => ListTile(
                  title: Text(printer.name),
                  subtitle: Text(
                    '${printer.type.name.toUpperCase()}: ${printer.address}',
                  ),
                  onTap: () => Navigator.of(context).pop(printer.id),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
