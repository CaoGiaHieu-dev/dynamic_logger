# DynamicLogger

A simple and structured logger for Dart applications.

## Features

- Log messages with different log levels (INFO, WARNING, ERROR)
- Log complex data structures like Maps, Lists, and FormData
- Color-coded logs based on the log level

## Usage
```dart
import 'package:dynamic_logger/dynamic_logger.dart';

void main() {
    // Log a simple message
    DynamicLogger.log('This is an info message');

    // Log a message with a specific log level
    DynamicLogger.log('This is a warning message', level: LogLevel.WARNING);

    // Log a message with a tag
    DynamicLogger.log('This is an error message', tag: 'MyTag', level: LogLevel.ERROR);

    // Log a complex data structure like a Map
    DynamicLogger.log({'key': 'value', 'anotherKey': 'anotherValue'});

    // Log a Dio RequestOptions object (example)
    // final requestOptions = RequestOptions(path: 'https://example.com');
    // DynamicLogger.log(requestOptions);
}
```

## Installation

Add `dynamic_logger` as a dependency in your `pubspec.yaml` file.
```yaml
dependencies:
    dynamic_logger: ^0.1.0
```

## License

MIT License. See the [LICENSE](LICENSE) file for details.