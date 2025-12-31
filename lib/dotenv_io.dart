import 'package:universal_io/io.dart';

/// Platform-specific implementation for non-web platforms (IO).
/// Loads files from the file system.
List<String> loadFile(String filename, bool quiet) {
  try {
    var f = File.fromUri(Uri.file(filename));
    // Check if file operations are supported (not web)
    try {
      if (!f.existsSync()) {
        if (!quiet) stderr.writeln('[dotenv] Load failed: file not found: $f');
        return [];
      }
      return f.readAsLinesSync();
    } catch (e) {
      // If existsSync throws "Unsupported operation: _Namespace", we're on web
      // This shouldn't happen if import condicional works, but as fallback:
      if (e.toString().contains('Unsupported operation') || 
          e.toString().contains('_Namespace')) {
        if (!quiet) {
          stderr.writeln('[dotenv] Web platform detected. File system not available.');
          stderr.writeln('[dotenv] On web, ensure .env is accessible via HTTP.');
        }
        return [];
      }
      rethrow;
    }
  } catch (e) {
    if (!quiet) stderr.writeln('[dotenv] Load failed: $e');
    return [];
  }
}

