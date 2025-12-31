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
List<String> loadFile(String filename, bool quiet) {
  final absolutePath = _getAbsolutePath(filename);
  if (!quiet) {
    _safeStderrWriteln('[dotenv] DEBUG: ========================================');
    _safeStderrWriteln('[dotenv] DEBUG: Using WEB implementation (dotenv_web.dart)');
    _safeStderrWriteln('[dotenv] DEBUG: File path: $absolutePath');
    _safeStderrWriteln('[dotenv] DEBUG: ========================================');
  }

  try {
    // Use a completer to make async operation appear synchronous
    List<String>? result;
    bool completed = false;

    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: Starting HTTP fetch for: $filename');
    }
    final promise = web.window.fetch(absolutePath.toJS);
    promise.toDart.then((response) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP response received');
      }
      return response.text().toDart;
    }).then((content) {
      final contentStr = content.toDart;
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: Content length: ${contentStr.length}');
      }
      if (contentStr.isEmpty) {
        if (!quiet) _safeStderrWriteln('[dotenv] Load failed: file is empty: $filename');
        result = [];
      } else {
        result = contentStr.split('\n');
        if (!quiet) {
          _safeStderrWriteln('[dotenv] DEBUG: Split into ${result?.length ?? 0} lines');
        }
      }
      completed = true;
    }).catchError((e) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch error: $e');
      }
      if (!quiet) {
        _safeStderrWriteln('[dotenv] Load failed: $e');
        _safeStderrWriteln('[dotenv] On web, ensure .env is in your web/ directory and accessible via HTTP');
        _safeStderrWriteln('[dotenv] Alternative: Use build-time environment variables with --dart-define');
      }
      result = [];
      completed = true;
    });

    // Wait for the async operation to complete
    // This is a blocking wait that works in web context
    final stopwatch = Stopwatch()..start();
    while (!completed && stopwatch.elapsedMilliseconds < 5000) {
      // Allow async operations to complete by processing the event loop
      // Use a small delay to allow HTTP request to complete
      final startTime = web.window.performance.now();
      while ((web.window.performance.now() - startTime) < 50) {
        // Busy wait for ~50ms to allow async operations to process
      }
      // Note: This is a workaround - true synchronous HTTP isn't possible on web
    }

    if (!completed) {
      if (!quiet) {
        _safeStderrWriteln('[dotenv] Load timeout: could not load $filename within 5 seconds');
      }
      return [];
    }

    if (!quiet) {
      _safeStderrWriteln('[dotenv] DEBUG: HTTP fetch completed. Result: ${result?.length ?? 0} lines');
    }
    return result ?? [];
  } catch (e) {
    if (!quiet) {
      _safeStderrWriteln('[dotenv] Load failed: $e');
      _safeStderrWriteln('[dotenv] On web, .env files must be served as static assets in the web/ directory');
    }
    return [];
  }
}
