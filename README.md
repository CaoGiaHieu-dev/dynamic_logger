# DynamicLogger

[![pub version](https://img.shields.io/pub/v/dynamic_logger.svg)](https://pub.dev/packages/dynamic_logger) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A flexible and memory-efficient logger for Dart/Flutter applications, providing structured, color-coded output with support for complex data types and truncation.

## Features

-   **Structured Output:** Pretty-prints Maps and Lists in a JSON-like format for easy readability.
-   **Color-Coded Levels:** Differentiates between INFO, WARNING, and ERROR logs using distinct colors (in terminals supporting ANSI codes). Colors can be disabled globally.
-   **Handles Complex Data:** Logs primitives (String, num, bool, null), Maps, Lists, and any object with a `toString()` or `toJson()` method.
-   **Truncation:** Limits output size for large or deeply nested data structures.
    -   Configurable `maxDepth`, `maxCollectionEntries`, and `maxStringLength`.
    -   Can be enabled/disabled globally via `configure()` or per call via `log()`.
-   **Level Filtering:** Set a `minLevel` to silently drop messages below a severity threshold (e.g. suppress INFO in production).
-   **Configuration:** Global defaults via `DynamicLogger.configure()`; per-call overrides via `DynamicLogger.log()` parameters.
-   **Test-Friendly:** `DynamicLogger.reset()` restores all defaults — no state leaks between test cases.
-   **Static Utility:** `DynamicLogger.formatData` formats data into a plain-text string without logging.
-   **Clean Formatting:** Single-line box-drawing headers/footers delimit each log block.

## Installation

Add `dynamic_logger` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  dynamic_logger: ^0.5.0
```
Then run `dart pub get` or `flutter pub get`.

**Note:** This package has no external dependencies and works with Dart SDK >=3.0.0 <4.0.0.

## Basic Usage

Import the package and use the static log method. Formatting runs synchronously, so output appears immediately. For large data structures, enable truncation to limit execution time.

```dart
import 'package:dynamic_logger/dynamic_logger.dart';

void main() {
  // Log a simple message (defaults to INFO)
  DynamicLogger.log('User logged in successfully.');

  // Log with a specific level and tag
  DynamicLogger.log(
    'Configuration file not found, using defaults.',
    level: LogLevel.WARNING,
    tag: 'ConfigLoader',
  );

  // Log an error with a tag
  DynamicLogger.log(
    'Failed to connect to database.',
    level: LogLevel.ERROR,
    tag: 'Database',
    // stackTrace: stackTrace, // Optionally include stack trace
  );

  // Log a Map
  final userData = {'id': 123, 'name': 'Alice', 'isActive': true, 'prefs': {} };
  DynamicLogger.log(userData, tag: 'UserData');

  // Log a List
  final items = ['apple', 10, true, null, {'nested': 'value'}, []];
  DynamicLogger.log(items, tag: 'ItemList');
}
```

### Output Visibility

By default, `DynamicLogger` uses `dart:developer.log` which may not be visible in standard console output. To see logs in your terminal, configure a custom log handler:

```dart
void main() {
  // Configure logger to print to console
  DynamicLogger.configure(
    logHandler: (message, {error, level = 0, name = '', stackTrace, time, zone, sequenceNumber}) {
      print(message);
    },
  );

  DynamicLogger.log('Now you can see this in the console!');
}
```

## Advanced Usage

### Configuration

Set global defaults once (e.g. in `main()`) for the entire application.

```dart
import 'package:dynamic_logger/dynamic_logger.dart';

void setupLogger({bool isProduction = false}) {
  DynamicLogger.configure(
    // Only emit WARNING and ERROR in production
    minLevel: isProduction ? LogLevel.WARNING : LogLevel.INFO,
    // Enable truncation to keep logs readable
    truncate: true,
    maxDepth: 5,
    maxCollectionEntries: 20,
    maxStringLength: 200,
    // Disable ANSI colors when writing to a file sink
    colorEnabled: true,
    // Print to console instead of dart:developer
    logHandler: (message, {error, level = 0, name = '', stackTrace, time, zone, sequenceNumber}) {
      print(message);
    },
  );
}

void main() {
  const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
  setupLogger(isProduction: kReleaseMode);

  DynamicLogger.log({'large': 'data', 'will': 'be', 'truncated': true});
}
```

### Truncation Per Call
Even if you have global defaults, you can override truncation settings for specific log calls.

```dart
final largeJsonData = {
  'users': List.generate(100, (i) => {'id': i, 'name': 'User $i'}),
  'metadata': {'count': 100, 'page': 1}
};

// Log a specific large object WITHOUT truncation for debugging
DynamicLogger.log(
  largeJsonData,
  tag: 'FullDebugData',
  truncate: false, // Disable truncation for this call only
);

// Log another large object with stricter limits than the default
DynamicLogger.log(
  largeJsonData,
  tag: 'BriefOverview',
  truncate: true, // Ensure truncation is on for this call
  maxDepth: 2,
  maxCollectionEntries: 5,
);
```

### Formatting Data (formatData)
Use `formatData` to get the formatted string representation of an object without actually logging it. It respects the configured truncation defaults unless overridden.

```dart
final data = {'a': 1, 'b': [1, 2, 3], 'c': {'d': 'hello'}};

// Format using default truncation settings
String formattedString = DynamicLogger.formatData(data);
print("Formatted Data:\n$formattedString");

// Format with specific truncation for this call
String truncatedString = DynamicLogger.formatData(
  data,
  truncate: true,
  maxDepth: 1,
  maxCollectionEntries: 2,
);
print("\nTruncated Formatted Data:\n$truncatedString");
```

**Output:**
```
Formatted Data:
{
  "a": 1,
  "b":
   [
    1,
    2,
    3
  ],
  "c":
  {
    "d": "hello"
  }
}

Truncated Formatted Data:
{
  "a": 1,
  "b":
  ... (Max depth reached)
  ... (1 more entries)
}
```

## Performance Considerations

- **Synchronous formatting:** `DynamicLogger.log` formats and emits output on the calling thread. For typical API responses and app state, this is imperceptible.
- **Truncation:** Use `truncate: true` with `maxDepth`, `maxCollectionEntries`, and `maxStringLength` to bound both execution time and output size for large data structures.
- **Level filtering:** Set `minLevel` to drop unwanted messages before any formatting work occurs.

## Example Output

The logger produces beautifully formatted, color-coded output:

```
┌──────────┤ UserData ├──────────┐
{
  "name": "Alice",
  "age": 30,
  "isActive": true,
  "tags":
  [
    "admin",
    "dev"
  ]
}
└────────────────────────────────┘
```

**Note:** Colors are displayed in terminals supporting ANSI codes. The actual colors are:
- **INFO:** Cyan/Blue
- **WARNING:** Yellow
- **ERROR:** Red

For a visual example, see [output.png](output.png) in the repository.

## API Reference

### `DynamicLogger.log()`

Logs a message or data structure with formatting.

**Parameters:**
- `msg` (dynamic): The message or data to log
- `tag` (String?): Optional tag for categorization
- `level` (LogLevel): Severity level (INFO, WARNING, ERROR)
- `stackTrace` (StackTrace?): Optional stack trace
- `logHandlerOverride` (LogHandler?): Override the default handler for this call
- `truncate` (bool?): Enable/disable truncation for this call
- `maxDepth` (int?): Maximum nesting depth for this call
- `maxCollectionEntries` (int?): Maximum entries to show for this call

### `DynamicLogger.configure()`

Sets global defaults for the logger. All parameters are optional.

**Parameters:**
- `logHandler` (LogHandler?): Custom log output function
- `maxDepth` (int?): Default maximum nesting depth when truncation is active (default: 10)
- `maxCollectionEntries` (int?): Default maximum Map/List entries when truncation is active (default: 100)
- `maxStringLength` (int?): Default maximum string length when truncation is active. -1 = no limit (default: -1)
- `truncate` (bool?): Enable truncation globally (default: false)
- `enable` (bool?): Enable/disable logging globally (default: true)
- `minLevel` (LogLevel?): Minimum severity to emit. Messages below this are silently dropped (default: LogLevel.INFO)
- `colorEnabled` (bool?): Emit ANSI color codes. Set to false for plain-text sinks (default: true)

### `DynamicLogger.reset()`

Restores all configuration to factory defaults. Use in test `tearDown` to prevent state leaking between test cases.

### `DynamicLogger.formatData()`

Formats data into a plain-text string without logging.

**Parameters:**
- `data` (dynamic): The data to format
- `truncate` (bool?): Enable/disable truncation
- `maxDepth` (int?): Maximum nesting depth
- `maxCollectionEntries` (int?): Maximum entries to show
- `maxStringLength` (int?): Maximum string length

**Returns:** `String` — The formatted data (no ANSI color codes)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License
MIT License. See the [LICENSE](LICENSE) file for details.
