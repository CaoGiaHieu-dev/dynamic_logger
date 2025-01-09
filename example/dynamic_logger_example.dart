import 'package:dynamic_logger/dynamic_logger.dart';

void main() async {
  // Log a simple message
  await Future.delayed(Duration(milliseconds: 500));
  DynamicLogger.log('This is an info message');
  await Future.delayed(Duration(milliseconds: 500));
  // Log a message with a specific log level
  DynamicLogger.log('This is a warning message', level: LogLevel.WARNING);
  await Future.delayed(Duration(milliseconds: 500));
  // Log a message with a tag
  DynamicLogger.log('This is an error message',
      tag: 'MyTag', level: LogLevel.ERROR);
  await Future.delayed(Duration(milliseconds: 500));
  // Log a complex data structure like a Map
  DynamicLogger.log({'key': 'value', 'anotherKey': 'anotherValue'});
  await Future.delayed(Duration(milliseconds: 500));
  // Log a Dio RequestOptions object (example)
  // final requestOptions = RequestOptions(path: 'https://example.com');
  // print('Logging Dio RequestOptions');
  // DynamicLogger.log(requestOptions);
}
