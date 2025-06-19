import 'package:taskwire/models/printer.dart';
import 'package:taskwire/models/task.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_usb/print_usb.dart';
import 'dart:io';

class PrinterService {
  final PrinterRepository _repository;

  PrinterService(this._repository);

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
    if (Platform.isWindows) {
      return await _scanWindowsUsbPrinters();
    } else {
      return await _scanMockPrinters();
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

      if (printer.type == PrinterType.usb && Platform.isWindows) {
        final connected = await PrintUsb.connect(name: printer.address);
        if (connected) {
          printer.isConnected = true;
          await _repository.updatePrinter(printer);
        }
        return connected;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        printer.isConnected = true;
        await _repository.updatePrinter(printer);
        return true;
      }
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  Future<bool> printJob(String printerId, List<int> bytes) async {
    try {
      final printers = await _repository.getPrinters();
      final printer = printers.firstWhere((p) => p.id == printerId);

      if (printer.type == PrinterType.usb && Platform.isWindows) {
        final devices = await PrintUsb.getList();
        final device = devices.firstWhere(
          (d) => d.name == printer.address,
          orElse: () => throw Exception('USB printer not found'),
        );

        final connected = await PrintUsb.connect(name: device.name);
        if (!connected) {
          throw Exception('Failed to connect to USB printer');
        }

        final success = await PrintUsb.printBytes(bytes: bytes, device: device);
        return success;
      } else {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
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
}
