import 'dart:async';

import 'package:dynamic_logger/dynamic_logger.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

class TestLogHandler {
  final List<String> logs = [];
  final List<int> levels = [];
  final List<StackTrace?> stackTraces = [];
  final bool stripAnsi;

  TestLogHandler({this.stripAnsi = true});

  static final _ansiRegex = RegExp(r'\x1b\[[0-9;]*m');

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
    final processed = stripAnsi ? message.replaceAll(_ansiRegex, '') : message;
    logs.add(processed);
    levels.add(level);
    stackTraces.add(stackTrace);
  }

  String get last => logs.last;
  int get lastLevel => levels.last;
  StackTrace? get lastStackTrace => stackTraces.last;
  void clear() {
    logs.clear();
    levels.clear();
    stackTraces.clear();
  }
}

class _CustomObject {
  final String value;
  _CustomObject(this.value);

  @override
  String toString() => 'CustomObject($value)';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DynamicLogger', () {
    late TestLogHandler handler;

    setUp(() {
      handler = TestLogHandler(stripAnsi: true);
      DynamicLogger.configure(logHandler: handler.call);
    });

    tearDown(() {
      DynamicLogger.reset();
    });

    // -----------------------------------------------------------------------
    // Primitive messages
    // -----------------------------------------------------------------------

    group('primitive messages', () {
      test('logs a String', () {
        DynamicLogger.log('Hello, world!');
        expect(handler.last, contains('Hello, world!'));
      });

      test('logs null', () {
        DynamicLogger.log(null);
        expect(handler.last, contains('null'));
      });

      test('logs an int', () {
        DynamicLogger.log(42);
        expect(handler.last, contains('42'));
      });

      test('logs a double', () {
        DynamicLogger.log(3.14);
        expect(handler.last, contains('3.14'));
      });

      test('logs bool true', () {
        DynamicLogger.log(true);
        expect(handler.last, contains('true'));
      });

      test('logs bool false', () {
        DynamicLogger.log(false);
        expect(handler.last, contains('false'));
      });

      test('encodes String with quotes and newlines as valid JSON', () {
        DynamicLogger.log('Say "hello"\nworld');
        expect(handler.last, contains('"Say \\"hello\\"\\nworld"'));
      });

      test('logs an empty String', () {
        DynamicLogger.log('');
        expect(handler.last, contains('""'));
      });
    });

    // -----------------------------------------------------------------------
    // Log levels
    // -----------------------------------------------------------------------

    group('log levels', () {
      test('defaults to INFO level (700)', () {
        DynamicLogger.log('info msg');
        expect(handler.lastLevel, 700);
      });

      test('WARNING maps to level 900', () {
        DynamicLogger.log('warn', level: LogLevel.WARNING);
        expect(handler.lastLevel, 900);
      });

      test('ERROR maps to level 1000', () {
        DynamicLogger.log('err', level: LogLevel.ERROR);
        expect(handler.lastLevel, 1000);
      });
    });

    // -----------------------------------------------------------------------
    // Header / Footer
    // -----------------------------------------------------------------------

    group('header and footer', () {
      test('default tag is "Dynamic Log"', () {
        DynamicLogger.log('msg');
        expect(handler.last, contains('Dynamic Log'));
      });

      test('custom tag appears in output', () {
        DynamicLogger.log('msg', tag: 'MyTag');
        expect(handler.last, contains('MyTag'));
      });

      test('footer length equals header length', () {
        DynamicLogger.log('msg', tag: 'ABC');
        final lines = handler.last.split('\n');
        final header = lines.first;
        final footer = lines.last;
        expect(footer.length, equals(header.length),
            reason: 'header and footer must be the same width');
      });

      test('header starts with ┌ and ends with ┐', () {
        DynamicLogger.log('msg', tag: 'T');
        final header = handler.last.split('\n').first;
        expect(header, startsWith('┌'));
        expect(header, endsWith('┐'));
      });

      test('footer starts with └ and ends with ┘', () {
        DynamicLogger.log('msg', tag: 'T');
        final footer = handler.last.split('\n').last;
        expect(footer, startsWith('└'));
        expect(footer, endsWith('┘'));
      });

      test('header contains tag label', () {
        DynamicLogger.log('msg', tag: 'UniqueTag');
        expect(handler.last.split('\n').first, contains('UniqueTag'));
      });
    });

