library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

/// Severity levels for log messages.
enum LogLevel { INFO, WARNING, ERROR }

/// Signature for log output functions, matching `dart:developer.log`.
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

/// {@template dynamic_logger}
/// A flexible logger for Dart/Flutter applications with structured,
/// color-coded output for complex nested data types.
///
/// Formatting runs synchronously on the calling thread. For very large data
/// structures, enable [truncate] to limit depth and collection size.
///
/// Configure once via [configure], then call [log] anywhere. Use [reset] in
/// tests to restore defaults between test cases.
/// {@endtemplate}
class DynamicLogger {
  DynamicLogger._internal() : logHandler = developer.log;

  static final _instance = DynamicLogger._internal();

  factory DynamicLogger() => _instance;

  /// The active output function. Override via [configure].
  LogHandler logHandler;

  // --- Static configuration state ---

  static int _defaultMaxDepth = 10;
  static int _defaultMaxCollectionEntries = 100;
  static int _defaultMaxStringLength = -1;
  static bool _defaultTruncate = false;
  static bool _enabled = true;
  static LogLevel _minLevel = LogLevel.INFO;
  static bool _colorEnabled = true;

  /// Configures the default behavior of [DynamicLogger].
  ///
  /// Call once early in your application (e.g., in `main()`) to set global
  /// preferences. All parameters are optional; omitting one leaves the current
  /// value unchanged.
  ///
  /// - [logHandler]: Custom log output function. Defaults to `dart:developer.log`.
  /// - [maxDepth]: Maximum recursion depth for nested structures when truncation
  ///   is active. Default: 10.
  /// - [maxCollectionEntries]: Maximum entries shown per Map/List when truncation
  ///   is active. Default: 100.
  /// - [maxStringLength]: Maximum string length before truncating. -1 means no
  ///   limit. Default: -1.
  /// - [truncate]: Enable truncation globally for all [log] calls. Default: false.
  /// - [enable]: Enable or disable the logger globally. Default: true.
  /// - [minLevel]: Minimum [LogLevel] to output. Messages below this level are
  ///   silently dropped. Default: [LogLevel.INFO].
  /// - [colorEnabled]: Emit ANSI color codes in output. Disable for environments
  ///   that do not support ANSI (e.g. plain file output). Default: true.
  static void configure({
    LogHandler? logHandler,
    int? maxDepth,
    int? maxCollectionEntries,
    int? maxStringLength,
    bool? truncate,
    bool? enable,
    LogLevel? minLevel,
    bool? colorEnabled,
  }) {
    if (logHandler != null) _instance.logHandler = logHandler;
    if (maxDepth != null) _defaultMaxDepth = maxDepth;
    if (maxCollectionEntries != null) {
      _defaultMaxCollectionEntries = maxCollectionEntries;
    }
    if (maxStringLength != null) _defaultMaxStringLength = maxStringLength;
    if (truncate != null) _defaultTruncate = truncate;
    if (enable != null) _enabled = enable;
    if (minLevel != null) _minLevel = minLevel;
    if (colorEnabled != null) _colorEnabled = colorEnabled;
  }

  /// Resets all configuration to factory defaults.
  ///
  /// Intended for use in tests to prevent state leaking between test cases.
  static void reset() {
    _instance.logHandler = developer.log;
    _defaultMaxDepth = 10;
    _defaultMaxCollectionEntries = 100;
    _defaultMaxStringLength = -1;
    _defaultTruncate = false;
    _enabled = true;
    _minLevel = LogLevel.INFO;
    _colorEnabled = true;
  }

  // --- Formatting constants ---

  static const int _borderLength = 10;
  static const String _indentSpace = '  ';
  static const String _colorReset = '\x1b[0m';

  // --- Public API ---

