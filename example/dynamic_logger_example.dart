import 'dart:convert';
import 'package:dynamic_logger/dynamic_logger.dart';

void main() {
  // Configure logger to print to console for visibility.
  // By default, DynamicLogger uses dart:developer.log which may not appear
  // in terminal output.
  DynamicLogger.configure(
    logHandler: (message,
        {error, level = 0, name = '', stackTrace, time, zone, sequenceNumber}) {
      print(message);
    },
  );

  // --- Basic Examples ---

  DynamicLogger.log('This is an info message');

  DynamicLogger.log('This is a warning message', level: LogLevel.WARNING);

  DynamicLogger.log('This is an error message',
      tag: 'MyTag', level: LogLevel.ERROR);

  // --- Complex Nested Data ---

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
  DynamicLogger.log(complexData, tag: 'ComplexData');

  // --- Large JSON Example ---

  final largeJsonString = '''
  {
    "metadata": {
      "timestamp": "2023-10-27T10:00:00Z",
      "source": "Example API",
      "version": "1.2.0"
    },
    "users": [
      {"id": 1, "name": "Alice", "email": "alice@example.com", "isActive": true, "tags": ["admin", "dev"], "profile": {"age": 30, "city": "New York"}},
      {"id": 2, "name": "Bob", "email": "bob@example.com", "isActive": false, "tags": ["user"], "profile": {"age": 25, "city": "Los Angeles"}},
      {"id": 3, "name": "Charlie", "email": "charlie@example.com", "isActive": true, "tags": ["user", "tester"], "profile": {"age": 35, "city": "Chicago"}},
      {"id": 4, "name": "David", "email": "david@example.com", "isActive": true, "tags": ["dev"], "profile": {"age": 28, "city": "Houston"}},
      {"id": 5, "name": "Eve", "email": "eve@example.com", "isActive": false, "tags": ["guest"], "profile": {"age": 22, "city": "Phoenix"}}
    ],
    "settings": {
      "theme": "dark",
      "notifications": {"email": true, "sms": false, "push": true},
      "featureFlags": {
        "newDashboard": true,
        "betaFeatureX": false
      }
    }
  }
  ''';
  final largeJsonData = jsonDecode(largeJsonString);

  DynamicLogger.log(largeJsonData, tag: 'LargeJSON-Full');

  // --- Truncation Examples ---

  DynamicLogger.configure(
    truncate: true,
    maxDepth: 3,
    maxCollectionEntries: 5,
  );

  DynamicLogger.log(largeJsonData, tag: 'LargeJSON-DefaultTrunc');

  DynamicLogger.log(
    largeJsonData,
    tag: 'LargeJSON-OverrideTrunc',
    truncate: true,
    maxDepth: 100,
    maxCollectionEntries: 100,
  );

  DynamicLogger.log(
    largeJsonData,
    tag: 'LargeJSON-NoTruncCall',
    truncate: false,
  );

  // --- minLevel Example ---

  // Only WARNING and ERROR will be emitted; INFO is silently dropped.
  DynamicLogger.configure(minLevel: LogLevel.WARNING);
  DynamicLogger.log('This INFO is dropped');
  DynamicLogger.log('This WARNING appears', level: LogLevel.WARNING);

  // --- maxStringLength Example ---

  DynamicLogger.configure(
    minLevel: LogLevel.INFO,
    truncate: true,
    maxStringLength: 30,
  );
  DynamicLogger.log(
    'This is a very long string that will be truncated by the logger.',
    tag: 'StringTrunc',
  );

  // --- Disable colors (useful for plain-file output) ---

  DynamicLogger.configure(colorEnabled: false);
  DynamicLogger.log('No ANSI color codes here', tag: 'PlainText');

  // --- Reset to defaults ---

  DynamicLogger.reset();
}
