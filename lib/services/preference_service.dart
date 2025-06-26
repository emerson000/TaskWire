import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _columnWidthPrefix = 'column_width_';
  static const double _defaultColumnWidth = 350.0;

  static Future<void> saveColumnWidth(int columnIndex, double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_columnWidthPrefix$columnIndex', width);
  }

  static Future<double> getColumnWidth(int columnIndex) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_columnWidthPrefix$columnIndex') ?? _defaultColumnWidth;
  }

  static Future<Map<int, double>> getAllColumnWidths() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final columnWidths = <int, double>{};

    for (final key in keys) {
      if (key.startsWith(_columnWidthPrefix)) {
        final columnIndex = int.tryParse(key.substring(_columnWidthPrefix.length));
        if (columnIndex != null) {
          final width = prefs.getDouble(key);
          if (width != null) {
            columnWidths[columnIndex] = width;
          }
        }
      }
    }

    return columnWidths;
  }

  static Future<void> clearColumnWidth(int columnIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_columnWidthPrefix$columnIndex');
  }

  static Future<void> clearAllColumnWidths() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_columnWidthPrefix)) {
        await prefs.remove(key);
      }
    }
  }
} 