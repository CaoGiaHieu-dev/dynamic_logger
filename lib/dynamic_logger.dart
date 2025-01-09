library;

import 'dart:async';
import 'dart:developer' as developer;
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Enum representing different log levels.
enum LogLevel { INFO, WARNING, ERROR }

/// Typedef for a log handler function.
typedef LogHandler = void Function(
  String message, {
  Object? error,
  int level,
  String name,
  int? sequenceNumber,
  StackTrace? stackTrace,
  DateTime? time,
  Zone? zone,
});

/// DynamicLogger is a singleton class used for logging messages in a structured and formatted manner.
/// It supports logging of various data types including Maps, Lists, and FormData.
/// The logs are color-coded based on the log level (INFO, WARNING, ERROR).
///
/// How to use:
/// 1. To log a simple message:
///    DynamicLogger.log('This is an info message');
///
/// 2. To log a message with a specific log level:
///    DynamicLogger.log('This is a warning message', level: LogLevel.WARNING);
///
/// 3. To log a message with a tag:
///    DynamicLogger.log('This is an error message', tag: 'MyTag', level: LogLevel.ERROR);
///
/// 4. To log a complex data structure like a Map:
///    DynamicLogger.log({'key': 'value', 'anotherKey': 'anotherValue'});
///
/// 5. To log a Dio RequestOptions object:
///    DynamicLogger.log(requestOptions);
///
/// The class provides methods to format and log different types of data:
/// - logFormData: Formats FormData for logging.
/// - logList: Formats a list for logging.
/// - logJson: Formats a JSON object for logging.
/// - formatData: Formats data for logging, handling different data types appropriately.
class DynamicLogger {
  /// Private constructor for singleton pattern.
  DynamicLogger.setup({this.logHandler = developer.log});

  /// Singleton instance of DynamicLogger.
  static final _instance = DynamicLogger.setup();

  /// Factory constructor to return the singleton instance.
  factory DynamicLogger() => _instance;

  /// Log handler function to handle log messages.
  final LogHandler logHandler;

  /// Constants for formatting the log output.
  static const int length = 22;
  static const int lengthEachSide = 10;
  static const String spaceTab = '  ';

  /// Logs a message with the specified log level and optional tag and stack trace.
  ///
  /// Parameters:
  /// - [msg]: The message to log.
  /// - [tag]: An optional tag to categorize the log.
  /// - [stackTrace]: An optional stack trace to include in the log.
  /// - [level]: The log level (INFO, WARNING, ERROR).
  /// - [logHandler]: An optional log handler to override the default handler.
  static void log(
    dynamic msg, {
    String? tag,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.INFO,
    LogHandler? logHandler,
  }) {
    final buffer = StringBuffer();
    final name = tag ?? "Dynamic Log";

    // Add header, formatted message, and footer to the log buffer
    buffer.writeln(_logHeader(name));
    buffer.writeln(_formatLogMessage(msg).trim());
    buffer.writeln(_logFooter(name));

    // Apply color to the log based on the log level
    final result = buffer
        .toString()
        .split('\n')
        .map((e) => _instance._applyColor(level, e))
        .join('\n');

    // Log the message using the logHandler
    ((logHandler ?? _instance.logHandler))(
      result,
      name: 'LOGGER',
      stackTrace: stackTrace,
      level: _mapLogLevel(level),
    );
  }

  /// Generates the header for the log message.
  ///
  /// Parameters:
  /// - [name]: The name to include in the header.
  static String _logHeader(String name) {
    return '${'═' * lengthEachSide}═╡ $name ╞═${'═' * lengthEachSide}';
  }

  /// Generates the footer for the log message.
  ///
  /// Parameters:
  /// - [name]: The name to include in the footer.
  static String _logFooter(String name) {
    return '═══${'═' * (lengthEachSide * 2 + name.length)}═══';
  }

  /// Formats the log message based on its type.
  ///
  /// Parameters:
  /// - [data]: The data to format.
  static String _formatLogMessage(dynamic data) {
    if (data is Map) {
      return data.isNotEmpty ? logJson(data) : '';
    } else if (data is List) {
      return data.isNotEmpty ? logList(data) : '';
    } else if (data is FormData) {
      return logFormData(data);
    } else if (data is RequestOptions) {
      return _formatRequestOptions(data);
    } else {
      return '$spaceTab$data';
    }
  }

  /// Formats FormData for logging.
  ///
  /// Parameters:
  /// - [data]: The FormData to format.
  /// - [level]: The indentation level for formatting.
  static String logFormData(FormData data, {int level = 1}) {
    final buffer = StringBuffer();

    // Format fields in FormData
    if (data.fields.isNotEmpty) {
      buffer.writeln('${spaceTab * (level - 1)}Fields');
      buffer.writeln('${spaceTab * (level - 1)}{');
      for (var item in data.fields) {
        final comma = item.key != data.fields.last.key ? ',' : '';
        buffer.writeln(
          '${spaceTab * level}"${item.key}" : "${item.value}"$comma',
        );
      }
      buffer.writeln('${spaceTab * (level - 1)}}');
    }

    // Format files in FormData
    if (data.files.isNotEmpty) {
      buffer.writeln('${spaceTab * (level - 1)}Files');
      var filesAsMap = groupBy(data.files, (obj) => obj.key);
      buffer.writeln(logJson(filesAsMap));
    }

    return buffer.toString();
  }

