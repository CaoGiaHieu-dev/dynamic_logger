import 'dart:async';

import 'package:dynamic_logger/dynamic_logger.dart';
import 'package:test/test.dart';

class TestLogHandler {
  final List<String> logs = [];
  final bool stripAnsi; // Option to remove color codes for easier comparison
  Completer<String>? _completer; // Completer to signal when a log is received

  TestLogHandler({this.stripAnsi = true});

  // ANSI color code regex
  final _ansiRegex = RegExp(r'\x1b\[[0-9;]*m');

  void call(
    String message, {
    Object? error,
    int level = 0,
    String name = '',
    StackTrace? stackTrace,
    DateTime? time,
    Zone? zone,
    int? sequenceNumber,
  }) {
    if (stripAnsi) {
      logs.add(message.replaceAll(_ansiRegex, '')); // Remove color codes
    } else {
      logs.add(message);
    }
    _completer?.complete(logs.last); // Complete the completer with the last log
  }

  // Resets the completer and returns a Future that completes when the next log is received.
  Future<String> waitForLog() {
    _completer = Completer<String>();
    return _completer!.future;
  }
}

void main() {
  group('DynamicLogger', () {
    late TestLogHandler logHandler;

    setUp(() {
      // Default to stripping ANSI codes for simpler string matching in tests
      logHandler = TestLogHandler(stripAnsi: true);
      // Configure the logger to use our test handler for all subsequent tests
      DynamicLogger.configure(logHandler: logHandler.call);
    });

    test('logs a simple message', () async {
      final futureLog = logHandler.waitForLog();
      DynamicLogger.log(
        'This is an info message',
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('This is an info message'));
    });

    test('logs a message with a specific log level', () async {
      final futureLog = logHandler.waitForLog();
      DynamicLogger.log(
        'This is a warning message',
        level: LogLevel.WARNING,
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('This is a warning message'));
    });

    test('logs a message with a tag', () async {
      final futureLog = logHandler.waitForLog();
      DynamicLogger.log(
        'This is an error message',
        tag: 'MyTag',
        level: LogLevel.ERROR,
      );
      final logOutput = await futureLog;
      // Check for tag in the header/footer line
      expect(logOutput, contains('MyTag'));
      // Check for message content
      expect(logOutput, contains('This is an error message'));
    });

    test('logs a complex data structure like a Map', () async {
      final futureLog = logHandler.waitForLog();
      final mapData = {'key': 'value', 'anotherKey': 123};
      DynamicLogger.log(
        mapData,
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('"key": "value"'));
      expect(logOutput, contains('"anotherKey": 123'));
    });

    test('logs a list', () async {
      final futureLog = logHandler.waitForLog();
      final listData = ['item1', 2, true, null];
      DynamicLogger.log(
        listData,
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('"item1"'));
      expect(logOutput, contains('2'));
      expect(logOutput, contains('true'));
      expect(logOutput, contains('null'));
    });

    test('logs a nested list', () async {
      final futureLog = logHandler.waitForLog();
      final nestedListData = [
        'item1',
        ['nestedItem1', 99, []], // Nested list with empty list
        'item2',
        {} // Empty map
      ];
      DynamicLogger.log(
        nestedListData,
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('"item1"'));
      expect(logOutput, contains('"nestedItem1"'));
      expect(logOutput, contains('99'));
      expect(logOutput, contains('[]')); // Check inner empty list
      expect(logOutput, contains('"item2"'));
      expect(logOutput, contains('{}')); // Check empty map
    });

    test('logs a nested map', () async {
      final futureLog = logHandler.waitForLog();
      final nestedMapData = {
        'key1': 'value1',
        'nestedMap': {
          'nestedKey1': 'nestedValue1',
          'nestedNum': 42.5,
          'nestedBool': false,
        }
      };
      DynamicLogger.log(
        nestedMapData,
      );
      final logOutput = await futureLog;
      expect(logOutput, contains('"key1": "value1"'));
      expect(logOutput, contains('"nestedMap":')); // Check key exists
      expect(logOutput, contains('"nestedKey1": "nestedValue1"'));
      expect(logOutput, contains('"nestedNum": 42.5'));
      expect(logOutput, contains('"nestedBool": false'));
    });

    test('logs a message with stack trace', () async {
      final futureLog = logHandler.waitForLog();
      final stackTrace = StackTrace.current;
      DynamicLogger.log(
        'Error with stack trace',
        stackTrace: stackTrace,
        level: LogLevel.ERROR,
      );
      final logOutput = await futureLog;
      // Stack trace isn't part of the formatted message string itself,
      // but passed to the handler. We just check the message content here.
      expect(logOutput, contains('Error with stack trace'));
    });

    // --- New Complex Test Case ---
    test('logs complex nested data structure correctly', () async {
      final futureLog = logHandler.waitForLog();
      final complexData = {
        'stringKey': 'A simple string with "quotes" and\nnewlines.',
        'integerKey': 12345,
        'doubleKey': 3.14159,
        'booleanKey': true,
        'nullKey': null,
        'listKey': [
          'List item 1',
          987,
          false,
          null,
          [], // Empty list
          {
            'mapInListKey': 'Value inside map in list',
            'anotherMapInListKey': 100,
            'nullInMapInList': null,
          },
          'List item last'
        ],
        'mapKey': {
          'nestedString': 'Nested string value',
          'nestedList': [
            {'deepMapInList': true, 'id': 'a-1'},
            'Another item in nested list',
            123,
          ],
          'deeplyNestedMap': {
            'finalKey': 'Reached the end!',
            'anotherBool': false,
          },
          'emptyMapValue': {}, // Empty map
          'emptyListValue': [], // Empty list
        },
        'longStringKey':
            'This is a relatively long string designed to test how the logger handles wrapping or displaying longer text values within the structure.',
      };

      DynamicLogger.log(
        complexData,
        tag: 'ComplexDataTest',
      );

      final logOutput = await futureLog;
      // --- Assertions ---
      // It's hard to match the exact multi-line string with indentation and colors.
      // Instead, check for the presence of key structural elements and values.
      expect(logHandler.logs.length, 1);

      // Check Header/Footer Tag
      expect(logOutput, contains('ComplexDataTest'));

      // Check top-level elements (including correct JSON string encoding)
      expect(
          logOutput,
          contains(
              '"stringKey": "A simple string with \\"quotes\\" and\\nnewlines."'));
      expect(logOutput, contains('"integerKey": 12345'));
      expect(logOutput, contains('"doubleKey": 3.14159'));
      expect(logOutput, contains('"booleanKey": true'));
      expect(logOutput, contains('"nullKey": null'));

      // Check list elements
      expect(logOutput, contains('"List item 1"'));
      expect(logOutput, contains('987'));
      expect(logOutput, contains('false'));
      // Check list contains null (might be tricky depending on exact formatting)
      // A safer check might be for the surrounding elements
      expect(
          logOutput,
          contains(
              'false,\n    null,')); // Check null preceded by false and comma (4 spaces)
      expect(
          logOutput,
          contains(
              'null,\n    [],')); // Check null followed by empty list and comma (4 spaces)

      // Check map within list
      expect(logOutput, contains('"mapInListKey": "Value inside map in list"'));
      expect(logOutput, contains('"anotherMapInListKey": 100'));
      expect(logOutput, contains('"nullInMapInList": null'));

      // Check nested map elements
      expect(logOutput, contains('"nestedString": "Nested string value"'));

      // Check list within map
      expect(logOutput, contains('"nestedList":'));
      expect(logOutput, contains('"deepMapInList": true'));
      expect(logOutput, contains('"id": "a-1"'));
      expect(logOutput, contains('"Another item in nested list"'));
      expect(logOutput, contains('123')); // Number in list

      // Check deeply nested map
      expect(logOutput, contains('"deeplyNestedMap":'));
      expect(logOutput, contains('"finalKey": "Reached the end!"'));
      expect(logOutput, contains('"anotherBool": false'));

      // Check empty structures within map
      expect(logOutput, contains('"emptyMapValue": {}'));
      expect(logOutput, contains('"emptyListValue": []'));

      // Check long string key/value presence
      expect(logOutput, contains('"longStringKey":'));
      expect(logOutput, contains('longer text values within the structure'));
    });
    // --- End of New Complex Test Case ---
  });
}
