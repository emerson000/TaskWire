import 'package:uuid/uuid.dart';

enum PrinterType { usb, network }

class Printer {
  final String id;
  final String name;
  final PrinterType type;
  final String address;
  bool isConnected;
  DateTime? lastSeen;

  Printer({
    String? id,
    required this.name,
    required this.type,
    required this.address,
    this.isConnected = false,
    this.lastSeen,
  }) : id = id ?? const Uuid().v4();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Printer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
