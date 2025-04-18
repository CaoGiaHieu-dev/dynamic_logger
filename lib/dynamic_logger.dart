library; // Library directive

import 'dart:async';
import 'dart:convert'; // Used for JsonEncoder, primarily in _formatValue
import 'dart:developer' as developer; // Default log handler
import 'package:dio/dio.dart'; // For handling RequestOptions and FormData
import 'package:logging/logging.dart' as logging; // For standard Level values

/// Enum representing the different severity levels for log messages.
enum LogLevel { INFO, WARNING, ERROR }

/// Typedef for a log handler function.
/// This defines the signature for functions that can process the final log message string.
///
/// Parameters match the standard `dart:developer.log` function signature,
/// allowing it to be used as a default or replacement.
typedef LogHandler = void Function(
  String message, {
  Object? error, // Associated error object, if any
  int level, // Severity level (maps to logging.Level.value)
  String name, // Logger name (defaults to 'LOGGER')
  int? sequenceNumber, // Sequence number for logs
  StackTrace? stackTrace, // Associated stack trace, if any
  DateTime? time, // Timestamp of the log record
  Zone? zone, // Zone where the log record was created
});

/// {@template dynamic_logger}
/// A flexible and memory-efficient logger for Dart/Flutter applications.
///
/// Provides structured, color-coded output for various data types, including
/// complex nested Maps and Lists, as well as specific support for `dio` objects.
/// Includes features for truncating large data structures to manage memory usage
/// and improve log readability.
///
/// Uses a singleton pattern accessed via the `DynamicLogger()` factory constructor
/// or static methods like `DynamicLogger.log` and `DynamicLogger.configure`.
/// {@endtemplate}
class DynamicLogger {
  /// Private constructor for the singleton pattern.
  /// Initializes the default log handler to `dart:developer.log`.
  DynamicLogger._internal() : logHandler = developer.log;

  /// The singleton instance of the [DynamicLogger].
  static final _instance = DynamicLogger._internal();

  /// Factory constructor to return the singleton instance.
  /// Use this or the static methods to interact with the logger.
  factory DynamicLogger() => _instance;

  /// The function responsible for outputting the formatted log message.
  /// Defaults to `dart:developer.log`. Can be overridden via [configure].
  LogHandler logHandler;

  // --- Configuration ---

  /// Default maximum recursion depth for formatting nested structures (Maps/Lists).
  /// Used when `truncate` is enabled and `maxDepth` is not specified in the `log` call.
  static int _defaultMaxDepth = 10;

  /// Default maximum number of entries to format within a single Map or List.
  /// Used when `truncate` is enabled and `maxCollectionEntries` is not specified in the `log` call.
  static int _defaultMaxCollectionEntries = 100;

  /// Default flag indicating whether truncation should be enabled globally.
  /// Can be overridden per log call using the `truncate` parameter in `log`.
  static bool _defaultTruncate = false;

  /// Configures the default behavior of the [DynamicLogger].
  ///
  /// Call this early in your application (e.g., in `main()`) to set global preferences.
  ///
  /// Parameters:
  /// - [logHandler]: Sets a new default log handler function (e.g., to write to a file).
  /// - [maxDepth]: Sets the default maximum recursion depth for formatting when truncation is enabled.
  /// - [maxCollectionEntries]: Sets the default maximum number of entries shown for collections when truncation is enabled.
  /// - [truncate]: Sets whether to enable truncation by default for all subsequent `log` calls (unless overridden).
  static void configure({
    LogHandler? logHandler,
    int? maxDepth,
    int? maxCollectionEntries,
    bool? truncate,
  }) {
    if (logHandler != null) _instance.logHandler = logHandler;
    if (maxDepth != null) _defaultMaxDepth = maxDepth;
    if (maxCollectionEntries != null) {
      _defaultMaxCollectionEntries = maxCollectionEntries;
    }
    if (truncate != null) _defaultTruncate = truncate;
  }

  // --- Constants for Formatting ---

  /// Length of the border line segments (`─`) on each side of the tag in the header/footer.
  static const int _borderLength = 10;

  /// The string used for one level of indentation (two spaces).
  static const String _indentSpace = '  ';

