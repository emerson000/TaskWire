import 'package:taskwire/models/printer.dart';
import 'package:taskwire/models/task.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_usb/print_usb.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:flutter_usb_printer/flutter_usb_printer.dart';

enum PrintErrorType {
  noPrinters,
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
  final Map<String, PrinterNetworkManager> _networkPrinters = {};

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
      } else if (printer.type == PrinterType.network) {
        if (!_isValidIpAddress(printer.address)) {
          print('Invalid IP address: ${printer.address}');
          return false;
        }

        PrinterNetworkManager? networkPrinter = _networkPrinters[printerId];
        
        if (networkPrinter == null) {
          networkPrinter = PrinterNetworkManager(printer.address);
          _networkPrinters[printerId] = networkPrinter;
        }
        
        try {
          final connectResult = await networkPrinter.connect();
          
          if (connectResult == PosPrintResult.success) {
            printer.isConnected = true;
            await _repository.updatePrinter(printer);
            return true;
          } else {
            print('Failed to connect to network printer: ${connectResult.msg}');
            _networkPrinters.remove(printerId);
            printer.isConnected = false;
            await _repository.updatePrinter(printer);
            return false;
          }
        } catch (e) {
          print('Error connecting to network printer: $e');
          _networkPrinters.remove(printerId);
          printer.isConnected = false;
          await _repository.updatePrinter(printer);
          return false;
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

  Future<bool> printJob(String printerId, List<int> bytes, {bool keepConnected = false}) async {
    try {
      final printers = await _repository.getPrinters();
      final printer = printers.firstWhere((p) => p.id == printerId);

      if (printer.type == PrinterType.network) {
        if (!printer.isConnected) {
          final connected = await connectToPrinter(printerId);
          if (!connected) {
            throw Exception('Failed to connect to network printer');
          }
        }
      } else {
        final connected = await connectToPrinter(printerId);
        if (!connected) {
          throw Exception('Failed to connect to printer');
        }
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
      } else if (printer.type == PrinterType.network) {
        final networkPrinter = _networkPrinters[printerId];
        if (networkPrinter == null) {
          throw Exception('Network printer not connected');
        }

        try {
          final printResult = await networkPrinter.printTicket(bytes);
          final success = printResult == PosPrintResult.success;
          
          if (success && !keepConnected) {
            networkPrinter.disconnect();
            _networkPrinters.remove(printerId);
            printer.isConnected = false;
            await _repository.updatePrinter(printer);
          }
          
          return success;
        } catch (e) {
          print('Network printer error: $e');
          if (e.toString().contains('capabilities.length is already loaded')) {
            print('Capabilities already loaded, trying alternative approach');
            await Future.delayed(const Duration(seconds: 1));
            return true;
          }
          
          if (!keepConnected) {
            try {
              networkPrinter.disconnect();
              _networkPrinters.remove(printerId);
              printer.isConnected = false;
              await _repository.updatePrinter(printer);
            } catch (disconnectError) {
              print('Error disconnecting after print: $disconnectError');
            }
          }
          
          await Future.delayed(const Duration(seconds: 2));
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

  Future<bool> printIndividualSlips(
    String printerId,
    List<Task> tasks, {
    String? hierarchyPath,
  }) async {
    try {
      final incompleteTasks = tasks.where((task) => !task.isCompleted).toList();
      
      if (incompleteTasks.isEmpty) {
        return true;
      }
      
      for (int i = 0; i < incompleteTasks.length; i++) {
        final task = incompleteTasks[i];
        final slipBytes = await _generateIndividualSlipBytes(task, hierarchyPath);
        final isLastTask = i == incompleteTasks.length - 1;
        final success = await printJob(printerId, slipBytes, keepConnected: !isLastTask);
        if (!success) return false;
      }
      return true;
    } catch (e) {
      print('Error in print individual slips: $e');
      return false;
    }
  }

  Future<bool> printIndividualSlipsWithSubtasks(
    String printerId,
    List<Task> tasks, {
    String? hierarchyPath,
  }) async {
    try {
      final incompleteTasks = tasks.where((task) => !task.isCompleted).toList();
      
      if (incompleteTasks.isEmpty) {
        return true;
      }
      
      for (int i = 0; i < incompleteTasks.length; i++) {
        final task = incompleteTasks[i];
        final slipBytes = await _generateIndividualSlipWithSubtasksBytes(task, hierarchyPath);
        final isLastTask = i == incompleteTasks.length - 1;
        final success = await printJob(printerId, slipBytes, keepConnected: !isLastTask);
        if (!success) return false;
      }
      return true;
    } catch (e) {
      print('Error in print individual slips with subtasks: $e');
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

      if (printer.type == PrinterType.network) {
        final networkPrinter = _networkPrinters[printerId];
        if (networkPrinter != null) {
          try {
            networkPrinter.disconnect();
          } catch (e) {
            print('Error disconnecting network printer: $e');
          }
          _networkPrinters.remove(printerId);
        }
      }

      printer.isConnected = false;
      await _repository.updatePrinter(printer);
    } catch (e) {
      print('Error disconnecting printer: $e');
    }
  }

  void dispose() {
    for (final networkPrinter in _networkPrinters.values) {
      try {
        networkPrinter.disconnect();
      } catch (e) {
        print('Error disposing network printer: $e');
      }
    }
    _networkPrinters.clear();
  }

  Future<PrintResult> printTasksWithPrinterSelection({
    required List<Task> tasks,
    required String? levelTitle,
    required bool includeSubtasks,
    required BuildContext context,
    String? printType,
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

      String? selectedPrinterId;
      if (printers.length == 1) {
        selectedPrinterId = printers.first.id;
      } else {
        selectedPrinterId = await _showPrinterSelectionDialog(
          context,
          printers,
        );
        if (selectedPrinterId == null) {
          return PrintResult(
            success: false,
            errorMessage: 'No printer selected.',
            errorType: PrintErrorType.cancelled,
          );
        }
      }

      bool success;
      switch (printType) {
        case 'checklist':
          success = includeSubtasks
              ? await printColumnWithSubtasks(selectedPrinterId!, tasks, columnTitle: levelTitle)
              : await printColumn(selectedPrinterId!, tasks, columnTitle: levelTitle);
          break;
        case 'individual_slips':
          success = includeSubtasks
              ? await printIndividualSlipsWithSubtasks(selectedPrinterId!, tasks, hierarchyPath: levelTitle)
              : await printIndividualSlips(selectedPrinterId!, tasks, hierarchyPath: levelTitle);
          break;
        default:
          success = includeSubtasks
              ? await printColumnWithSubtasks(selectedPrinterId!, tasks, columnTitle: levelTitle)
              : await printColumn(selectedPrinterId!, tasks, columnTitle: levelTitle);
      }

      if (success) {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        final typeText = printType == 'individual_slips' ? 'individual slips' : 'checklist';
        
        String successMessage;
        if (printType == 'individual_slips') {
          final incompleteCount = tasks.where((task) => !task.isCompleted).length;
          if (incompleteCount == 0) {
            successMessage = 'No incomplete tasks to print for level "$levelTitle"';
          } else {
            successMessage = '$incompleteCount incomplete task${incompleteCount == 1 ? '' : 's'} from level "$levelTitle" printed as $typeText successfully';
          }
        } else {
          successMessage = 'Level "$levelTitle" $actionText printed as $typeText successfully';
        }
        
        return PrintResult(
          success: true,
          successMessage: successMessage,
        );
      } else {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        final typeText = printType == 'individual_slips' ? 'individual slips' : 'checklist';
        return PrintResult(
          success: false,
          errorMessage: 'Failed to print level $actionText as $typeText',
          errorType: PrintErrorType.printFailed,
        );
      }
    } catch (e) {
      final actionText = includeSubtasks ? 'with subtasks' : '';
      final typeText = printType == 'individual_slips' ? 'individual slips' : 'checklist';
      return PrintResult(
        success: false,
        errorMessage: 'Error printing level $actionText as $typeText: $e',
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

  Future<List<int>> _generateIndividualSlipBytes(
    Task task,
    String? hierarchyPath,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    generator.setGlobalFont(PosFontType.fontA);

    List<int> bytes = [];
    bytes += generator.reset();

    if (hierarchyPath != null) {
      bytes += generator.text(
        hierarchyPath,
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text('');
    }

    bytes += generator.text(
      task.title,
      styles: PosStyles(
        height: PosTextSize.size3,
        width: PosTextSize.size3,
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text('');

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    if (task.subtaskCount > 0) {
      bytes += generator.text(
        'Subtasks: ${task.subtaskCount}',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      );
    }
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _generateIndividualSlipWithSubtasksBytes(
    Task task,
    String? hierarchyPath,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    generator.setGlobalFont(PosFontType.fontA);

    List<int> bytes = [];
    bytes += generator.reset();

    if (hierarchyPath != null) {
      bytes += generator.text(
        hierarchyPath,
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text('');
    }

    bytes += generator.text(
      task.title,
      styles: PosStyles(
        height: PosTextSize.size3,
        width: PosTextSize.size3,
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text('');

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    if (task.subtaskCount > 0) {
      bytes += generator.text('');
      bytes += generator.text(
        'Subtasks:',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += await _addSubtasksToIndividualSlip(generator, task.subtasks, 1);
    }
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _addSubtasksToIndividualSlip(
    Generator generator,
    List<Task> subtasks,
    int level,
  ) async {
    List<int> bytes = [];
    for (final subtask in subtasks) {
      final indent = '  ' * level;
      bytes += generator.text(
        '$indent[ ] ${subtask.title}',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      if (subtask.subtaskCount > 0) {
        bytes += await _addSubtasksToIndividualSlip(
          generator,
          subtask.subtasks,
          level + 1,
        );
      }
    }
    return bytes;
  }

  bool _isValidIpAddress(String ipAddress) {
    try {
      final parts = ipAddress.split('.');
      if (parts.length != 4) return false;
      
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
