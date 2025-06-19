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

  Future<void> addManualPrinter(String ipAddress) async {
    final printer = Printer(
      name: 'Network Printer',
      type: PrinterType.network,
      address: ipAddress,
    );
    await addPrinter(printer);
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
        subtitle: Text(
          '${printer.type.name.toUpperCase()}: ${printer.address}',
        ),
        trailing: IconButton(
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
      ),
    );
  }

  Widget _buildScannedPrinterTile(BuildContext context, Printer printer) {
    final provider = Provider.of<PrinterProvider>(context, listen: false);
    return Card(
      child: ListTile(
        title: Text(printer.name),
        subtitle: Text(
          '${printer.type.name.toUpperCase()}: ${printer.address}',
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
    final ipController = TextEditingController();
    final provider = Provider.of<PrinterProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Network Printer Manually'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              labelText: 'Printer IP Address',
              hintText: '192.168.1.100',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (ipController.text.isNotEmpty) {
                  // Basic validation, can be improved with a regex
                  provider.addManualPrinter(ipController.text);
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