  /// Formats a list for logging.
  ///
  /// Parameters:
  /// - [data]: The list to format.
  /// - [level]: The indentation level for formatting.
  static String logList(List data, {int level = 1}) {
    final buffer = StringBuffer();

    if (data.isEmpty) {
      return '$spaceTab${spaceTab * (level - 1)}[]';
    }

    if (data is List<int>) {
      return '$spaceTab${spaceTab * (level - 1)}$data';
    }

    buffer.writeln('$spaceTab${spaceTab * (level - 1)}[');
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final comma = i < data.length - 1 ? ',' : '';

      if (item is Map) {
        buffer.writeln(
          logJson(item, level: level + 1, extraComma: i < data.length - 1),
        );
      } else if (item is List) {
        buffer.writeln('${logList(item, level: level + 1)}$comma');
      } else if (item is String) {
        buffer.writeln(_formatString(item, level, comma));
      } else {
        buffer.writeln('$spaceTab${spaceTab * level}$item$comma');
      }
    }
    buffer.write('$spaceTab${spaceTab * (level - 1)}]');

    return buffer.toString();
  }

  /// Formats a string for logging, handling multi-line strings appropriately.
  ///
  /// Parameters:
  /// - [item]: The string to format.
  /// - [level]: The indentation level for formatting.
  /// - [comma]: The comma to append at the end of the string.
  static String _formatString(String item, int level, String comma) {
    final buffer = StringBuffer();
    if (item.contains('\n')) {
      final valueList = item.split('\n');
      for (var i = 0; i < valueList.length; i++) {
        if (i == 0) {
          buffer.writeln('$spaceTab${spaceTab * level}"${valueList[i]}');
        } else if (i == valueList.length - 1) {
          buffer.writeln('$spaceTab${valueList[i]}"$comma');
        } else {
          buffer.writeln('$spaceTab${valueList[i]}');
        }
      }
    } else {
      buffer.writeln('$spaceTab${spaceTab * level}"$item"$comma');
    }
    return buffer.toString();
  }

  /// Formats a JSON object for logging.
  ///
  /// Parameters:
  /// - [data]: The JSON object to format.
  /// - [level]: The indentation level for formatting.
  /// - [extraComma]: Whether to append an extra comma at the end.
  static String logJson(Map data, {int level = 1, bool extraComma = false}) {
    final buffer = StringBuffer();

    if (data.isEmpty) {
      return '$spaceTab${spaceTab * (level - 1)}{}';
    }

    buffer.writeln('$spaceTab${spaceTab * (level - 1)}{');
    for (var item in data.entries) {
      final value = item.value;
      final comma = item.key != data.entries.last.key ? ',' : '';

      if (value is Map) {
        buffer.writeln('$spaceTab${spaceTab * level}"${item.key}":');
        buffer.writeln(
          logJson(
            value,
            level: level + 1,
            extraComma: item.key != data.entries.last.key,
          ),
        );
      } else if (value is List) {
        buffer.writeln('$spaceTab${spaceTab * level}"${item.key}" : ');
        buffer.writeln('${logList(value, level: level + 1)}$comma');
      } else if (value is MultipartFile) {
        buffer.writeln(
          '$spaceTab${spaceTab * level}"${item.key}" : "${value.filename}"',
        );
      } else if (value != null) {
        buffer.writeln(
          '$spaceTab${spaceTab * level}"${item.key}" : ${_formatValue(value)}$comma',
        );
      } else {
        buffer.writeln(
          '$spaceTab${spaceTab * level}"${item.key}" : $value$comma',
        );
      }
    }
    buffer.write('$spaceTab${spaceTab * (level - 1)}}${extraComma ? ',' : ''}');

    return buffer.toString();
  }

  /// Formats a value for logging, adding quotes around strings.
  ///
  /// Parameters:
  /// - [value]: The value to format.
  static String _formatValue(dynamic value) {
    if (value is String) {
      return '"$value"';
    }
    return value.toString();
  }

  /// Formats RequestOptions for logging.
  ///
  /// Parameters:
  /// - [options]: The RequestOptions to format.
  static String _formatRequestOptions(RequestOptions options) {
    final buffer = StringBuffer();
    buffer.writeln('Request: ${options.method} ${options.uri}');
    buffer.writeln('Headers: ${options.headers}');
    if (options.data != null) {
      buffer.writeln('Data: ${_formatLogMessage(options.data)}');
    }
    return buffer.toString();
  }

  /// Applies color to the log message based on the log level.
  ///
  /// Parameters:
  /// - [level]: The log level.
  /// - [text]: The text to color.
  String _applyColor(LogLevel level, String text) {
    return '\x1B[${_color(level)}$text\x1b[0m';
  }

  /// Returns the color code for the specified log level.
  ///
  /// Parameters:
  /// - [level]: The log level.
  String _color(LogLevel level) {
    String result;
    switch (level) {
      case LogLevel.INFO:
        result = '38;5;45m';
        break;
      case LogLevel.WARNING:
        result = '33m';
        break;
      case LogLevel.ERROR:
        result = '38;5;202m';
        break;
    }
    return result;
  }

  /// Maps the log level to the corresponding logging level value.
  ///
  /// Parameters:
  /// - [level]: The log level.
  static int _mapLogLevel(LogLevel level) {
    int result;
    switch (level) {
      case LogLevel.INFO:
        result = Level.CONFIG.value;
        break;
      case LogLevel.WARNING:
        result = Level.WARNING.value;
        break;
      case LogLevel.ERROR:
        result = Level.SEVERE.value;
        break;
    }
    return result;
  }

  /// Formats data for logging, handling different data types appropriately.
  ///
  /// Parameters:
  /// - [data]: The data to format.
  static String formatData(dynamic data) {
    if (data is Map) {
      return logJson(data);
    } else if (data is List) {
      return logList(data);
    } else if (data is FormData) {
      return logFormData(data);
    } else {
      return data.toString();
    }
  }
}
