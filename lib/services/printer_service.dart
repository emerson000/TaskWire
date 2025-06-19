import 'package:taskwire/models/printer.dart';
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
