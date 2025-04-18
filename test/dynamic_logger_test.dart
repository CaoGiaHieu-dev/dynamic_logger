import 'dart:async';

import 'package:dynamic_logger/dynamic_logger.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class TestLogHandler {
  final List<String> logs = [];
  final bool stripAnsi; // Option to remove color codes for easier comparison

  TestLogHandler({this.stripAnsi = true});

  // ANSI color code regex
  final _ansiRegex = RegExp(r'\x1b\[[0-9;]*m');

  void call(
    String message, {
    Object? error,
    int level = 0,
    String name = '',
    int? sequenceNumber,
    StackTrace? stackTrace,
    DateTime? time,
    Zone? zone,
  }) {
    if (stripAnsi) {
      logs.add(message.replaceAll(_ansiRegex, '')); // Remove color codes
    } else {
      logs.add(message);
    }
  }
}

void main() {
  group('DynamicLogger', () {
    late TestLogHandler logHandler;

    setUp(() {
      // Default to stripping ANSI codes for simpler string matching in tests
      logHandler = TestLogHandler(stripAnsi: true);
    });

    test('logs a simple message', () {
      DynamicLogger.log('This is an info message',
          logHandlerOverride: logHandler.call);
      expect(logHandler.logs.first, contains('This is an info message'));
    });

    test('logs a message with a specific log level', () {
      DynamicLogger.log('This is a warning message',
          level: LogLevel.WARNING, logHandlerOverride: logHandler.call);
      expect(logHandler.logs.first, contains('This is a warning message'));
    });

    test('logs a message with a tag', () {
      DynamicLogger.log('This is an error message',
          tag: 'MyTag',
          level: LogLevel.ERROR,
          logHandlerOverride: logHandler.call);
      // Check for tag in the header/footer line
      expect(logHandler.logs.first, contains('MyTag'));
      // Check for message content
      expect(logHandler.logs.first, contains('This is an error message'));
    });

    test('logs a complex data structure like a Map', () {
      final mapData = {'key': 'value', 'anotherKey': 123};
      DynamicLogger.log(mapData, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('"key": "value"'));
      expect(logOutput, contains('"anotherKey": 123'));
    });

    test('logs a Dio RequestOptions object', () {
      final requestOptions = RequestOptions(
        path: '/test',
        method: 'GET',
        headers: {
          'Authorization': 'Bearer token',
          'Accept': 'application/json'
        },
        queryParameters: {'id': 10, 'active': true},
        data: {'name': 'test data'},
        connectTimeout: const Duration(seconds: 5),
      );
      DynamicLogger.log(requestOptions, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('Request: GET /test'));
      expect(logOutput, contains('Headers:'));
      expect(logOutput, contains('"Authorization": "Bearer token"'));
      expect(logOutput, contains('"Accept": "application/json"'));
      expect(logOutput, contains('Query Parameters:'));
      expect(logOutput, contains('"id": 10'));
      expect(logOutput, contains('"active": true'));
      expect(logOutput, contains('Data:'));
      expect(logOutput, contains('"name": "test data"'));
      expect(logOutput, contains('--- Options ---'));
      expect(logOutput, contains('Connect Timeout (ms): 5000'));
    });

    test('logs FormData', () {
      final formData = FormData.fromMap({
        'field1': 'value1',
        'field2': 1234,
        'file': MultipartFile.fromString('file content',
            filename: 'file.txt',
            contentType: DioMediaType.parse('text/plain')),
        'anotherField': true,
      });
      DynamicLogger.log(formData, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('Fields: {'));
      expect(logOutput, contains('"field1": "value1"'));
      expect(
          logOutput, contains('"field2": "1234"')); // Expect the string "1234"
      expect(logOutput,
          contains('"anotherField": "true"')); // Expect the string "true"

      expect(logOutput, contains('Files: {'));
      expect(
          logOutput,
          contains(
              '"file": "File(name: \\"file.txt\\", type: text/plain; charset=utf-8, size: 12)"')); // Check file details formatting including charset
    });

    test('logs a list', () {
      final listData = ['item1', 2, true, null];
      DynamicLogger.log(listData, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('"item1"'));
      expect(logOutput, contains('2'));
      expect(logOutput, contains('true'));
      expect(logOutput, contains('null'));
    });

    test('logs a nested list', () {
      final nestedListData = [
        'item1',
        ['nestedItem1', 99, []], // Nested list with empty list
        'item2',
        {} // Empty map
      ];
      DynamicLogger.log(nestedListData, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('"item1"'));
      expect(logOutput, contains('"nestedItem1"'));
      expect(logOutput, contains('99'));
      expect(logOutput, contains('[]')); // Check inner empty list
      expect(logOutput, contains('"item2"'));
      expect(logOutput, contains('{}')); // Check empty map
    });

    test('logs a nested map', () {
      final nestedMapData = {
        'key1': 'value1',
        'nestedMap': {
          'nestedKey1': 'nestedValue1',
          'nestedNum': 42.5,
          'nestedBool': false,
        }
      };
      DynamicLogger.log(nestedMapData, logHandlerOverride: logHandler.call);
      final logOutput = logHandler.logs.first;
      expect(logOutput, contains('"key1": "value1"'));
      expect(logOutput, contains('"nestedMap":')); // Check key exists
      expect(logOutput, contains('"nestedKey1": "nestedValue1"'));
      expect(logOutput, contains('"nestedNum": 42.5'));
      expect(logOutput, contains('"nestedBool": false'));
    });

    test('logs a message with stack trace', () {
      final stackTrace = StackTrace.current;
      DynamicLogger.log('Error with stack trace',
          stackTrace: stackTrace,
          level: LogLevel.ERROR,
          logHandlerOverride: logHandler.call);
      // Stack trace isn't part of the formatted message string itself,
      // but passed to the handler. We just check the message content here.
      expect(logHandler.logs.first, contains('Error with stack trace'));
    });

    // --- New Complex Test Case ---
    test('logs complex nested data structure correctly', () {
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

      DynamicLogger.log(complexData,
          tag: 'ComplexDataTest', logHandlerOverride: logHandler.call);

      // --- Assertions ---
      // It's hard to match the exact multi-line string with indentation and colors.
      // Instead, check for the presence of key structural elements and values.
      expect(logHandler.logs.length, 1);
      final logOutput = logHandler.logs.first;

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
