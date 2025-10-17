import 'dart:convert'; // Required for jsonDecode
import 'package:dynamic_logger/dynamic_logger.dart';

Future<void> main() async {
  // Configure logger to print to console for visibility
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
    // No need to set truncate: true if default is true, but explicit here
    truncate: true,
    maxDepth: 100,
    maxCollectionEntries: 100,
  );

  DynamicLogger.log(
    largeJsonData,
    tag: 'LargeJSON-NoTruncCall',
    truncate: false, // Override default and disable truncation
  );

  // --- Reset Configuration (Optional) ---
  // DynamicLogger.configure(truncate: false, maxDepth: 10, maxCollectionEntries: 100);

  // --- Dio RequestOptions Example (Uncomment to use) ---
  //
  //
  // final requestOptions = RequestOptions(
  //   path: 'https://example.com/users',
  //   method: 'POST',
  //   headers: {'Authorization': 'Bearer xyz', 'X-API-Key': '12345'},
  //   queryParameters: {'page': 1, 'limit': 10},
  //   data: {'name': 'New User', 'role': 'editor'},
  // );
  //  DynamicLogger.log(requestOptions, tag: 'DioRequest');

  // Ensure all log has been recorded
  await Future.delayed(Duration(microseconds: 1000));
}
