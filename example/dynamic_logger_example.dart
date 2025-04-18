import 'dart:async';
import 'dart:convert'; // Required for jsonDecode
import 'package:dynamic_logger/dynamic_logger.dart';
// import 'package:dio/dio.dart'; // Uncomment if you want to log RequestOptions

void main() async {
  // --- Basic Examples ---
  print('\n--- Basic Logging Examples ---');
  await Future.delayed(const Duration(milliseconds: 500));
  DynamicLogger.log('This is an info message');

  await Future.delayed(const Duration(milliseconds: 500));
  DynamicLogger.log('This is a warning message', level: LogLevel.WARNING);

  await Future.delayed(const Duration(milliseconds: 500));
  DynamicLogger.log('This is an error message',
      tag: 'MyTag', level: LogLevel.ERROR);

  // --- Complex Nested Data ---
  print('\n--- Complex Nested Data Example ---');
  await Future.delayed(const Duration(milliseconds: 500));
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
  DynamicLogger.log(complexData, tag: 'ComplexData');

  // --- Large JSON Example ---
  print('\n--- Large JSON Example (Simulated) ---');
  await Future.delayed(const Duration(milliseconds: 500));

  // Simulate a large JSON structure (e.g., from an API response)
  // In a real app, you might get this from an HTTP response or file.
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
      {"id": 5, "name": "Eve", "email": "eve@example.com", "isActive": false, "tags": ["guest"], "profile": {"age": 22, "city": "Phoenix"}},
      {"id": 6, "name": "Frank", "email": "frank@example.com", "isActive": true, "tags": ["admin", "dev", "lead"], "profile": {"age": 40, "city": "Philadelphia"}},
      {"id": 7, "name": "Grace", "email": "grace@example.com", "isActive": true, "tags": ["user"], "profile": {"age": 31, "city": "San Antonio"}},
      {"id": 8, "name": "Heidi", "email": "heidi@example.com", "isActive": false, "tags": [], "profile": {"age": 29, "city": "San Diego"}},
      {"id": 9, "name": "Ivan", "email": "ivan@example.com", "isActive": true, "tags": ["dev", "tester"], "profile": {"age": 33, "city": "Dallas"}},
      {"id": 10, "name": "Judy", "email": "judy@example.com", "isActive": true, "tags": ["user"], "profile": {"age": 27, "city": "San Jose"}}
    ],
    "settings": {
      "theme": "dark",
      "notifications": {"email": true, "sms": false, "push": true},
      "featureFlags": {
        "newDashboard": true,
        "betaFeatureX": false,
        "analyticsV2": true
      },
      "preferences": [
        {"key": "lang", "value": "en-US"},
        {"key": "timezone", "value": "America/New_York"},
        {"key": "itemsPerPage", "value": 50}
      ]
    }
  }
  ''';
  final largeJsonData = jsonDecode(largeJsonString);

  print("Logging large JSON (no truncation yet)...");
  DynamicLogger.log(largeJsonData, tag: 'LargeJSON-Full');

  // --- Truncation Examples ---
  print('\n--- Truncation Examples ---');
  await Future.delayed(const Duration(milliseconds: 500));

  print("Configuring default truncation (depth 3, 5 entries)...");
  DynamicLogger.configure(
    truncate: true,
    maxDepth: 3,
    maxCollectionEntries: 5,
  );

  await Future.delayed(const Duration(milliseconds: 500));
  print("Logging large JSON (with default truncation)...");
  DynamicLogger.log(largeJsonData, tag: 'LargeJSON-DefaultTrunc');

  await Future.delayed(const Duration(milliseconds: 500));
  print("Logging large JSON (overriding truncation: depth 2, 3 entries)...");
  DynamicLogger.log(
    largeJsonData,
    tag: 'LargeJSON-OverrideTrunc',
    // No need to set truncate: true if default is true, but explicit here
    truncate: true,
    maxDepth: 100,
    maxCollectionEntries: 100,
  );

  await Future.delayed(const Duration(milliseconds: 500));
  print("Logging large JSON (disabling truncation for this call)...");
  DynamicLogger.log(
    largeJsonData,
    tag: 'LargeJSON-NoTruncCall',
    truncate: false, // Override default and disable truncation
  );

  // --- Reset Configuration (Optional) ---
  // DynamicLogger.configure(truncate: false, maxDepth: 10, maxCollectionEntries: 100);

  // --- Dio RequestOptions Example (Uncomment to use) ---
  // print('\n--- Dio RequestOptions Example ---');
  // await Future.delayed(const Duration(milliseconds: 500));
  // final requestOptions = RequestOptions(
  //   path: 'https://example.com/users',
  //   method: 'POST',
  //   headers: {'Authorization': 'Bearer xyz', 'X-API-Key': '12345'},
  //   queryParameters: {'page': 1, 'limit': 10},
  //   data: {'name': 'New User', 'role': 'editor'},
  // );
  // DynamicLogger.log(requestOptions, tag: 'DioRequest');

  print('\n--- Examples Complete ---');
}
