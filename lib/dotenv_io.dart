import 'package:universal_io/io.dart';

/// Platform-specific implementation for non-web platforms (IO).
/// Loads files from the file system.
List<String> loadFile(String filename, bool quiet) {
  if (!quiet) {
    stderr.writeln('[dotenv] DEBUG: ========================================');
    stderr.writeln('[dotenv] DEBUG: Using IO implementation (dotenv_io.dart)');
    stderr.writeln('[dotenv] DEBUG: File path: $filename');
    stderr.writeln('[dotenv] DEBUG: ========================================');
  }
  
  try {
    var f = File.fromUri(Uri.file(filename));
    if (!quiet) {
      stderr.writeln('[dotenv] DEBUG: Created File object: ${f.path}');
    }
    
    // Check if file operations are supported (not web)
    try {
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: Checking if file exists...');
      }
      if (!f.existsSync()) {
        if (!quiet) {
          stderr.writeln('[dotenv] Load failed: file not found: $f');
        }
        return [];
      }
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: File exists, reading lines...');
      }
      var lines = f.readAsLinesSync();
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: Successfully read ${lines.length} lines');
      }
      return lines;
    } catch (e, stackTrace) {
      // If existsSync throws "Unsupported operation: _Namespace", we're on web
      // This shouldn't happen if import condicional works, but as fallback:
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: Error during file operation: $e');
        stderr.writeln('[dotenv] DEBUG: Stack trace: $stackTrace');
      }
      
      if (e.toString().contains('Unsupported operation') || 
          e.toString().contains('_Namespace')) {
        if (!quiet) {
          stderr.writeln('[dotenv] ERROR: Web platform detected in IO implementation!');
          stderr.writeln('[dotenv] ERROR: This means the conditional import failed!');
          stderr.writeln('[dotenv] ERROR: Expected: dotenv_web.dart, Got: dotenv_io.dart');
          stderr.writeln('[dotenv] Web platform detected. File system not available.');
          stderr.writeln('[dotenv] On web, ensure .env is accessible via HTTP.');
        }
        return [];
      }
      rethrow;
    }
  } catch (e, stackTrace) {
    if (!quiet) {
      stderr.writeln('[dotenv] ERROR: Load failed with exception: $e');
      stderr.writeln('[dotenv] ERROR: Stack trace: $stackTrace');
    }
    return [];
  }
}

