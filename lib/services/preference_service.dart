import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PreferenceService {
  static const String _columnWidthPrefix = 'column_width_';
  static const double _defaultColumnWidth = 350.0;
  static const String _themeModeKey = 'theme_mode';

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

  static Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode.name);
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => ThemeMode.system,
      );
    }
    return ThemeMode.system;
  }

  static Future<void> clearThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeModeKey);
  }
} 