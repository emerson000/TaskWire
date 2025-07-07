import 'package:taskwire/models/printer.dart';
import 'package:taskwire/models/task.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:taskwire/services/logging_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_usb/print_usb.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:flutter_usb_printer/flutter_usb_printer.dart';

enum PrintErrorType { noPrinters, cancelled, printFailed, exception }

enum BarcodeType { qr, code39, code128, upcA }

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

  Future<Generator> _createGenerator() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    generator.setGlobalFont(PosFontType.fontA, maxCharsPerLine: 42);
    return generator;
  }

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
      LoggingService.error('Error scanning USB printers on Android: $e');
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
      LoggingService.error('Error scanning USB printers: $e');
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
          LoggingService.warning('Invalid IP address: ${printer.address}');
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
            LoggingService.error('Failed to connect to network printer: ${connectResult.msg}');
            _networkPrinters.remove(printerId);
            printer.isConnected = false;
            await _repository.updatePrinter(printer);
            return false;
          }
        } catch (e) {
          LoggingService.error('Error connecting to network printer: $e');
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
      LoggingService.error('Error connecting to printer: $e');
      return false;
    }
  }

  Future<bool> printJob(
    String printerId,
    List<int> bytes, {
    bool keepConnected = false,
  }) async {
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
          await Future.delayed(const Duration(seconds: 1));
          return success;
        } catch (e) {
          LoggingService.error('Network printer error: $e');
          if (!keepConnected) {
            try {
              networkPrinter.disconnect();
              _networkPrinters.remove(printerId);
              printer.isConnected = false;
              await _repository.updatePrinter(printer);
            } catch (disconnectError) {
              LoggingService.error('Error disconnecting after print: $disconnectError');
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
      LoggingService.error('Error printing job: $e');
      return false;
    }
  }

  Future<bool> testPrint(String printerId) async {
    try {
      final testBytes = await _generateTestReceiptBytes();
      return await printJob(printerId, testBytes);
    } catch (e) {
      LoggingService.error('Error in test print: $e');
      return false;
    }
  }

  Future<bool> printColumn(
    String printerId,
    List<Task> tasks, {
    String? columnTitle,
    String? hierarchyPath,
  }) async {
    try {
      final columnBytes = await _generateColumnReceiptBytes(tasks, columnTitle, hierarchyPath);
      return await printJob(printerId, columnBytes);
    } catch (e) {
      LoggingService.error('Error in print column: $e');
      return false;
    }
  }

  Future<bool> printColumnWithSubtasks(
    String printerId,
    List<Task> tasks, {
    String? columnTitle,
    String? hierarchyPath,
  }) async {
    try {
      final columnBytes = await _generateColumnWithSubtasksReceiptBytes(
        tasks,
        columnTitle,
        hierarchyPath,
      );
      return await printJob(printerId, columnBytes);
    } catch (e) {
      LoggingService.error('Error in print column with subtasks: $e');
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

      List<int> allBytes = [];
      for (final task in incompleteTasks) {
        final slipBytes = await _generateIndividualSlipBytes(
          task,
          hierarchyPath,
        );
        allBytes.addAll(slipBytes);
      }

      return await printJob(printerId, allBytes);
    } catch (e) {
      LoggingService.error('Error in print individual slips: $e');
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

      List<int> allBytes = [];
      for (final task in incompleteTasks) {
        final slipBytes = await _generateIndividualSlipWithSubtasksBytes(
          task,
          hierarchyPath,
        );
        allBytes.addAll(slipBytes);
      }

      return await printJob(printerId, allBytes);
    } catch (e) {
      LoggingService.error('Error in print individual slips with subtasks: $e');
      return false;
    }
  }

  Future<List<int>> _generateColumnWithSubtasksReceiptBytes(
    List<Task> tasks,
    String? columnTitle,
    String? hierarchyPath,
  ) async {
    final generator = await _createGenerator();

    List<int> bytes = [];
    bytes += generator.reset();

    if (hierarchyPath != null && hierarchyPath != columnTitle) {
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

    if (_isBarcodeTitle(columnTitle)) {
      bytes += _addBarcodeToReceipt(generator, columnTitle!, null);
      bytes += generator.text('');
    } else {
      final title = columnTitle ?? 'TaskWire Column';
      bytes += _wrapTextForSize2(
        generator,
        title,
        align: PosAlign.center,
        bold: true,
      );
    }

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    if (tasks.isNotEmpty) {
      bytes += generator.text(
        'Tasks: ${tasks.length}',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      );
      bytes += generator.hr(len: 42);
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        if (_isBarcodeTask(task)) {
          bytes += _addBarcodeToReceipt(generator, task.title, task);
        } else {
          bytes += generator.text(
            '[${task.isCompleted ? 'X' : ' '}] ${task.title}',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              bold: task.isCompleted,
            ),
          );
        }

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
      
      if (_isBarcodeTask(subtask)) {
        bytes += _addBarcodeToReceipt(generator, subtask.title, subtask, indent);
      } else {
        bytes += generator.text(
          '$indent[${subtask.isCompleted ? 'X' : ' '}] ${subtask.title}',
          styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            bold: subtask.isCompleted,
          ),
        );
      }

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
    String? hierarchyPath,
  ) async {
    final generator = await _createGenerator();

    List<int> bytes = [];
    bytes += generator.reset();

    if (hierarchyPath != null && hierarchyPath != columnTitle) {
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

    if (_isBarcodeTitle(columnTitle)) {
      bytes += _addBarcodeToReceipt(generator, columnTitle!, null);
      bytes += generator.text('');
    } else {
      final title = columnTitle ?? 'TaskWire Column';
      bytes += _wrapTextForSize2(
        generator,
        title,
        align: PosAlign.center,
        bold: true,
      );
    }

    bytes += generator.text(
      'Date: ${DateTime.now().toString().split('.')[0]}',
      styles: PosStyles(
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        align: PosAlign.center,
      ),
    );

    if (tasks.isNotEmpty) {
      bytes += generator.text(
        'Tasks: ${tasks.length}',
        styles: PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      );
      bytes += generator.hr(len: 42);
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        if (_isBarcodeTask(task)) {
          bytes += _addBarcodeToReceipt(generator, task.title, task);
        } else {
          bytes += generator.text(
            '[${task.isCompleted ? 'X' : ' '}] ${task.title}',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              bold: task.isCompleted,
            ),
          );
        }

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
    bytes += generator.cut();
    return bytes;
  }

  Future<List<int>> _generateTestReceiptBytes() async {
    final generator = await _createGenerator();

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += _wrapTextForSize2(
      generator,
      'TaskWire Printer Test',
      align: PosAlign.center,
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
            LoggingService.error('Error disconnecting network printer: $e');
          }
          _networkPrinters.remove(printerId);
        }
      }

      printer.isConnected = false;
      await _repository.updatePrinter(printer);
    } catch (e) {
      LoggingService.error('Error disconnecting printer: $e');
    }
  }

  void dispose() {
    for (final networkPrinter in _networkPrinters.values) {
      try {
        networkPrinter.disconnect();
      } catch (e) {
        LoggingService.error('Error disposing network printer: $e');
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
    String? hierarchyPath,
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
        if (!context.mounted) {
          return PrintResult(
            success: false,
            errorMessage: 'Widget was disposed before printer selection.',
            errorType: PrintErrorType.cancelled,
          );
        }
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

      if (!context.mounted) {
        return PrintResult(
          success: false,
          errorMessage: 'Widget was disposed during printer selection.',
          errorType: PrintErrorType.cancelled,
        );
      }

      bool success;
      switch (printType) {
        case 'checklist':
          success = includeSubtasks
              ? await printColumnWithSubtasks(
                  selectedPrinterId,
                  tasks,
                  columnTitle: levelTitle,
                  hierarchyPath: hierarchyPath,
                )
              : await printColumn(
                  selectedPrinterId,
                  tasks,
                  columnTitle: levelTitle,
                  hierarchyPath: hierarchyPath,
                );
          break;
        case 'individual_slips':
          success = includeSubtasks
              ? await printIndividualSlipsWithSubtasks(
                  selectedPrinterId,
                  tasks,
                  hierarchyPath: hierarchyPath ?? levelTitle,
                )
              : await printIndividualSlips(
                  selectedPrinterId,
                  tasks,
                  hierarchyPath: hierarchyPath ?? levelTitle,
                );
          break;
        default:
          success = includeSubtasks
              ? await printColumnWithSubtasks(
                  selectedPrinterId,
                  tasks,
                  columnTitle: levelTitle,
                  hierarchyPath: hierarchyPath,
                )
              : await printColumn(
                  selectedPrinterId,
                  tasks,
                  columnTitle: levelTitle,
                  hierarchyPath: hierarchyPath,
                );
      }

      if (success) {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        final typeText = printType == 'individual_slips'
            ? 'individual slips'
            : 'checklist';

        String successMessage;
        if (printType == 'individual_slips') {
          final incompleteCount = tasks
              .where((task) => !task.isCompleted)
              .length;
          if (incompleteCount == 0) {
            successMessage =
                'No incomplete tasks to print for level "$levelTitle"';
          } else {
            successMessage =
                '$incompleteCount incomplete task${incompleteCount == 1 ? '' : 's'} from level "$levelTitle" printed as $typeText successfully';
          }
        } else {
          successMessage =
              'Level "$levelTitle" $actionText printed as $typeText successfully';
        }

        return PrintResult(success: true, successMessage: successMessage);
      } else {
        final actionText = includeSubtasks ? 'with subtasks' : '';
        final typeText = printType == 'individual_slips'
            ? 'individual slips'
            : 'checklist';
        return PrintResult(
          success: false,
          errorMessage: 'Failed to print level $actionText as $typeText',
          errorType: PrintErrorType.printFailed,
        );
      }
    } catch (e) {
      final actionText = includeSubtasks ? 'with subtasks' : '';
      final typeText = printType == 'individual_slips'
          ? 'individual slips'
          : 'checklist';
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
    final generator = await _createGenerator();

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

    if (_isBarcodeTask(task)) {
      bytes += _addBarcodeToReceipt(generator, task.title, task);
    } else {
      bytes += _wrapTextForSize2(
        generator,
        task.title,
        align: PosAlign.center,
        bold: true,
      );
    }

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
    final generator = await _createGenerator();

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

    if (_isBarcodeTask(task)) {
      bytes += _addBarcodeToReceipt(generator, task.title, task);
    } else {
      bytes += _wrapTextForSize2(
        generator,
        task.title,
        align: PosAlign.left,
        bold: true,
      );
    }

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
      
      if (_isBarcodeTask(subtask)) {
        bytes += _addBarcodeToReceipt(generator, subtask.title, subtask, indent);
      } else {
        bytes += generator.text(
          '$indent[${subtask.isCompleted ? 'X' : ' '}] ${subtask.title}',
          styles: PosStyles(height: PosTextSize.size1, width: PosTextSize.size1),
        );
      }

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

  bool _isBarcodeTask(Task task) {
    return _getBarcodeType(task.title) != null;
  }

  bool _isBarcodeTitle(String? title) {
    return title != null && _getBarcodeType(title) != null;
  }

  BarcodeType? _getBarcodeType(String content) {
    final upperContent = content.toUpperCase();
    
    if (upperContent.startsWith('QR:')) {
      return BarcodeType.qr;
    } else if (upperContent.startsWith('CODE39:') || upperContent.startsWith('C39:')) {
      return BarcodeType.code39;
    } else if (upperContent.startsWith('CODE128:') || upperContent.startsWith('C128:')) {
      return BarcodeType.code128;
    } else if (upperContent.startsWith('UPCA:') || upperContent.startsWith('UPC:')) {
      return BarcodeType.upcA;
    }
    return null;
  }

  String _getBarcodeContent(String content) {
    final type = _getBarcodeType(content);
    if (type == null) return '';
    
    final upperContent = content.toUpperCase();
    
    switch (type) {
      case BarcodeType.qr:
        return content.substring(3).trim();
      case BarcodeType.code39:
        if (upperContent.startsWith('CODE39:')) {
          return content.substring(7).trim();
        } else if (upperContent.startsWith('C39:')) {
          return content.substring(4).trim();
        }
        break;
      case BarcodeType.code128:
        if (upperContent.startsWith('CODE128:')) {
          return content.substring(8).trim();
        } else if (upperContent.startsWith('C128:')) {
          return content.substring(5).trim();
        }
        break;
      case BarcodeType.upcA:
        if (upperContent.startsWith('UPCA:')) {
          return content.substring(5).trim();
        } else if (upperContent.startsWith('UPC:')) {
          return content.substring(4).trim();
        }
        break;
    }
    return '';
  }

  List<int> _convertToCode39Data(String content) {
    List<int> result = [];
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      final codeUnit = char.codeUnitAt(0);
      
      if (codeUnit >= 48 && codeUnit <= 57) {
        result.add(int.parse(char));
      } else if (codeUnit >= 65 && codeUnit <= 90) {
        result.add(codeUnit - 55);
      } else if (codeUnit >= 97 && codeUnit <= 122) {
        result.add(codeUnit - 87);
      }
    }
    return result;
  }

  List<dynamic> _convertToCode128Data(String content) {
    String processedContent = content.replaceAll(' ', '');
    
    if (!processedContent.startsWith('{A') && !processedContent.startsWith('{B') && !processedContent.startsWith('{C')) {
      processedContent = '{B$processedContent';
    }
    
    return processedContent.split('');
  }

  List<int> _convertToUpcAData(String content) {
    List<int> result = [];
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      final codeUnit = char.codeUnitAt(0);
      
      if (codeUnit >= 48 && codeUnit <= 57) {
        result.add(int.parse(char));
      }
    }
    return result;
  }

  List<int> _addBarcodeToReceipt(Generator generator, String content, Task? task, [String? indent]) {
    List<int> bytes = [];
    final barcodeType = _getBarcodeType(content);
    final barcodeContent = _getBarcodeContent(content);
    
    if (barcodeType == null || barcodeContent.isEmpty) {
      if (task != null) {
        bytes += generator.text(
          '${indent ?? ''}[${task.isCompleted ? 'X' : ' '}] $content',
          styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            bold: task.isCompleted,
          ),
        );
      } else {
        bytes += generator.text(
          '${indent ?? ''}$content',
          styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        );
      }
      return bytes;
    }

    switch (barcodeType) {
      case BarcodeType.qr:
        bytes += generator.qrcode(barcodeContent);
        break;
      case BarcodeType.code39:
        try {
          final barData = _convertToCode39Data(barcodeContent);
          bytes += generator.barcode(Barcode.code39(barData));
        } catch (e) {
          LoggingService.error('Error generating Code 39 barcode: $e');
          bytes += generator.text(
            '${indent ?? ''}Code 39 Error: $barcodeContent',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          );
        }
        break;
      case BarcodeType.code128:
        try {
          final barData = _convertToCode128Data(barcodeContent);
          bytes += generator.barcode(Barcode.code128(barData));
        } catch (e) {
          LoggingService.error('Error generating Code 128 barcode: $e');
          bytes += generator.text(
            '${indent ?? ''}Code 128 Error: $barcodeContent',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          );
        }
        break;
      case BarcodeType.upcA:
        try {
          final barData = _convertToUpcAData(barcodeContent);
          bytes += generator.barcode(Barcode.upcA(barData));
        } catch (e) {
          LoggingService.error('Error generating UPC-A barcode: $e');
          bytes += generator.text(
            '${indent ?? ''}UPC-A Error: $barcodeContent',
            styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          );
        }
        break;
    }
    
    bytes += generator.text('');
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

  List<int> _wrapTextForSize2(
    Generator generator,
    String text, {
    PosAlign align = PosAlign.left,
    bool bold = false,
  }) {
    return generator.text(
      text.trim(),
      styles: PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: align,
        bold: bold,
      ),
      maxCharsPerLine: 14,
    );
  }
}
