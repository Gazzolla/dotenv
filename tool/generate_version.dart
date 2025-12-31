import 'dart:io';

void main(List<String> args) {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  final content = pubspec.readAsStringSync();
  final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);

  if (versionMatch == null) {
    print('Error: version not found in pubspec.yaml');
    exit(1);
  }

  final currentVersion = versionMatch.group(1)!.trim();
  String newVersion;

  // Se um argumento foi passado, usa essa versão
  if (args.isNotEmpty) {
    newVersion = args[0].trim();
    if (!_isValidVersion(newVersion)) {
      print('Error: Invalid version format: $newVersion');
      print('Expected format: MAJOR.MINOR.PATCH (e.g., 1.2.3)');
      exit(1);
    }
  } else {
    // Por padrão, incrementa o patch version (+1)
    newVersion = _incrementVersion(currentVersion);
  }

  // Atualiza o pubspec.yaml
  final updatedContent = content.replaceFirst(
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $newVersion',
  );
  pubspec.writeAsStringSync(updatedContent);

  // Gera o version.dart
  final versionFile = File('lib/version.dart');
  versionFile.writeAsStringSync('''
// This file is generated automatically by tool/generate_version.dart
// Do not edit manually.

/// Package version from pubspec.yaml
const String packageVersion = '$newVersion';
''');

  print('Version updated: $currentVersion -> $newVersion');
  print('Updated pubspec.yaml and generated lib/version.dart');
}

/// Incrementa o patch version (último número) em +1
String _incrementVersion(String version) {
  final parts = version.split('.');
  if (parts.length < 3) {
    print('Warning: Version format may be incomplete. Expected MAJOR.MINOR.PATCH');
    // Tenta adicionar .0 se faltar
    while (parts.length < 3) {
      parts.add('0');
    }
  }

  final major = int.tryParse(parts[0]) ?? 0;
  final minor = int.tryParse(parts[1]) ?? 0;
  final patch = int.tryParse(parts[2]) ?? 0;

  return '$major.$minor.${patch + 1}';
}

/// Valida o formato da versão (MAJOR.MINOR.PATCH)
bool _isValidVersion(String version) {
  final parts = version.split('.');
  if (parts.length < 2 || parts.length > 3) {
    return false;
  }

  for (final part in parts) {
    if (int.tryParse(part.trim()) == null) {
      return false;
    }
  }

  return true;
}
