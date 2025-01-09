import 'dart:async';

import 'package:dynamic_logger/dynamic_logger.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class TestLogHandler {
  final List<String> logs = [];

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
    logs.add(message);
  }
}

void main() {
  group('DynamicLogger', () {
    late TestLogHandler logHandler;

    setUp(() {
      logHandler = TestLogHandler();
    });

    test('logs a simple message', () {
      DynamicLogger.log('This is an info message', logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('This is an info message')));
    });

    test('logs a message with a specific log level', () {
      DynamicLogger.log('This is a warning message',
          level: LogLevel.WARNING, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('This is a warning message')));
    });

    test('logs a message with a tag', () {
      DynamicLogger.log('This is an error message',
          tag: 'MyTag', level: LogLevel.ERROR, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('MyTag')));
    });

    test('logs a complex data structure like a Map', () {
      final mapData = {'key': 'value', 'anotherKey': 'anotherValue'};
      DynamicLogger.log(mapData, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('"key" : "value"')));
    });

    test('logs a Dio RequestOptions object', () {
      final requestOptions = RequestOptions(
        path: '/test',
        method: 'GET',
        headers: {'Authorization': 'Bearer token'},
      );
      DynamicLogger.log(requestOptions, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('Request: GET /test')));
    });

    test('logs FormData', () {
      final formData = FormData.fromMap({
        'field1': 'value1',
        'field2': 'value2',
        'file': MultipartFile.fromString('file content', filename: 'file.txt'),
      });
      DynamicLogger.log(formData, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('"field1" : "value1"')));
    });

    test('logs a list', () {
      final listData = ['item1', 'item2', 'item3'];
      DynamicLogger.log(listData, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('"item1"')));
    });

    test('logs a nested list', () {
      final nestedListData = [
        'item1',
        ['nestedItem1', 'nestedItem2'],
        'item2'
      ];
      DynamicLogger.log(nestedListData, logHandler: logHandler.call);
      expect(logHandler.logs, contains(contains('"nestedItem1"')));
    });

    test('logs a nested map', () {
      final nestedMapData = {
        'key1': 'value1',
        'nestedMap': {'nestedKey1': 'nestedValue1'}
      };
      DynamicLogger.log(nestedMapData, logHandler: logHandler.call);
      expect(
          logHandler.logs, contains(contains('"nestedKey1" : "nestedValue1"')));
    });

    test('logs a message with stack trace', () {
      final stackTrace = StackTrace.current;
      DynamicLogger.log('This is an error message with stack trace',
          stackTrace: stackTrace,
          level: LogLevel.ERROR,
          logHandler: logHandler.call);
      expect(logHandler.logs,
          contains(contains('This is an error message with stack trace')));
    });
  });
}