  /// ANSI escape code to reset terminal colors to default.
  static const String _colorReset = '\x1b[0m';

  /// Logs a message or data structure with enhanced formatting and optional truncation.
  ///
  /// This is the primary method for logging. It formats the input `msg` based on its type,
  /// applies color-coding based on the `level`, adds headers/footers, and handles truncation.
  ///
  /// Parameters:
  /// - [msg]: The message or data to log (e.g., String, int, Map, List, RequestOptions).
  /// - [tag]: An optional tag string displayed in the header/footer to categorize the log. Defaults to "Dynamic Log".
  /// - [stackTrace]: An optional [StackTrace] object to associate with the log record. Passed to the [logHandler].
  /// - [level]: The severity [LogLevel] of the message (INFO, WARNING, ERROR). Determines the color. Defaults to INFO.
  /// - [logHandlerOverride]: An optional [LogHandler] to use for this specific call, overriding the default/configured handler.
  /// - [truncate]: Enables or disables truncation for *this specific log call*. Overrides the global default set by [configure].
  /// - [maxDepth]: Sets the maximum recursion depth for formatting nested structures for *this specific log call*. Requires `truncate` to be `true` (either globally or for this call). Overrides the global default.
  /// - [maxCollectionEntries]: Sets the maximum number of entries shown for Maps/Lists for *this specific log call*. Requires `truncate` to be `true`. Overrides the global default.
  static void log(
    dynamic msg, {
    String? tag,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.INFO,
    LogHandler? logHandlerOverride,
    bool? truncate,
    int? maxDepth,
    int? maxCollectionEntries,
  }) {
    // Determine the handler, tag, and color for this log call
    final handler = logHandlerOverride ?? _instance.logHandler;
    final name = tag ?? "Dynamic Log";
    final colorCode = _instance._getColorCode(level);

    // Determine effective truncation settings for this call
    final bool shouldTruncate = truncate ?? _defaultTruncate;
    // Use -1 to signify "no limit" if truncation is disabled
    final int effectiveMaxDepth =
        (shouldTruncate ? (maxDepth ?? _defaultMaxDepth) : -1);
    final int effectiveMaxEntries = (shouldTruncate
        ? (maxCollectionEntries ?? _defaultMaxCollectionEntries)
        : -1);

    final buffer = StringBuffer();

    // --- Header ---
    final header = _logHeader(name);
    buffer.writeln('$colorCode$header$_colorReset');

    // --- Content ---
    // Use a separate buffer for content formatting to handle potential errors gracefully
    final contentBuffer = StringBuffer();
    try {
      // Handle top-level primitives directly for correct alignment
      if (msg == null || msg is String || msg is num || msg is bool) {
        // Format directly using _formatValue, add color, no extra indent
        contentBuffer.writeln('$colorCode${_formatValue(msg)}$_colorReset');
      } else {
        // For collections/objects, start the recursive formatting
        _formatLogMessage(
          contentBuffer,
          msg,
          colorCode: colorCode,
          level: 0, // Level 0 means content starts directly under header
          maxDepth: effectiveMaxDepth,
          maxCollectionEntries: effectiveMaxEntries,
        );
      }
    } catch (e, s) {
      // Handle errors during the formatting process itself
      contentBuffer.clear(); // Clear potentially partial content
      final errorIndent = _indentSpace * 1; // Indent error message slightly
      contentBuffer.writeln(
          '$colorCode$errorIndent Error formatting log message: $e$_colorReset');
      contentBuffer.writeln(
          '$colorCode$errorIndent Falling back to default toString():$_colorReset');
      // Use _formatValue for the fallback msg as well for consistency, indented
      contentBuffer
          .writeln('$colorCode$errorIndent${_formatValue(msg)}$_colorReset');
      // Log the internal error using the default developer log for visibility
      developer.log(
        'Error during DynamicLogger formatting',
        error: e,
        stackTrace: s,
        level: logging.Level.SEVERE.value, // Use standard logging level value
        name: 'DynamicLoggerInternal',
      );
    }

    // Add formatted content lines to the main buffer
    buffer.write(contentBuffer.toString().trimRight());
    // Ensure exactly one newline before the footer
    if (!buffer.toString().endsWith('\n')) {
      buffer.writeln();
    }

    // --- Footer ---
    final footer = _logFooter(name);
    buffer.writeln('$colorCode$footer$_colorReset');

    // --- Log Output ---
    // Pass the complete formatted string and other details to the handler
    handler(
      buffer.toString().trimRight(), // Trim final trailing newline
      name: 'LOGGER', // Consistent name for developer tools integration
      stackTrace: stackTrace,
      level: _mapLogLevel(level), // Map our LogLevel to standard int level
    );
  }

