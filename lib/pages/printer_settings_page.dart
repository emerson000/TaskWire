import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taskwire/models/printer.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:taskwire/services/printer_service.dart';
import 'package:get_it/get_it.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService;

  PrinterProvider(this._printerService) {
    _loadPrinters();
  }

  List<Printer> _savedPrinters = [];
  List<Printer> get savedPrinters => _savedPrinters;

  List<Printer> _scannedPrinters = [];
  List<Printer> get scannedPrinters => _scannedPrinters;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  @override
  void dispose() {
    _printerService.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    _savedPrinters = await _printerService.getPrinters();
    notifyListeners();
  }

  Future<void> scanForPrinters() async {
    _isScanning = true;
    _scannedPrinters = [];
    notifyListeners();

    final foundPrinters = await _printerService.scanForPrinters();
    _scannedPrinters = foundPrinters
        .where((p) => !_savedPrinters.any((sp) => sp.address == p.address))
        .toList();

    _isScanning = false;
    notifyListeners();
  }

  Future<void> addPrinter(Printer printer) async {
    await _printerService.addPrinter(printer);
    _scannedPrinters.remove(printer);
    await _loadPrinters();
  }

  Future<void> removePrinter(String printerId) async {
    await _printerService.removePrinter(printerId);
    await _loadPrinters();
  }

  Future<void> addManualPrinter(String name, String ipAddress) async {
    final printer = Printer(
      name: name,
      type: PrinterType.network,
      address: ipAddress,
    );
    await addPrinter(printer);
  }

  Future<bool> connectToPrinter(String printerId) async {
    final success = await _printerService.connectToPrinter(printerId);
    if (success) {
      await _loadPrinters();
    }
    return success;
  }

  Future<void> disconnectPrinter(String printerId) async {
    await _printerService.disconnectPrinter(printerId);
    await _loadPrinters();
  }

  Future<bool> testPrint(String printerId) async {
    return await _printerService.testPrint(printerId);
  }
}

class PrinterSettingsPage extends StatelessWidget {
  const PrinterSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          PrinterProvider(PrinterService(GetIt.I.get<PrinterRepository>())),
      child: Scaffold(
        appBar: AppBar(title: const Text('Printer Settings')),
        body: Consumer<PrinterProvider>(
          builder: (context, provider, child) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(context, 'Saved Printers'),
                if (provider.savedPrinters.isEmpty)
                  const Text('No saved printers.')
                else
                  ...provider.savedPrinters.map(
                    (p) => _buildSavedPrinterTile(context, p),
                  ),
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'Discover Printers'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (Platform.isAndroid || Platform.isWindows)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.isScanning
                            ? null
                            : () => provider.scanForPrinters(),
                        icon: const Icon(Icons.search),
                        label: const Text('Scan for Printers'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddManualPrinterDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Manually'),
                      ),
                    ),
                  ],
                ),
                if (provider.isScanning)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (provider.scannedPrinters.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...provider.scannedPrinters.map(
                    (p) => _buildScannedPrinterTile(context, p),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildSavedPrinterTile(BuildContext context, Printer printer) {
    final provider = Provider.of<PrinterProvider>(context, listen: false);
    return Card(
      child: ListTile(
        title: Text(printer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${printer.type.name.toUpperCase()}: ${printer.address}'),
            if (printer.lastSeen != null)
              Text(
                'Last seen: ${printer.lastSeen!.toString().substring(0, 19)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (printer.type != PrinterType.network)
              IconButton(
                icon: Icon(
                  printer.isConnected ? Icons.link : Icons.link_off,
                  color: printer.isConnected ? Colors.green : Colors.grey,
                ),
                onPressed: () async {
                  if (printer.isConnected) {
                    await provider.disconnectPrinter(printer.id);
                  } else {
                    await provider.connectToPrinter(printer.id);
                  }
                },
                tooltip: printer.isConnected ? 'Disconnect' : 'Connect',
              ),
            IconButton(
              icon: const Icon(Icons.print, color: Colors.blue),
              onPressed: printer.isConnected || printer.type == PrinterType.network
                  ? () => provider.testPrint(printer.id)
                  : null,
              tooltip: 'Test Print',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Printer'),
                    content: Text(
                      'Are you sure you want to remove ${printer.name}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  provider.removePrinter(printer.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedPrinterTile(BuildContext context, Printer printer) {
    final provider = Provider.of<PrinterProvider>(context, listen: false);
    return Card(
      child: ListTile(
        title: Text(printer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${printer.type.name.toUpperCase()}: ${printer.address}'),
            if (printer.lastSeen != null)
              Text(
                'Discovered: ${printer.lastSeen!.toString().substring(0, 19)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: ElevatedButton(
          child: const Text('Add'),
          onPressed: () {
            provider.addPrinter(printer);
          },
        ),
      ),
    );
  }

  void _showAddManualPrinterDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final provider = Provider.of<PrinterProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Network Printer Manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Printer Name',
                  hintText: 'My Network Printer',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Printer IP Address',
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network printers will automatically disconnect after each print job to ensure proper processing.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (nameController.text.isNotEmpty && ipController.text.isNotEmpty) {
                  if (_isValidIpAddress(ipController.text)) {
                    provider.addManualPrinter(nameController.text, ipController.text);
                    Navigator.of(ctx).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid IP address (e.g., 192.168.1.100)'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
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