  /// Logs [msg] with formatted, optionally color-coded output.
  ///
  /// Formatting runs synchronously. For very large data structures, enable
  /// [truncate] to limit output size and execution time.
  ///
  /// Does nothing when globally disabled via `configure(enable: false)` or when
  /// [level] is below the configured [minLevel].
  ///
  /// - [msg]: Data to log (String, num, bool, null, Map, List, or any object).
  /// - [tag]: Label shown in the header/footer. Defaults to `"Dynamic Log"`.
  /// - [stackTrace]: Passed through to the log handler.
  /// - [level]: Severity [LogLevel]. Affects color. Defaults to [LogLevel.INFO].
  /// - [logHandlerOverride]: Overrides the configured handler for this call only.
  /// - [truncate]: Enables truncation for this call, overriding the global default.
  /// - [maxDepth]: Max nesting depth for this call (requires truncate to be active).
  /// - [maxCollectionEntries]: Max Map/List entries for this call (requires truncate).
  /// - [maxStringLength]: Max string length for this call (requires truncate).
  static void log(
    dynamic msg, {
    String? tag,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.INFO,
    LogHandler? logHandlerOverride,
    bool? truncate,
    int? maxDepth,
    int? maxCollectionEntries,
    int? maxStringLength,
  }) {
    if (!_enabled) return;
    if (level.index < _minLevel.index) return;

    final bool shouldTruncate = truncate ?? _defaultTruncate;
    final int effectiveMaxDepth =
        shouldTruncate ? (maxDepth ?? _defaultMaxDepth) : -1;
    final int effectiveMaxEntries = shouldTruncate
        ? (maxCollectionEntries ?? _defaultMaxCollectionEntries)
        : -1;
    final int effectiveMaxStringLength =
        shouldTruncate ? (maxStringLength ?? _defaultMaxStringLength) : -1;

    final color = _colorEnabled ? _getColorCode(level) : '';
    final resetCode = _colorEnabled ? _colorReset : '';
    final name = tag ?? 'Dynamic Log';

    final buffer = StringBuffer();
    buffer.writeln('$color${_logHeader(name)}$resetCode');

    final contentBuffer = StringBuffer();
    try {
      if (msg == null || msg is String || msg is num || msg is bool) {
        contentBuffer.writeln(
            '$color${_formatValue(msg, maxStringLength: effectiveMaxStringLength)}$resetCode');
      } else {
        _formatColored(
          contentBuffer,
          msg,
          color: color,
          resetCode: resetCode,
          depth: 0,
          maxDepth: effectiveMaxDepth,
          maxCollectionEntries: effectiveMaxEntries,
          maxStringLength: effectiveMaxStringLength,
        );
      }
    } catch (e) {
      contentBuffer.clear();
      contentBuffer
          .writeln('$color$_indentSpace[Log formatting error]: $e$resetCode');
      contentBuffer
          .writeln('$color$_indentSpace${_formatValue(msg)}$resetCode');
    }

    buffer.write(contentBuffer.toString().trimRight());
    if (!buffer.toString().endsWith('\n')) buffer.writeln();
    buffer.writeln('$color${_logFooter(name)}$resetCode');

    final formattedMessage = buffer.toString().trimRight();
    final handler = logHandlerOverride ?? _instance.logHandler;
    handler(
      formattedMessage,
      name: 'LOGGER',
      stackTrace: stackTrace,
      level: _mapLogLevel(level),
    );
  }

  /// Formats [data] into a plain-text string without logging.
  ///
  /// Useful for debug panels or other non-log output. No ANSI color codes are
  /// emitted. Respects the global truncation defaults unless overridden.
  static String formatData(
    dynamic data, {
    bool? truncate,
    int? maxDepth,
    int? maxCollectionEntries,
    int? maxStringLength,
  }) {
    final bool shouldTruncate = truncate ?? _defaultTruncate;
    final int effectiveMaxDepth =
        shouldTruncate ? (maxDepth ?? _defaultMaxDepth) : -1;
    final int effectiveMaxEntries = shouldTruncate
        ? (maxCollectionEntries ?? _defaultMaxCollectionEntries)
        : -1;
    final int effectiveMaxStringLength =
        shouldTruncate ? (maxStringLength ?? _defaultMaxStringLength) : -1;

    final buffer = StringBuffer();
    _formatPlain(
      buffer,
      data,
      depth: 0,
      maxDepth: effectiveMaxDepth,
      maxCollectionEntries: effectiveMaxEntries,
      maxStringLength: effectiveMaxStringLength,
    );
    return buffer.toString().trimRight();
  }

  // --- Header / Footer ---

  static String _logHeader(String name) {
    final border = '─' * _borderLength;
    return '┌$border┤ $name ├$border┐';
  }

  static String _logFooter(String name) {
    final totalLength = (_borderLength * 2) + name.length + 4;
    return '└${'─' * totalLength}┘';
  }

