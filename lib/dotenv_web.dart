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
/// Loads files via HTTP request using a synchronous approach.
/// On web, files must be accessible via HTTP (e.g., in web/ directory).
/// Tries to load from root first, then falls back to web/ directory.
List<String> loadFile(String filename, bool quiet) {
  // Lista de caminhos para tentar (raiz primeiro, depois web/)
  final pathsToTry = <String>[];

  if (filename.startsWith('/')) {
    // Caminho absoluto - tenta diretamente
    pathsToTry.add(filename);
  } else {
    // Tenta na raiz primeiro
    pathsToTry.add('/$filename');
    // Depois tenta relativo (web/)
    pathsToTry.add(filename);
  }

  for (var path in pathsToTry) {
    final absolutePath = _getAbsolutePath(path);
    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: ========================================');
      _safeStderrWriteln('[dotenv] DEBUG: Using WEB implementation (dotenv_web.dart)');
      _safeStderrWriteln('[dotenv] DEBUG: Attempting to load from: $absolutePath');
      _safeStderrWriteln('[dotenv] DEBUG: ========================================');
    }

    final result = _tryLoadFile(absolutePath, path, quiet);
    if (result != null) {
      return result;
    }
  }

  // Se nenhum caminho funcionou, retorna vazio
  if (!quiet) {
    _safeStderrWriteln('[dotenv] Load failed: could not find .env in root or web/ directory');
    _safeStderrWriteln('[dotenv] Tried paths: ${pathsToTry.join(", ")}');
  }
  return [];
}

/// Tenta carregar um arquivo e retorna null se falhar
List<String>? _tryLoadFile(String absolutePath, String originalPath, bool quiet) {
  try {
    // Use a completer to make async operation appear synchronous
    List<String>? result;
    bool completed = false;
    bool success = false;

    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: Starting HTTP fetch for: $absolutePath');
    }
    final promise = web.window.fetch(absolutePath.toJS);
    promise.toDart.then((response) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP response received, status: ${response.status}');
      }

      // Se não for sucesso (200-299), marca como falha
      if (response.status < 200 || response.status >= 300) {
        if (!quiet) {
          _safeStderrWriteln('[dotenv] DEBUG: HTTP status ${response.status}, trying next path...');
        }
        completed = true;
        return response.text().toDart; // Continua para tratar no próximo then
      }

      return response.text().toDart;
    }).then((content) {
      final contentStr = content.toDart;

      // Se status não foi sucesso, content pode estar vazio ou com erro
      if (contentStr.isEmpty) {
        if (!quiet) _safeStderrWriteln('[dotenv] DEBUG: File is empty or not found, trying next path...');
        completed = true;
        return;
      }

      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Content length: ${contentStr.length}');
      }

      // Split by newlines and filter out empty lines
      result = contentStr.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      success = true;
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Successfully loaded from: $absolutePath');
        _safeStderrWriteln('[dotenv] DEBUG: Split into ${result!.length} non-empty lines');
        for (var i = 0; i < result!.length; i++) {
          _safeStderrWriteln('[dotenv] DEBUG: Parsed line ${i + 1}: "${result![i]}"');
        }
      }
      completed = true;
    }).catchError((e) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch error for $absolutePath: $e');
        _safeStderrWriteln('[dotenv] DEBUG: Trying next path...');
      }
      completed = true;
    });

    // Wait for the async operation to complete
    // This is a blocking wait that works in web context
    // Use a longer timeout and better event loop processing
    final timeoutMs = 10000; // 10 seconds timeout
    final maxIterations = timeoutMs ~/ 10; // Check every 10ms
    int iterations = 0;
    
    while (!completed && iterations < maxIterations) {
      iterations++;
      
      // Use performance.now() for more accurate timing
      final startTime = web.window.performance.now();
      // Wait 10ms - this allows the event loop to process
      while ((web.window.performance.now() - startTime) < 10) {
        // Small busy wait to allow event loop processing
      }
      
      // Double check completion status
      if (completed) break;
    }

    if (!completed) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Load timeout for $absolutePath, trying next path...');
      }
      return null;
    }

    if (success && result != null) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch completed. Result: ${result!.length} lines');
      }
      return result;
    }

    return null;
  } catch (e) {
    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: Exception loading $absolutePath: $e');
    }
    return null;
  }
}
