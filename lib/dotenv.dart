import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

import 'parser.dart';

// Conditional imports for web support
import 'dotenv_io.dart' if (dart.library.html) 'dotenv_web.dart' as platform;

/// Loads key-value pairs from a file into a [Map<String, String>].
///
/// The parser will attempt to handle simple variable substitution,
/// respect single- vs. double-quotes, and ignore `#comments` or the `export` keyword.
/// Loads environment variables from a `.env` file.
///
/// ## usage
///
/// Call [DotEnv.load] to parse the file(s).
/// Read variables from the underlying [Map] using the `[]` operator.
///
///     import 'package:dotenv/dotenv.dart';
///
///     void main() {
///       var env = DotEnv(includePlatformEnvironment: true)
///         ..load('path/to/my/.env');
///       var foo = env['foo'];
///       var homeDir = env['HOME'];
///       // ...
///     }
///
/// Verify required variables are present:
///
///     const _requiredEnvVars = ['host', 'port'];
///     bool get hasEnv => env.isEveryDefined(_requiredEnvVars);
class DotEnv {
  /// If true, the underlying map will contain the entries of [Platform.environment],
  /// even after calling [clear].
  /// Otherwise, it will be empty until populated by [load].
  final bool includePlatformEnvironment;

  /// If true, suppress "file not found" messages on [stderr] during [load].
  final bool quiet;

  final _map = <String, String>{};

  DotEnv({this.includePlatformEnvironment = false, this.quiet = false}) {
    if (includePlatformEnvironment) _addPlatformEnvironment();
  }

  /// Provides access to the underlying [Map].
  ///
  /// Prefer using [operator[]] to read values.
  @visibleForTesting
  Map<String, String> get map => _map;

  /// Reads the value for [key] from the underlying map.
  ///
  /// Returns `null` if [key] is absent.  See [isDefined].
  String? operator [](String key) => _map[key];

  /// Calls [Map.addAll] on the underlying map.
  void addAll(Map<String, String> other) => _map.addAll(other);

  /// Calls [Map.clear] on the underlying map.
  ///
  /// If [includePlatformEnvironment] is true, the entries of [Platform.environment] will be reinserted.
  void clear() {
    _map.clear();
    if (includePlatformEnvironment) _addPlatformEnvironment();
  }

  /// Equivalent to [operator []] when the underlying map contains [key],
  /// and the value is non-empty.  See [isDefined].
  ///
  /// Otherwise, calls [orElse] and returns the value.
  String getOrElse(String key, String Function() orElse) => isDefined(key) ? _map[key]! : orElse();

  /// True if [key] has a nonempty value in the underlying map.
  ///
  /// Differs from [Map.containsKey] by excluding empty values.
  bool isDefined(String key) => _map[key]?.isNotEmpty ?? false;

  /// True if all supplied [vars] have nonempty value; false otherwise.
  ///
  /// See [isDefined].
  bool isEveryDefined(Iterable<String> vars) => vars.every(isDefined);

  /// Parses environment variables from each path in [filenames], and adds them
  /// to the underlying [Map].
  ///
  /// Automatically detects the platform (web or non-web) and loads files accordingly.
  /// On web, files are loaded via HTTP. On other platforms, files are loaded from the file system.
  ///
  /// Logs to [stderr] if any file does not exist; see [quiet].
  void load([
    Iterable<String> filenames = const ['.env'],
    Parser psr = const Parser(),
  ]) {
    if (!quiet) {
      stderr.writeln('[dotenv] DEBUG: ========================================');
      stderr.writeln('[dotenv] DEBUG: Starting load operation');
      stderr.writeln('[dotenv] DEBUG: Platform: ${Platform.operatingSystem}');
      stderr.writeln('[dotenv] DEBUG: Platform environment available: ${Platform.environment.isNotEmpty}');
      stderr.writeln('[dotenv] DEBUG: dart.library.html available: ${_isWebPlatform()}');
      stderr.writeln('[dotenv] DEBUG: ========================================');
    }

    for (var filename in filenames) {
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: Attempting to load file: $filename');
      }
      var lines = platform.loadFile(filename, quiet);
      if (!quiet) {
        stderr.writeln('[dotenv] DEBUG: Loaded ${lines.length} lines from $filename');
      }
      _map.addAll(psr.parse(lines));
    }

    if (!quiet) {
      stderr.writeln('[dotenv] DEBUG: Load complete. Total variables: ${_map.length}');
    }
  }

  void _addPlatformEnvironment() => _map.addAll(Platform.environment);

  /// Helper to detect if web platform is available
  bool _isWebPlatform() {
    try {
      // Try to check if dart.library.html is available
      // This is a compile-time check, but we can try to detect at runtime
      return false; // Will be determined by conditional import
    } catch (e) {
      return false;
    }
  }
}
