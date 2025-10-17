# DynamicLogger

[![pub version](https://img.shields.io/pub/v/dynamic_logger.svg)](https://pub.dev/packages/dynamic_logger) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A flexible and memory-efficient logger for Dart/Flutter applications, providing structured, color-coded output with support for complex data types and truncation.

## Features

-   **Structured Output:** Pretty-prints Maps and Lists in a JSON-like format for easy readability.
-   **Color-Coded Levels:** Differentiates between INFO, WARNING, and ERROR logs using distinct colors (in terminals supporting ANSI codes).
-   **Handles Complex Data:** Logs primitives (String, num, bool, null), Maps, Lists, and any object with proper `toString()` or `toJson()` methods.
-   **Memory Efficient & Non-Blocking:** Designed to reduce intermediate string creation and now uses [Dart Isolates](https://dart.dev/language/concurrency) to perform heavy formatting work in the background, preventing UI jank when logging large data structures.
-   **Truncation:** Automatically truncates deep or large collections (Maps/Lists) to prevent excessive memory usage and overly long logs.
    -   Configurable maximum depth and maximum collection entries.
    -   Can be enabled/disabled globally or per log call.
-   **Configuration:** Set global defaults for truncation behavior, depth/entry limits, and the underlying log handler (`dart:developer` by default).
-   **Clean Formatting:** Uses clear single-line headers/footers to delineate log blocks.
-   **Static Utility:** Includes `DynamicLogger.formatData` to format data structures into strings without logging.
-   **Easy Access:** Simple static methods (`DynamicLogger.log`, `DynamicLogger.configure`) for convenient use.

## Installation

Add `dynamic_logger` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  dynamic_logger: ^0.2.2
```
Then run `dart pub get` or `flutter pub get`.

**Note:** This package has no external dependencies and works with Dart SDK >=3.0.0 <4.0.0.

## Basic Usage

Import the package and use the static log method. `DynamicLogger.log` is a **fire-and-forget** method, meaning it returns immediately and performs formatting in a background isolate. **No `await` is needed.**

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

You can set global defaults for the logger's behavior. This is useful for setting up truncation project-wide.

```dart
import 'package:dynamic_logger/dynamic_logger.dart';

void setupLogger({bool isProduction = false}) {
  DynamicLogger.configure(
    // Enable truncation by default for all logs
    truncate: true,
    // Set default max depth for nested structures
    maxDepth: 5,
    // Set default max entries shown for Maps/Lists
    maxCollectionEntries: 20,
    // Globally enable or disable logging (defaults to true)
    enable: !isProduction, // Disable logs in production builds
    // Optionally override the default log handler (e.g., for custom output)
    logHandler: (message, {error, level = 0, name = '', stackTrace, time, zone, sequenceNumber}) {
      print(message); // Print to console instead of dart:developer
    },
  );
}

void main() {
  const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
  setupLogger(isProduction: kReleaseMode);

  // Subsequent logs will use the configured defaults unless overridden
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

- **Isolates:** Formatting runs in a background isolate, preventing UI blocking
- **Fire-and-forget:** Logs are non-blocking; the method returns immediately
- **Memory efficient:** Truncation prevents excessive memory usage with large data
- **Async timing:** Since formatting happens asynchronously, logs may appear out of order if called in rapid succession

If you need to ensure logs complete before program exit, add a small delay:
```dart
void main() async {
  DynamicLogger.log('Important message');
  await Future.delayed(Duration(milliseconds: 100)); // Wait for isolate
}
```

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

Sets global defaults for the logger.

**Parameters:**
- `logHandler` (LogHandler?): Custom log handler function
- `maxDepth` (int?): Default maximum nesting depth (default: 10)
- `maxCollectionEntries` (int?): Default maximum entries (default: 100)
- `truncate` (bool?): Enable truncation by default (default: false)
- `enable` (bool?): Enable/disable logging globally (default: true)

### `DynamicLogger.formatData()`

Formats data into a string without logging.

**Parameters:**
- `data` (dynamic): The data to format
- `truncate` (bool?): Enable/disable truncation
- `maxDepth` (int?): Maximum nesting depth
- `maxCollectionEntries` (int?): Maximum entries to show

**Returns:** `String` - The formatted data

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License
MIT License. See the [LICENSE](LICENSE) file for details.
