import 'package:drift/drift.dart';
import 'package:taskwire/database/database.dart';
import 'package:taskwire/models/printer.dart';

class PrinterRepository {
  final AppDatabase _db;

  PrinterRepository(this._db);

  Future<List<Printer>> getPrinters() async {
    final entries = await _db.allPrinters;
    return entries
        .map(
          (entry) => Printer(
            id: entry.id,
            name: entry.name,
            type: entry.type,
            address: entry.address,
            lastSeen: entry.lastSeen,
          ),
        )
        .toList();
  }

  Future<String> addPrinter(Printer printer) {
    final entry = PrintersCompanion(
      id: Value(printer.id),
      name: Value(printer.name),
      type: Value(printer.type),
      address: Value(printer.address),
      lastSeen: Value(printer.lastSeen),
    );
    return _db.addPrinter(entry);
  }

  Future<void> removePrinter(String id) {
    return _db.deletePrinter(id);
  }

  Future<void> updatePrinter(Printer printer) {
    final entry = PrinterEntry(
      id: printer.id,
      name: printer.name,
      type: printer.type,
      address: printer.address,
      lastSeen: printer.lastSeen,
    );
    return _db.updatePrinter(entry);
  }
}
