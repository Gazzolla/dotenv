import 'dart:async';
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

    final result = _tryLoadFile(absolutePath, filename, quiet);
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
List<String>? _tryLoadFile(String absolutePath, String originalPath, bool quiet) {
  try {
    // Use a completer to make async operation appear synchronous
    List<String>? result;
    bool completed = false;
    bool success = false;

    final promise = web.window.fetch(absolutePath.toJS);
    promise.toDart.then((response) {
      // Se não for sucesso (200-299), marca como falha
      if (response.status < 200 || response.status >= 300) {
        if (!quiet) {
          _safeStderrWriteln('[dotenv] DEBUG: HTTP status ${response.status}, trying next path...');
        }
        completed = true;
        return response.text().toDart;
      }

      return response.text().toDart;
    }).then((content) {
      final contentStr = content.toDart;

      // Se status não foi sucesso, content pode estar vazio ou com erro
      if (contentStr.isEmpty) {
        if (!quiet) {
          _safeStderrWriteln('[dotenv] DEBUG: File is empty, trying next path...');
        }
        completed = true;
        return;
      }

      // Split by newlines and filter out empty lines
      result = contentStr.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      success = true;
      completed = true;
    }).catchError((e) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch error: $e');
      }
      completed = true;
    });

    // Wait for the async operation to complete
    // This is a blocking wait that works in web context
    // The key is to use scheduleMicrotask to yield to event loop
    // This allows fetch callbacks to be processed
    final timeoutMs = 10000; // 10 seconds timeout
    final startTime = web.window.performance.now();
    int checkCount = 0;
    const maxChecks = 20000; // Maximum number of checks
    
    while (!completed && checkCount < maxChecks) {
      checkCount++;
      
      // Schedule a microtask to yield to event loop
      // This is critical - it allows the fetch callbacks to be processed
      var microtaskCompleted = false;
      scheduleMicrotask(() {
        microtaskCompleted = true;
      });
      
      // Wait for microtask to complete - this yields to event loop
      // The microtask will be processed by the event loop
      var waitIterations = 0;
      while (!microtaskCompleted && waitIterations < 100) {
        waitIterations++;
        // Very short wait to allow microtask processing
        final waitStart = web.window.performance.now();
        while ((web.window.performance.now() - waitStart) < 0.01) {
          // Minimal wait - allows event loop to process microtasks
        }
      }
      
      // Check elapsed time using wall clock time
      final elapsed = web.window.performance.now() - startTime;
      if (elapsed > timeoutMs) {
        if (!quiet) {
          _safeStderrWriteln('[dotenv] DEBUG: Timeout after ${elapsed.toStringAsFixed(0)}ms');
        }
        break;
      }
      
      // Check completion status - this should be set by the promise callbacks
      if (completed) {
        break;
      }
    }

    if (!completed) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Load timeout for $absolutePath, trying next path...');
      }
      return null;
    }

    if (success && result != null) {
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