  // --- Colored formatters (used by log()) ---

  static void _formatColored(
    StringBuffer buffer,
    dynamic data, {
    required String color,
    required String resetCode,
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;

    if (maxDepth != -1 && depth >= maxDepth) {
      buffer.writeln('$color$indent... (Max depth reached)$resetCode');
      return;
    }

    if (data == null || data is String || data is num || data is bool) {
      buffer.writeln(
          '$color$indent${_formatValue(data, maxStringLength: maxStringLength)}$resetCode');
    } else if (data is Map) {
      _coloredMap(buffer, data,
          color: color,
          resetCode: resetCode,
          depth: depth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);
    } else if (data is List) {
      _coloredList(buffer, data,
          color: color,
          resetCode: resetCode,
          depth: depth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);
    } else {
      buffer.writeln('$color$indent$data$resetCode');
    }
  }

  static void _coloredList(
    StringBuffer buffer,
    List data, {
    required String color,
    required String resetCode,
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;
    final itemDepth = depth + 1;
    final itemIndent = _indentSpace * itemDepth;

    if (data.isEmpty) {
      buffer.writeln('$color$indent[]$resetCode');
      return;
    }

    buffer.writeln('$color$indent[$resetCode');
    int count = 0;
    for (int i = 0; i < data.length; i++) {
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$color$itemIndent... (${data.length - count} more items)$resetCode');
        break;
      }
      final isLast = i == data.length - 1;
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      final itemBuffer = StringBuffer();
      _formatColored(itemBuffer, data[i],
          color: color,
          resetCode: resetCode,
          depth: itemDepth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);

      final lines = itemBuffer.toString().trimRight().split('\n');
      for (int j = 0; j < lines.length; j++) {
        if (j == lines.length - 1) {
          buffer.writeln('${lines[j]}$color$comma$resetCode');
        } else {
          buffer.writeln(lines[j]);
        }
      }
      count++;
    }
    buffer.writeln('$color$indent]$resetCode');
  }

  static void _coloredMap(
    StringBuffer buffer,
    Map data, {
    required String color,
    required String resetCode,
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;
    final entryDepth = depth + 1;
    final entryIndent = _indentSpace * entryDepth;

    if (data.isEmpty) {
      buffer.writeln('$color$indent{}$resetCode');
      return;
    }

    buffer.writeln('$color$indent{$resetCode');
    int count = 0;
    final entries = data.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$color$entryIndent... (${entries.length - count} more entries)$resetCode');
        break;
      }
      final key = entries[i].key;
      final value = entries[i].value;
      final isLast = i == entries.length - 1;
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';
      final keyStr = '$color$entryIndent"$key": ';

      if (value == null || value is String || value is num || value is bool) {
        buffer.writeln(
            '$keyStr$color${_formatValue(value, maxStringLength: maxStringLength)}$comma$resetCode');
      } else if ((value is Map && value.isEmpty) ||
          (value is List && value.isEmpty)) {
        buffer.writeln(
            '$keyStr$color${value is Map ? '{}' : '[]'}$comma$resetCode');
      } else {
        buffer.writeln('${keyStr.trimRight()}$resetCode');

        final valueBuffer = StringBuffer();
        _formatColored(valueBuffer, value,
            color: color,
            resetCode: resetCode,
            depth: entryDepth,
            maxDepth: maxDepth,
            maxCollectionEntries: maxCollectionEntries,
            maxStringLength: maxStringLength);

        final lines = valueBuffer.toString().trimRight().split('\n');
        for (int j = 0; j < lines.length; j++) {
          if (j == lines.length - 1) {
            buffer.writeln('${lines[j]}$color$comma$resetCode');
          } else {
            buffer.writeln(lines[j]);
          }
        }
      }
      count++;
    }
    buffer.writeln('$color$indent}$resetCode');
  }

  // --- Plain-text formatters (used by formatData()) ---

