import 'dart:js_interop';
// ignore: uri_does_not_exist
import 'package:web/web.dart' as web;

/// Writes to print on web platforms (stderr is not available)
void _safeStderrWriteln(String message) {
  // On web, stderr is not available, use print directly
  print(message);
}

/// Converts a relative path to an absolute URL on web platforms
String _getAbsolutePath(String filename) {
  try {
    final location = web.window.location;

    if (filename.startsWith('http://') || filename.startsWith('https://') || filename.startsWith('//')) {
      return filename;
    }

    final href = (location.href as JSString).toDart;
    final baseUri = Uri.parse(href);
    final basePath = baseUri.resolve('./').toString();

    if (filename.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$filename';
    }

    return Uri.parse(basePath).resolve(filename).toString();
  } catch (e) {
    return filename;
  }
}

/// Platform-specific implementation for web platforms.
/// Loads files via HTTP request using an asynchronous approach.
/// On web, files must be accessible via HTTP (e.g., in web/ directory).
/// Tries to load from root first, then falls back to web/ directory.
Future<List<String>> loadFile(String filename, bool quiet) async {
  // Lista de caminhos absolutos únicos para tentar
  final absolutePathsToTry = <String>{};

  if (filename.startsWith('/')) {
    // Caminho absoluto - tenta diretamente
    absolutePathsToTry.add(_getAbsolutePath(filename));
  } else {
    // Tenta na raiz primeiro
    absolutePathsToTry.add(_getAbsolutePath('/$filename'));
    // Depois tenta relativo (web/)
    absolutePathsToTry.add(_getAbsolutePath(filename));
  }

  if (!quiet) {
    _safeStderrWriteln('[dotenv] DEBUG: Using WEB implementation');
    _safeStderrWriteln('[dotenv] DEBUG: Will try ${absolutePathsToTry.length} unique path(s)');
  }

  for (var absolutePath in absolutePathsToTry) {
    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: Attempting to load from: $absolutePath');
    }

    final result = await _tryLoadFile(absolutePath, filename, quiet);
    if (result != null && result.isNotEmpty) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Successfully loaded ${result.length} line(s) from: $absolutePath');
      }
      return result;
    }
  }

  // Se nenhum caminho funcionou, retorna vazio
  if (!quiet) {
    _safeStderrWriteln('[dotenv] Load failed: could not find .env');
    _safeStderrWriteln('[dotenv] Tried paths: ${absolutePathsToTry.join(", ")}');
  }
  return [];
}

/// Tenta carregar um arquivo e retorna null se falhar
Future<List<String>?> _tryLoadFile(String absolutePath, String originalPath, bool quiet) async {
  try {
    final response = await web.window.fetch(absolutePath.toJS).toDart;
    
    // Se não for sucesso (200-299), retorna null
    if (response.status < 200 || response.status >= 300) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP status ${response.status}, trying next path...');
      }
      return null;
    }

    final content = await response.text().toDart;
    final contentStr = content.toDart;

    // Se content estiver vazio, retorna null
    if (contentStr.isEmpty) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: File is empty, trying next path...');
      }
      return null;
    }

    // Split by newlines and filter out empty lines
    final result = contentStr.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    
    return result;
  } catch (e) {
    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch error: $e');
    }
    return null;
  }
}