    // -----------------------------------------------------------------------
    // Collections
    // -----------------------------------------------------------------------

    group('collections', () {
      test('logs empty Map on one line', () {
        DynamicLogger.log({});
        expect(handler.last, contains('{}'));
      });

      test('logs empty List on one line', () {
        DynamicLogger.log([]);
        expect(handler.last, contains('[]'));
      });

      test('logs flat Map with mixed value types', () {
        DynamicLogger.log({'s': 'v', 'n': 1, 'b': true, 'nil': null});
        final out = handler.last;
        expect(out, contains('"s": "v"'));
        expect(out, contains('"n": 1'));
        expect(out, contains('"b": true'));
        expect(out, contains('"nil": null'));
      });

      test('logs flat List with mixed types', () {
        DynamicLogger.log(['a', 2, false, null]);
        final out = handler.last;
        expect(out, contains('"a"'));
        expect(out, contains('2'));
        expect(out, contains('false'));
        expect(out, contains('null'));
      });

      test('empty Map value is inline with key', () {
        DynamicLogger.log({'key': {}});
        expect(handler.last, contains('"key": {}'));
      });

      test('empty List value is inline with key', () {
        DynamicLogger.log({'key': []});
        expect(handler.last, contains('"key": []'));
      });

      test('logs nested Map', () {
        DynamicLogger.log({
          'outer': {'inner': 'value', 'num': 99}
        });
        final out = handler.last;
        expect(out, contains('"outer":'));
        expect(out, contains('"inner": "value"'));
        expect(out, contains('"num": 99'));
      });

      test('logs nested List', () {
        DynamicLogger.log([
          [1, 2],
          [3, 4]
        ]);
        final out = handler.last;
        expect(out, contains('1'));
        expect(out, contains('4'));
      });

      test('logs Map inside List', () {
        DynamicLogger.log([
          {'k': 'v'}
        ]);
        expect(handler.last, contains('"k": "v"'));
      });

      test('logs List inside Map value', () {
        DynamicLogger.log({
          'items': ['a', 'b', 'c']
        });
        expect(handler.last, contains('"items":'));
        expect(handler.last, contains('"a"'));
        expect(handler.last, contains('"c"'));
      });

      test('commas between List items, no trailing comma', () {
        DynamicLogger.log([1, 2, 3]);
        final out = handler.last;
        expect(out, contains('1,'));
        expect(out, contains('2,'));
        expect(out, isNot(contains('3,')));
      });

      test('commas between Map entries, no trailing comma', () {
        DynamicLogger.log({'a': 1, 'b': 2, 'c': 3});
        final out = handler.last;
        expect(out, contains('"a": 1,'));
        expect(out, contains('"b": 2,'));
        expect(out, isNot(contains('"c": 3,')));
      });
    });

    // -----------------------------------------------------------------------
    // Unknown object types
    // -----------------------------------------------------------------------

    group('unknown object types', () {
      test('falls back to toString() for unknown objects', () {
        DynamicLogger.log(_CustomObject('hello'));
        expect(handler.last, contains('CustomObject(hello)'));
      });
    });

    // -----------------------------------------------------------------------
    // Stack trace
    // -----------------------------------------------------------------------

