import 'package:universal_io/io.dart';

/// Platform-specific implementation for non-web platforms (IO).
/// Loads files from the file system.
List<String> loadFile(String filename, bool quiet) {
  try {
    var f = File.fromUri(Uri.file(filename));
    if (!f.existsSync()) {
      if (!quiet) stderr.writeln('[dotenv] Load failed: file not found: $f');
      return [];
    }
    return f.readAsLinesSync();
  } catch (e) {
    if (!quiet) stderr.writeln('[dotenv] Load failed: $e');
    return [];
  }
}

