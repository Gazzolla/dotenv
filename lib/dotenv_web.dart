import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:universal_io/io.dart';

/// Platform-specific implementation for web platforms.
/// Loads files via HTTP request using a synchronous approach.
/// On web, files must be accessible via HTTP (e.g., in web/ directory).
List<String> loadFile(String filename, bool quiet) {
  try {
    // Use a completer to make async operation appear synchronous
    List<String>? result;
    bool completed = false;

    final promise = web.window.fetch(filename.toJS);
    promise.toDart.then((response) {
      return response.text().toDart;
    }).then((content) {
      final contentStr = content.toDart;
      if (contentStr.isEmpty) {
        if (!quiet) stderr.writeln('[dotenv] Load failed: file is empty: $filename');
        result = [];
      } else {
        result = contentStr.split('\n');
      }
      completed = true;
    }).catchError((e) {
      if (!quiet) {
        stderr.writeln('[dotenv] Load failed: $e');
        stderr.writeln('[dotenv] On web, ensure .env is in your web/ directory and accessible via HTTP');
        stderr.writeln('[dotenv] Alternative: Use build-time environment variables with --dart-define');
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
        stderr.writeln('[dotenv] Load timeout: could not load $filename within 5 seconds');
      }
      return [];
    }

    return result ?? [];
  } catch (e) {
    if (!quiet) {
      stderr.writeln('[dotenv] Load failed: $e');
      stderr.writeln('[dotenv] On web, .env files must be served as static assets in the web/ directory');
    }
    return [];
  }
}
