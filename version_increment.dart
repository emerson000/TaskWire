import 'dart:io';
import 'lib/services/logging_service.dart';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    LoggingService.error('Error: pubspec.yaml not found');
    exit(1);
  }

  final content = await pubspecFile.readAsString();
  final versionRegex = RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)');
  final match = versionRegex.firstMatch(content);
  
  if (match == null) {
    LoggingService.error('Error: Could not find version in pubspec.yaml');
    exit(1);
  }

  final version = match.group(1);
  final buildNumber = int.parse(match.group(2)!);
  final newBuildNumber = buildNumber + 1;
  
  final newContent = content.replaceFirst(
    versionRegex,
    'version: $version+$newBuildNumber'
  );

  await pubspecFile.writeAsString(newContent);
  LoggingService.info('Incremented build number to $newBuildNumber');
} 