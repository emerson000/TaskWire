import 'dart:io';

void main() async {
  final hooksDir = Directory('.git/hooks');
  if (!await hooksDir.exists()) {
    print('Error: .git/hooks directory not found');
    exit(1);
  }

  final hookFile = File('.git/hooks/pre-commit');
  final content = '#!/bin/sh\ndart version_increment.dart\ngit add pubspec.yaml';

  await hookFile.writeAsString(content);
  
  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['+x', '.git/hooks/pre-commit']);
    if (result.exitCode != 0) {
      print('Warning: Failed to make hook executable: ${result.stderr}');
    }
  }

  print('Version increment hook installed successfully!');
} 