  static void _formatPlain(
    StringBuffer buffer,
    dynamic data, {
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;

    if (maxDepth != -1 && depth >= maxDepth) {
      buffer.writeln('$indent... (Max depth reached)');
      return;
    }

    if (data == null || data is String || data is num || data is bool) {
      buffer.writeln(
          '$indent${_formatValue(data, maxStringLength: maxStringLength)}');
    } else if (data is Map) {
      _plainMap(buffer, data,
          depth: depth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);
    } else if (data is List) {
      _plainList(buffer, data,
          depth: depth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);
    } else {
      buffer.writeln('$indent$data');
    }
  }

  static void _plainMap(
    StringBuffer buffer,
    Map data, {
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;
    final entryDepth = depth + 1;
    final entryIndent = _indentSpace * entryDepth;

    if (data.isEmpty) {
      buffer.writeln('$indent{}');
      return;
    }

    buffer.writeln('$indent{');
    int count = 0;
    final entries = data.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln(
            '$entryIndent... (${entries.length - count} more entries)');
        break;
      }
      final key = entries[i].key;
      final value = entries[i].value;
      final isLast = i == entries.length - 1;
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';
      final keyStr = '$entryIndent"$key": ';

      if (value == null || value is String || value is num || value is bool) {
        buffer.writeln(
            '$keyStr${_formatValue(value, maxStringLength: maxStringLength)}$comma');
      } else if ((value is Map && value.isEmpty) ||
          (value is List && value.isEmpty)) {
        buffer.writeln('$keyStr${value is Map ? '{}' : '[]'}$comma');
      } else {
        buffer.writeln(keyStr.trimRight());

        final valueBuffer = StringBuffer();
        _formatPlain(valueBuffer, value,
            depth: entryDepth,
            maxDepth: maxDepth,
            maxCollectionEntries: maxCollectionEntries,
            maxStringLength: maxStringLength);

        final lines = valueBuffer.toString().trimRight().split('\n');
        for (int j = 0; j < lines.length; j++) {
          buffer
              .writeln(j == lines.length - 1 ? '${lines[j]}$comma' : lines[j]);
        }
      }
      count++;
    }
    buffer.writeln('$indent}');
  }

  static void _plainList(
    StringBuffer buffer,
    List data, {
    required int depth,
    required int maxDepth,
    required int maxCollectionEntries,
    required int maxStringLength,
  }) {
    final indent = _indentSpace * depth;
    final itemDepth = depth + 1;
    final itemIndent = _indentSpace * itemDepth;

    if (data.isEmpty) {
      buffer.writeln('$indent[]');
      return;
    }

    buffer.writeln('$indent[');
    int count = 0;
    for (int i = 0; i < data.length; i++) {
      if (maxCollectionEntries != -1 && count >= maxCollectionEntries) {
        buffer.writeln('$itemIndent... (${data.length - count} more items)');
        break;
      }
      final isLast = i == data.length - 1;
      final comma = !isLast &&
              (maxCollectionEntries == -1 || count < maxCollectionEntries - 1)
          ? ','
          : '';

      final itemBuffer = StringBuffer();
      _formatPlain(itemBuffer, data[i],
          depth: itemDepth,
          maxDepth: maxDepth,
          maxCollectionEntries: maxCollectionEntries,
          maxStringLength: maxStringLength);

      final lines = itemBuffer.toString().trimRight().split('\n');
      for (int j = 0; j < lines.length; j++) {
        buffer.writeln(j == lines.length - 1 ? '${lines[j]}$comma' : lines[j]);
      }
      count++;
    }
    buffer.writeln('$indent]');
  }

  // --- Value formatting ---

  static String _formatValue(dynamic value, {int maxStringLength = -1}) {
    if (value == null) return 'null';
    if (value is String) {
      if (maxStringLength != -1 && value.length > maxStringLength) {
        final truncated = value.substring(0, maxStringLength);
        return '"$truncated"... (${value.length - maxStringLength} more chars)';
      }
      return jsonEncode(value);
    }
    if (value is num || value is bool) return value.toString();
    try {
      return jsonEncode(value);
    } catch (_) {
      return jsonEncode(value.toString());
    }
  }

  // --- Color and level mapping ---

  static String _getColorCode(LogLevel level) {
    switch (level) {
      case LogLevel.INFO:
        return '\x1B[38;5;45m';
      case LogLevel.WARNING:
        return '\x1B[33m';
      case LogLevel.ERROR:
        return '\x1B[38;5;196m';
    }
  }

  static int _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.INFO:
        return 700;
      case LogLevel.WARNING:
        return 900;
      case LogLevel.ERROR:
        return 1000;
    }
  }
}