    group('stack trace', () {
      test('passes stack trace to log handler', () {
        final trace = StackTrace.current;
        DynamicLogger.log('msg', stackTrace: trace, level: LogLevel.ERROR);
        expect(handler.lastStackTrace, same(trace));
      });

      test('null stack trace when not provided', () {
        DynamicLogger.log('no trace');
        expect(handler.lastStackTrace, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // logHandlerOverride
    // -----------------------------------------------------------------------

    group('logHandlerOverride', () {
      test('uses override handler for a single call', () {
        final override = TestLogHandler(stripAnsi: true);
        DynamicLogger.log('only here', logHandlerOverride: override.call);
        expect(override.logs, hasLength(1));
        expect(override.last, contains('only here'));
        expect(handler.logs, isEmpty);
      });

      test('default handler is used on subsequent calls', () {
        final override = TestLogHandler(stripAnsi: true);
        DynamicLogger.log('one', logHandlerOverride: override.call);
        DynamicLogger.log('two');
        expect(handler.logs, hasLength(1));
        expect(handler.last, contains('two'));
      });
    });

    // -----------------------------------------------------------------------
    // enable / disable
    // -----------------------------------------------------------------------

    group('enable / disable', () {
      test('disabled logger produces no output', () {
        DynamicLogger.configure(enable: false);
        DynamicLogger.log('should not appear');
        expect(handler.logs, isEmpty);
      });

      test('re-enabling logger resumes output', () {
        DynamicLogger.configure(enable: false);
        DynamicLogger.log('ignored');
        DynamicLogger.configure(enable: true);
        DynamicLogger.log('visible');
        expect(handler.logs, hasLength(1));
        expect(handler.last, contains('visible'));
      });
    });

    // -----------------------------------------------------------------------
    // minLevel filter
    // -----------------------------------------------------------------------

    group('minLevel', () {
      test('INFO passes when minLevel is INFO', () {
        DynamicLogger.configure(minLevel: LogLevel.INFO);
        DynamicLogger.log('info', level: LogLevel.INFO);
        expect(handler.logs, hasLength(1));
      });

      test('INFO is dropped when minLevel is WARNING', () {
        DynamicLogger.configure(minLevel: LogLevel.WARNING);
        DynamicLogger.log('info', level: LogLevel.INFO);
        expect(handler.logs, isEmpty);
      });

      test('WARNING passes when minLevel is WARNING', () {
        DynamicLogger.configure(minLevel: LogLevel.WARNING);
        DynamicLogger.log('warn', level: LogLevel.WARNING);
        expect(handler.logs, hasLength(1));
      });

      test('WARNING is dropped when minLevel is ERROR', () {
        DynamicLogger.configure(minLevel: LogLevel.ERROR);
        DynamicLogger.log('warn', level: LogLevel.WARNING);
        expect(handler.logs, isEmpty);
      });

      test('ERROR passes when minLevel is WARNING', () {
        DynamicLogger.configure(minLevel: LogLevel.WARNING);
        DynamicLogger.log('err', level: LogLevel.ERROR);
        expect(handler.logs, hasLength(1));
      });

      test('minLevel WARNING allows WARNING and ERROR through', () {
        DynamicLogger.configure(minLevel: LogLevel.WARNING);
        DynamicLogger.log('w', level: LogLevel.WARNING);
        DynamicLogger.log('e', level: LogLevel.ERROR);
        expect(handler.logs, hasLength(2));
      });
    });

    // -----------------------------------------------------------------------
    // colorEnabled
    // -----------------------------------------------------------------------

    group('colorEnabled', () {
      test('ANSI codes are present when colorEnabled is true', () {
        final colorHandler = TestLogHandler(stripAnsi: false);
        DynamicLogger.configure(
            logHandler: colorHandler.call, colorEnabled: true);
        DynamicLogger.log('colored');
        expect(colorHandler.last, contains('\x1b['));
      });

      test('no ANSI codes when colorEnabled is false', () {
        final colorHandler = TestLogHandler(stripAnsi: false);
        DynamicLogger.configure(
            logHandler: colorHandler.call, colorEnabled: false);
        DynamicLogger.log('plain');
        expect(colorHandler.last, isNot(contains('\x1b[')));
        expect(colorHandler.last, contains('plain'));
      });
    });

    // -----------------------------------------------------------------------
    // Truncation
    // -----------------------------------------------------------------------

    group('truncation', () {
      test('maxDepth stops recursion at specified depth', () {
        final deep = {
          'a': {
            'b': {'c': 'value'}
          }
        };
        DynamicLogger.log(deep, truncate: true, maxDepth: 2);
        expect(handler.last, contains('Max depth reached'));
        expect(handler.last, isNot(contains('"c": "value"')));
      });

      test('no depth limit when truncate is false', () {
        final deep = {
          'a': {
            'b': {'c': 'deep'}
          }
        };
        DynamicLogger.log(deep, truncate: false);
        expect(handler.last, contains('"c": "deep"'));
        expect(handler.last, isNot(contains('Max depth reached')));
      });

      test('maxCollectionEntries limits Map entries', () {
        final map = {for (var i = 0; i < 5; i++) 'k$i': i};
        DynamicLogger.log(map, truncate: true, maxCollectionEntries: 2);
        expect(handler.last, contains('more entries'));
        expect(handler.last, isNot(contains('"k4"')));
      });

      test('maxCollectionEntries limits List items', () {
        DynamicLogger.log([1, 2, 3, 4, 5],
            truncate: true, maxCollectionEntries: 2);
        expect(handler.last, contains('more items'));
        expect(handler.last, isNot(contains('5')));
      });

      test('per-call truncate: false overrides global truncate: true', () {
        DynamicLogger.configure(truncate: true, maxDepth: 1);
        DynamicLogger.log({
          'a': {'b': 'value'}
        }, truncate: false);
        expect(handler.last, contains('"b": "value"'));
        expect(handler.last, isNot(contains('Max depth reached')));
      });

      test('global truncate applies when no per-call override', () {
        DynamicLogger.configure(truncate: true, maxDepth: 1);
        DynamicLogger.log({
          'a': {'b': 'deep'}
        });
        expect(handler.last, contains('Max depth reached'));
      });

      test('per-call maxDepth overrides global maxDepth', () {
        DynamicLogger.configure(truncate: true, maxDepth: 1);
        DynamicLogger.log({
          'a': {'b': 'deep'}
        }, truncate: true, maxDepth: 10);
        expect(handler.last, contains('"b": "deep"'));
        expect(handler.last, isNot(contains('Max depth reached')));
      });
    });

    // -----------------------------------------------------------------------
    // maxStringLength
    // -----------------------------------------------------------------------

    group('maxStringLength', () {
      test('truncates strings exceeding the limit', () {
        final longStr = 'A' * 50;
        DynamicLogger.log(longStr, truncate: true, maxStringLength: 10);
        expect(handler.last, contains('more chars'));
        expect(handler.last, isNot(contains('A' * 20)));
      });

      test('does not truncate strings within the limit', () {
        DynamicLogger.log('short', truncate: true, maxStringLength: 100);
        expect(handler.last, contains('"short"'));
        expect(handler.last, isNot(contains('more chars')));
      });

      test('no string truncation when truncate is false', () {
        final longStr = 'B' * 50;
        DynamicLogger.log(longStr, truncate: false, maxStringLength: 5);
        expect(handler.last, isNot(contains('more chars')));
      });

      test('truncates long string values inside Maps', () {
        DynamicLogger.log({'k': 'X' * 50}, truncate: true, maxStringLength: 5);
        expect(handler.last, contains('more chars'));
      });

      test('truncates long string items inside Lists', () {
        DynamicLogger.log(['Y' * 50], truncate: true, maxStringLength: 5);
        expect(handler.last, contains('more chars'));
      });

      test('reports remaining character count accurately', () {
        DynamicLogger.log('ABCDEFGHIJ', truncate: true, maxStringLength: 3);
        expect(handler.last, contains('7 more chars'));
      });
    });

    // -----------------------------------------------------------------------
    // formatData
    // -----------------------------------------------------------------------

    group('formatData', () {
      test('returns plain text with no ANSI codes', () {
        final result = DynamicLogger.formatData({'k': 'v'});
        expect(result, isNot(contains('\x1b[')));
        expect(result, contains('"k": "v"'));
      });

      test('formats a flat Map', () {
        final result = DynamicLogger.formatData({'a': 1, 'b': 'two'});
        expect(result, contains('"a": 1'));
        expect(result, contains('"b": "two"'));
      });

      test('formats a List', () {
        final result = DynamicLogger.formatData([1, 'two', null]);
        expect(result, contains('1'));
        expect(result, contains('"two"'));
        expect(result, contains('null'));
      });

      test('respects maxDepth with truncate: true', () {
        final result = DynamicLogger.formatData({
          'a': {'b': 'v'}
        }, truncate: true, maxDepth: 1);
        expect(result, contains('Max depth reached'));
        expect(result, isNot(contains('"b"')));
      });

      test('respects maxCollectionEntries with truncate: true', () {
        final result = DynamicLogger.formatData([1, 2, 3, 4, 5],
            truncate: true, maxCollectionEntries: 2);
        expect(result, contains('more items'));
      });

      test('respects maxStringLength with truncate: true', () {
        final result = DynamicLogger.formatData('A' * 30,
            truncate: true, maxStringLength: 5);
        expect(result, contains('more chars'));
      });

      test('does not emit any log output', () {
        DynamicLogger.formatData({'silent': true});
        expect(handler.logs, isEmpty);
      });

      test('formats empty Map as {}', () {
        expect(DynamicLogger.formatData({}), contains('{}'));
      });

      test('formats empty List as []', () {
        expect(DynamicLogger.formatData([]), contains('[]'));
      });
    });

    // -----------------------------------------------------------------------
    // reset()
    // -----------------------------------------------------------------------

    group('reset', () {
      test('reset re-enables a disabled logger', () {
        DynamicLogger.configure(enable: false);
        DynamicLogger.reset();
        DynamicLogger.configure(logHandler: handler.call);
        DynamicLogger.log('after reset');
        expect(handler.logs, hasLength(1));
      });

      test('reset restores minLevel to INFO', () {
        DynamicLogger.configure(minLevel: LogLevel.ERROR);
        DynamicLogger.reset();
        DynamicLogger.configure(logHandler: handler.call);
        DynamicLogger.log('info after reset', level: LogLevel.INFO);
        expect(handler.logs, hasLength(1));
      });

      test('reset restores truncate to false', () {
        DynamicLogger.configure(truncate: true, maxDepth: 1);
        DynamicLogger.reset();
        DynamicLogger.configure(logHandler: handler.call);
        DynamicLogger.log({
          'a': {'b': 'deep'}
        });
        expect(handler.last, contains('"b": "deep"'));
        expect(handler.last, isNot(contains('Max depth reached')));
      });

      test('reset restores colorEnabled to true', () {
        final colorHandler = TestLogHandler(stripAnsi: false);
        DynamicLogger.configure(colorEnabled: false);
        DynamicLogger.reset();
        DynamicLogger.configure(logHandler: colorHandler.call);
        DynamicLogger.log('colored after reset');
        expect(colorHandler.last, contains('\x1b['));
      });

      test('configure after reset only changes specified fields', () {
        DynamicLogger.reset();
        DynamicLogger.configure(
            logHandler: handler.call, minLevel: LogLevel.ERROR);
        DynamicLogger.log('warn', level: LogLevel.WARNING);
        expect(handler.logs, isEmpty);
        DynamicLogger.log('err', level: LogLevel.ERROR);
        expect(handler.logs, hasLength(1));
      });
    });

    // -----------------------------------------------------------------------
    // Complex nested structure (integration)
    // -----------------------------------------------------------------------

    group('complex nested structure', () {
      test('logs complex nested data correctly', () {
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
            [],
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
            'emptyMapValue': {},
            'emptyListValue': [],
          },
        };

        DynamicLogger.log(complexData, tag: 'ComplexDataTest');

        expect(handler.logs, hasLength(1));
        final out = handler.last;

        expect(out, contains('ComplexDataTest'));
        expect(
            out,
            contains(
                '"stringKey": "A simple string with \\"quotes\\" and\\nnewlines."'));
        expect(out, contains('"integerKey": 12345'));
        expect(out, contains('"doubleKey": 3.14159'));
        expect(out, contains('"booleanKey": true'));
        expect(out, contains('"nullKey": null'));
        expect(out, contains('"List item 1"'));
        expect(out, contains('987'));
        expect(out, contains('"mapInListKey": "Value inside map in list"'));
        expect(out, contains('"anotherMapInListKey": 100'));
        expect(out, contains('"nullInMapInList": null'));
        expect(out, contains('"nestedString": "Nested string value"'));
        expect(out, contains('"nestedList":'));
        expect(out, contains('"deepMapInList": true'));
        expect(out, contains('"id": "a-1"'));
        expect(out, contains('"Another item in nested list"'));
        expect(out, contains('"deeplyNestedMap":'));
        expect(out, contains('"finalKey": "Reached the end!"'));
        expect(out, contains('"anotherBool": false'));
        expect(out, contains('"emptyMapValue": {}'));
        expect(out, contains('"emptyListValue": []'));
      });

      test('multiple concurrent log calls all complete', () {
        for (var i = 0; i < 10; i++) {
          DynamicLogger.log({'index': i, 'data': List.generate(5, (j) => j)});
        }
        expect(handler.logs, hasLength(10));
      });
    });
  });
}
