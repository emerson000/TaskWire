import 'dart:io';
import 'lib/services/logging_service.dart';

void main() async {
  final hooksDir = Directory('.git/hooks');
  if (!await hooksDir.exists()) {
    LoggingService.error('Error: .git/hooks directory not found');
    exit(1);
  }

  final hookFile = File('.git/hooks/pre-commit');
  final content = '#!/bin/sh\ndart version_increment.dart\ngit add pubspec.yaml';

  await hookFile.writeAsString(content);
  
  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['+x', '.git/hooks/pre-commit']);
    if (result.exitCode != 0) {
      LoggingService.warning('Warning: Failed to make hook executable: ${result.stderr}');
    }
  }

  LoggingService.info('Version increment hook installed successfully!');
} 