  // --- Header/Footer ---

  /// Generates the top border line for the log output.
  /// Includes the log tag centered between border segments.
  static String _logHeader(String name) {
    final border = '─' * _borderLength;
    final middle = '┤ $name ├'; // Separator with tag
    return '┌$border$middle$border┐';
  }

  /// Generates the bottom border line for the log output.
  /// Matches the length of the header.
  static String _logFooter(String name) {
    // Calculate total length based on the header's structure
    final middleLength = name.length + 4; // Length of '┤  ├' + name
    final totalLength = (_borderLength * 2) + middleLength;
    // Ensure footer length matches header, accounting for corner characters
    return '└${'─' * (totalLength - 2)}┘'; // -2 for corners '└' and '┘'
  }

  /// Recursively formats the log message based on its type, applying indentation and color.
  /// Writes the formatted output directly to the provided [buffer].
  ///
  /// This is the core recursive function called by `log` for non-primitive types
  /// and by formatting helpers (`_logJson`, `_logList`) for nested structures.
  ///
  /// Parameters:
  /// - [buffer]: The [StringBuffer] to write the formatted output to.
  /// - [data]: The current piece of data being formatted.
  /// - [colorCode]: The ANSI color code string for the current log level.
  /// - [level]: The current nesting level (0 for top-level objects/collections). Determines indentation.
  /// - [maxDepth]: The maximum allowed nesting level. If `level` exceeds this, truncation occurs. (-1 means no limit).
  /// - [maxCollectionEntries]: The maximum number of entries to show in Maps/Lists at this level. (-1 means no limit).
  static void _formatLogMessage(
    StringBuffer buffer,
    dynamic data, {
    required String colorCode,
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    // Calculate indentation string for the current level
    final currentIndent = _indentSpace * level;

    // Check for max depth truncation
    if (maxDepth != -1 && level >= maxDepth) {
      // Use >= for depth check consistency
      buffer.writeln(
          '$colorCode$currentIndent... (Max depth reached)$_colorReset');
      return;
    }

    // --- Format based on type ---
    if (data == null || data is String || data is num || data is bool) {
      // Handle primitives (only occurs for items *inside* collections here)
      buffer
          .writeln('$colorCode$currentIndent${_formatValue(data)}$_colorReset');
    } else if (data is Map) {
      // Delegate Map formatting
      _logJson(buffer, data,
          colorCode: colorCode,
          level: level, // Map braces are at the current level
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is List) {
      // Delegate List formatting
      _logList(buffer, data,
          colorCode: colorCode,
          level: level, // List brackets are at the current level
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is FormData) {
      // Delegate FormData formatting
      _logFormData(buffer, data,
          colorCode: colorCode,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is RequestOptions) {
      // Delegate RequestOptions formatting
      _formatRequestOptions(buffer, data,
          colorCode: colorCode,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else {
      // Fallback for unknown objects: use toString() and apply indent
      buffer.writeln('$colorCode$currentIndent$data$_colorReset');
    }
  }

  // --- Type-Specific Formatters ---

  /// Formats FormData (from `dio` package) with indentation and color.
  /// Separates fields and files. Applies truncation limits to both sections.
  static void _logFormData(
    StringBuffer buffer,
    FormData data, {
    required String colorCode,
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    final currentIndent = _indentSpace * level;
    final nextLevelIndent = _indentSpace * (level + 1);

    // --- Format fields ---
    buffer.writeln('$colorCode${currentIndent}Fields: {$_colorReset}');
    if (data.fields.isNotEmpty) {
      int count = 0;
      final fieldList = data.fields.toList();
      for (int i = 0; i < fieldList.length; i++) {
        final entry = fieldList[i];
        final isLast = i == fieldList.length - 1;
        // Check collection entry truncation
        if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
          buffer.writeln(
              '$colorCode$nextLevelIndent... (${fieldList.length - count} more fields)$_colorReset');
          break;
        }
        final comma = !isLast &&
                (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
            ? ','
            : '';
        // Use _formatValue for consistent value formatting (e.g., quoting strings)
        buffer.writeln(
            '$colorCode$nextLevelIndent"${entry.key}": ${_formatValue(entry.value)}$comma$_colorReset');
        count++;
      }
    }
    buffer.writeln(
        '$colorCode$currentIndent}$_colorReset'); // Closing brace for Fields

    // --- Format files ---
    buffer.writeln('$colorCode${currentIndent}Files: {$_colorReset}');
    if (data.files.isNotEmpty) {
      int count = 0;
      final fileList = data.files.toList();
      for (int i = 0; i < fileList.length; i++) {
        final entry = fileList[i];
        final isLast = i == fileList.length - 1;
        // Check collection entry truncation
        if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
          buffer.writeln(
              '$colorCode$nextLevelIndent... (${fileList.length - count} more files)$_colorReset');
          break;
        }
        final comma = !isLast &&
                (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
            ? ','
            : '';
        final fileName = entry.value.filename ?? 'unknown_file';
        // Create a descriptive string for the file and format it as a value
        final fileDesc = _formatValue(
            'File(name: "$fileName", type: ${entry.value.contentType}, size: ${entry.value.length})');
        buffer.writeln(
            '$colorCode$nextLevelIndent"${entry.key}": $fileDesc$comma$_colorReset');
        count++;
      }
    }
    buffer.writeln(
        '$colorCode$currentIndent}$_colorReset'); // Closing brace for Files
  }

  /// Formats a List with proper indentation, color, commas, and truncation.
  static void _logList(
    StringBuffer buffer,
    List data, {
    required String colorCode,
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1; // Indentation level for list items

    if (data.isEmpty) {
      buffer.writeln(
          '$colorCode$currentIndent[]$_colorReset'); // Empty list on one line
      return;
    }

    buffer.writeln(
        '$colorCode$currentIndent [$_colorReset'); // Opening bracket at current level
    int count = 0;
    for (int i = 0; i < data.length; i++) {
      final isLast = i == data.length - 1;
      // Check collection entry truncation
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$colorCode${_indentSpace * nextLevel}... (${data.length - count} more items)$_colorReset');
        break;
      }
      final item = data[i];
      // Determine if a comma is needed after this item
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      // Format the item recursively into a temporary buffer
      // This allows us to easily add the comma after the item's last line
      final itemBuffer = StringBuffer();
      _formatLogMessage(itemBuffer, item,
          colorCode: colorCode,
          level: nextLevel, // Items are indented one level deeper
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);

      // Write the formatted item lines from the temporary buffer to the main buffer
      final itemLines = itemBuffer.toString().trimRight().split('\n');
      for (int j = 0; j < itemLines.length; j++) {
        final line = itemLines[j];
        if (j == itemLines.length - 1) {
          // Is this the last line of the formatted item?
          buffer.writeln(
              '$line$colorCode$comma$_colorReset'); // Add comma and reset color
        } else {
          buffer.writeln(
              line); // Write intermediate lines as they are (already colored/indented)
        }
      }
      count++;
    }
    buffer.writeln(
        '$colorCode$currentIndent]$_colorReset'); // Closing bracket at current level
  }

  /// Formats a Map with proper indentation, color, commas, key quoting, and truncation.
  static void _logJson(
    StringBuffer buffer,
    Map data, {
    required String colorCode,
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1; // Indentation level for key-value pairs
    final nextLevelIndent = _indentSpace * nextLevel;

    if (data.isEmpty) {
      buffer.writeln(
          '$colorCode$currentIndent{}$_colorReset'); // Empty map on one line
      return;
    }

    buffer.writeln(
        '$colorCode$currentIndent{$_colorReset'); // Opening brace at current level
    int count = 0;
    final entries =
        data.entries.toList(); // Convert to list for index-based iteration

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      // Check collection entry truncation
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$colorCode$nextLevelIndent... (${entries.length - count} more entries)$_colorReset');
        break;
      }

      final key = entry.key;
      final value = entry.value;
      // Determine if a comma is needed after this key-value pair
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      // Format the key part (always indented at the next level)
      final keyString = '$colorCode$nextLevelIndent"$key": ';

      // --- Value Formatting Logic ---
      if (value == null || value is String || value is num || value is bool) {
        // Simple primitive type: Format value and print "key": value, on one line
        final formattedValue = _formatValue(value);
        buffer.writeln('$keyString$colorCode$formattedValue$comma$_colorReset');
      } else if ((value is Map && value.isEmpty) ||
          (value is List && value.isEmpty)) {
        // Empty collection: Print "key": {} or "key": [], on one line
        final emptyCollectionString = (value is Map) ? '{}' : '[]';
        buffer.writeln(
            '$keyString$colorCode$emptyCollectionString$comma$_colorReset');
      } else {
        // Non-empty complex type (Map, List, other): Print "key": on its line,
        // then format the value recursively starting on the next line.
        buffer
            .writeln('${keyString.trimRight()}$_colorReset'); // Print key: line

        // Format the complex value recursively into a temporary buffer
        final valueBuffer = StringBuffer();
        _formatLogMessage(valueBuffer, value,
            colorCode: colorCode,
            level: nextLevel, // Value structure starts at the next level
            maxDepth: maxDepth,
            maxCollectionEntries: maxCollectionEntries);

        // Write the formatted value lines, adding the comma to the last line
        final valueLines = valueBuffer.toString().trimRight().split('\n');
        for (int j = 0; j < valueLines.length; j++) {
          final line = valueLines[j];
          if (j == valueLines.length - 1) {
            // Is this the last line of the formatted value?
            buffer.writeln(
                '$line$colorCode$comma$_colorReset'); // Add comma and reset color
          } else {
            buffer.writeln(line); // Write intermediate lines as they are
          }
        }
      }
      count++;
    }
    buffer.writeln(
        '$colorCode$currentIndent}$_colorReset'); // Closing brace at current level
  }

  /// Formats a simple value (String, num, bool, null) according to JSON standards.
  /// - Strings are enclosed in double quotes with proper escaping.
  /// - Numbers and booleans are represented as literals.
  /// - Null is represented as the literal `null`.
  /// - Other object types attempt `jsonEncode` (useful if they have `toJson`) or fall back
  ///   to quoting their `toString()` representation.
  static String _formatValue(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is String) {
      return jsonEncode(value); // Handles quotes and escapes
    } else if (value is num || value is bool) {
      return value.toString(); // JSON numbers and booleans are not quoted
    } else {
      // Fallback for other types
      try {
        // If object has toJson(), jsonEncode might work and produce valid JSON
        return jsonEncode(value);
      } catch (_) {
        // Otherwise, treat its string representation as a string value
        return jsonEncode(value.toString());
      }
    }
  }

  /// Formats RequestOptions (from `dio` package) with indentation and color.
  /// Displays key information like method, URI, headers, query params, data, and common options.
  static void _formatRequestOptions(
    StringBuffer buffer,
    RequestOptions options, {
    required String colorCode,
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1;
    final nextLevelIndent = _indentSpace * nextLevel;

    // Request Line (Method and URI)
    buffer.writeln(
        '$colorCode${currentIndent}Request: ${options.method} ${options.uri}$_colorReset');

    // --- Helper to format sections (Headers, Query, Data) ---
    void formatSection(String title, dynamic data) {
      if (data == null) return; // Skip null sections
      // Skip empty collections/strings to avoid empty sections
      bool isEmptyCollection =
          (data is Map && data.isEmpty) || (data is List && data.isEmpty);
      bool isEmptyString = data is String && data.isEmpty;
      bool isEmptyFormData =
          data is FormData && data.fields.isEmpty && data.files.isEmpty;
      if (isEmptyCollection || isEmptyString || isEmptyFormData) return;

      // Print section title at the current level
      buffer.writeln('$colorCode$currentIndent$title:$_colorReset');
      // Format section content recursively, indented at the next level
      _formatLogMessage(buffer, data,
          colorCode: colorCode,
          level: nextLevel, // Section content starts one level deeper
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    }

    // --- Format Request Parts ---
    formatSection('Headers', options.headers);
    formatSection('Query Parameters', options.queryParameters);
    formatSection('Data', options.data); // Handles Map, List, FormData, etc.

    // --- Format Common Options ---
    buffer.writeln('$colorCode$currentIndent--- Options ---$_colorReset');
    void formatOption(String key, dynamic value) {
      // Print each option key-value pair at the next level
      buffer.writeln(
          '$colorCode$nextLevelIndent$key: ${_formatValue(value)}$_colorReset');
    }

    formatOption('Content-Type', options.contentType);
    formatOption('Response Type', options.responseType.toString());
    formatOption('Follow Redirects', options.followRedirects);
    formatOption(
        'Connect Timeout (ms)', options.connectTimeout?.inMilliseconds);
    formatOption(
        'Receive Timeout (ms)', options.receiveTimeout?.inMilliseconds);
    formatOption('Send Timeout (ms)', options.sendTimeout?.inMilliseconds);
    // Add more options here if needed (e.g., extra headers, validateStatus)
  }

  // --- Color and Level Mapping ---

  /// Returns the ANSI color code string corresponding to the given [LogLevel].
  String _getColorCode(LogLevel level) {
    switch (level) {
      case LogLevel.INFO:
        return '\x1B[38;5;45m'; // Blueish (ANSI 256 color)
      case LogLevel.WARNING:
        return '\x1B[33m'; // Yellow (Standard ANSI)
      case LogLevel.ERROR:
        return '\x1B[38;5;196m'; // Reddish (ANSI 256 color)
    }
  }

  /// Maps the custom [LogLevel] enum to the integer values used by `dart:developer`
  /// and the standard `package:logging`.
  static int _mapLogLevel(LogLevel level) {
    switch (level) {
      // Mapping INFO to CONFIG for better visibility in some tools,
      // as INFO level might be filtered out by default.
      case LogLevel.INFO:
        return logging.Level.CONFIG.value;
      case LogLevel.WARNING:
        return logging.Level.WARNING.value;
      case LogLevel.ERROR:
        return logging.Level.SEVERE.value; // Map ERROR to SEVERE
    }
  }

  /// Public utility to format data into a string using the logger's formatting logic,
  /// but without actually logging it.
  ///
  /// Useful for displaying formatted data in UI debug panels or other contexts.
  /// Respects truncation rules (defaults or overrides). Output is plain text (no color).
  ///
  /// Parameters mirror the truncation parameters of the `log` method.
  static String formatData(dynamic data,
      {bool? truncate, int? maxDepth, int? maxCollectionEntries}) {
    final buffer = StringBuffer();
    // Determine effective truncation settings
    final bool shouldTruncate = truncate ?? _defaultTruncate;
    final int effectiveMaxDepth =
        (shouldTruncate ? (maxDepth ?? _defaultMaxDepth) : -1);
    final int effectiveMaxEntries = (shouldTruncate
        ? (maxCollectionEntries ?? _defaultMaxCollectionEntries)
        : -1);

    // Use the dedicated plain text formatting helper
    _formatPlainTextMessage(
      buffer,
      data,
      level: 0, // Start formatting at level 0
      maxDepth: effectiveMaxDepth,
      maxCollectionEntries: effectiveMaxEntries,
    );

    return buffer.toString().trimRight(); // Return the formatted string
  }

  /// Recursive helper function for [formatData].
  /// Generates plain text output (no color) with space indentation,
  /// applying truncation rules. Mirrors the logic of `_formatLogMessage`.
  static void _formatPlainTextMessage(
    StringBuffer buffer,
    dynamic data, {
    required int level,
    required int maxDepth,
    required int maxCollectionEntries,
  }) {
    final currentIndent = _indentSpace * level;

    // Check for max depth truncation
    if (maxDepth != -1 && level >= maxDepth) {
      buffer.writeln('$currentIndent... (Max depth reached)');
      return;
    }

    // --- Format based on type (Plain Text) ---
    if (data == null || data is String || data is num || data is bool) {
      // Use _formatValue for consistent JSON-like formatting of primitives
      buffer.writeln('$currentIndent${_formatValue(data)}');
    } else if (data is Map) {
      _logPlainTextJson(buffer, data,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is List) {
      _logPlainTextList(buffer, data,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is FormData) {
      _logPlainTextFormData(buffer, data,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else if (data is RequestOptions) {
      _formatPlainTextRequestOptions(buffer, data,
          level: level,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    } else {
      // Fallback for unknown objects
      buffer.writeln('$currentIndent$data');
    }
  }

  // --- Plain Text Formatters (for formatData) ---

  /// Plain text formatter for Maps. Mirrors `_logJson` but without color codes.
  static void _logPlainTextJson(StringBuffer buffer, Map data,
      {required int level,
      required int maxDepth,
      required int maxCollectionEntries}) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1;
    final nextLevelIndent = _indentSpace * nextLevel;

    if (data.isEmpty) {
      buffer.writeln('$currentIndent{}');
      return;
    }

    buffer.writeln('$currentIndent{'); // Opening brace
    int count = 0;
    final entries = data.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;
      // Check collection entry truncation
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$nextLevelIndent... (${entries.length - count} more entries)');
        break;
      }
      final key = entry.key;
      final value = entry.value;
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      final keyString = '$nextLevelIndent"$key": '; // Key part with indent

      // --- Value Formatting Logic (Plain Text) ---
      if (value == null || value is String || value is num || value is bool) {
        // Simple type
        final formattedValue = _formatValue(value);
        buffer.writeln('$keyString$formattedValue$comma');
      } else if ((value is Map && value.isEmpty) ||
          (value is List && value.isEmpty)) {
        // Empty collection
        final emptyCollectionString = (value is Map) ? '{}' : '[]';
        buffer.writeln('$keyString$emptyCollectionString$comma');
      } else {
        // Non-empty complex type
        buffer.writeln(keyString.trimRight()); // Print key: line

        // Format value recursively into temporary buffer
        final valueBuffer = StringBuffer();
        _formatPlainTextMessage(valueBuffer, value,
            level: nextLevel,
            maxDepth: maxDepth,
            maxCollectionEntries: maxCollectionEntries);

        // Write formatted value lines, adding comma to the last line
        final valueLines = valueBuffer.toString().trimRight().split('\n');
        for (int j = 0; j < valueLines.length; j++) {
          final line = valueLines[j];
          if (j == valueLines.length - 1) {
            // Last line of value
            buffer.writeln('$line$comma');
          } else {
            buffer.writeln(line);
          }
        }
      }
      count++;
    }
    buffer.writeln('$currentIndent}'); // Closing brace
  }

  /// Plain text formatter for Lists. Mirrors `_logList` but without color codes.
  static void _logPlainTextList(StringBuffer buffer, List data,
      {required int level,
      required int maxDepth,
      required int maxCollectionEntries}) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1;
    final nextLevelIndent = _indentSpace * nextLevel;

    if (data.isEmpty) {
      buffer.writeln('$currentIndent[]');
      return;
    }

    buffer.writeln('$currentIndent['); // Opening bracket
    int count = 0;
    for (int i = 0; i < data.length; i++) {
      final isLast = i == data.length - 1;
      // Check collection entry truncation
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer
            .writeln('$nextLevelIndent... (${data.length - count} more items)');
        break;
      }
      final item = data[i];
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      // Format item recursively into temporary buffer
      final itemBuffer = StringBuffer();
      _formatPlainTextMessage(itemBuffer, item,
          level: nextLevel,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);

      // Write formatted item lines, adding comma to the last line
      final itemLines = itemBuffer.toString().trimRight().split('\n');
      for (int j = 0; j < itemLines.length; j++) {
        final line = itemLines[j];
        if (j == itemLines.length - 1) {
          // Last line of item
          buffer.writeln('$line$comma');
        } else {
          buffer.writeln(line);
        }
      }
      count++;
    }
    buffer.writeln('$currentIndent]'); // Closing bracket
  }

  /// Plain text formatter for FormData. Mirrors `_logFormData` but without color codes.
  static void _logPlainTextFormData(StringBuffer buffer, FormData data,
      {required int level,
      required int maxDepth,
      required int maxCollectionEntries}) {
    final currentIndent = _indentSpace * level;
    final nextLevelIndent = _indentSpace * (level + 1);

    // Fields section
    buffer.writeln('${currentIndent}Fields: {');
    if (data.fields.isNotEmpty) {
      int count = 0;
      final fieldList = data.fields.toList();
      for (int i = 0; i < fieldList.length; i++) {
        final entry = fieldList[i];
        final isLast = i == fieldList.length - 1;
        if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
          buffer.writeln(
              '$nextLevelIndent... (${fieldList.length - count} more fields)');
          break;
        }
        final comma = !isLast &&
                (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
            ? ','
            : '';
        buffer.writeln(
            '$nextLevelIndent"${entry.key}": ${_formatValue(entry.value)}$comma');
        count++;
      }
    }
    buffer.writeln('$currentIndent}');

    // Files section
    buffer.writeln('${currentIndent}Files: {');
    if (data.files.isNotEmpty) {
      int count = 0;
      final fileList = data.files.toList();
      for (int i = 0; i < fileList.length; i++) {
        final entry = fileList[i];
        final isLast = i == fileList.length - 1;
        if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
          buffer.writeln(
              '$nextLevelIndent... (${fileList.length - count} more files)');
          break;
        }
        final comma = !isLast &&
                (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
            ? ','
            : '';
        final fileName = entry.value.filename ?? 'unknown_file';
        final fileDesc = _formatValue(
            'File(name: "$fileName", type: ${entry.value.contentType}, size: ${entry.value.length})');
        buffer.writeln('$nextLevelIndent"${entry.key}": $fileDesc$comma');
        count++;
      }
    }
    buffer.writeln('$currentIndent}');
  }

  /// Plain text formatter for RequestOptions. Mirrors `_formatRequestOptions` but without color codes.
  static void _formatPlainTextRequestOptions(
      StringBuffer buffer, RequestOptions options,
      {required int level,
      required int maxDepth,
      required int maxCollectionEntries}) {
    final currentIndent = _indentSpace * level;
    final nextLevel = level + 1;
    final nextLevelIndent = _indentSpace * nextLevel;

    // Request line
    buffer.writeln('${currentIndent}Request: ${options.method} ${options.uri}');

    // Helper for sections
    void formatSection(String title, dynamic data) {
      if (data == null) return;
      bool isEmptyCollection =
          (data is Map && data.isEmpty) || (data is List && data.isEmpty);
      bool isEmptyString = data is String && data.isEmpty;
      bool isEmptyFormData =
          data is FormData && data.fields.isEmpty && data.files.isEmpty;
      if (isEmptyCollection || isEmptyString || isEmptyFormData) return;

      buffer.writeln('$currentIndent$title:'); // Section title
      // Format section content recursively
      _formatPlainTextMessage(buffer, data,
          level: nextLevel,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries);
    }

    // Format sections
    formatSection('Headers', options.headers);
    formatSection('Query Parameters', options.queryParameters);
    formatSection('Data', options.data);

    // Format options
    buffer.writeln('$currentIndent--- Options ---');
    void formatOption(String key, dynamic value) {
      buffer.writeln('$nextLevelIndent$key: ${_formatValue(value)}');
    }

    formatOption('Content-Type', options.contentType);
    formatOption('Response Type', options.responseType.toString());
    formatOption('Follow Redirects', options.followRedirects);
    formatOption(
        'Connect Timeout (ms)', options.connectTimeout?.inMilliseconds);
    formatOption(
        'Receive Timeout (ms)', options.receiveTimeout?.inMilliseconds);
    formatOption('Send Timeout (ms)', options.sendTimeout?.inMilliseconds);
  }
} // End of DynamicLogger class
