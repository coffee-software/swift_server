import 'dart:convert';
import 'dart:io';

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:swift_server/tools.dart';

@Compose
abstract class ErrorHandler {

  @Inject
  ServerConfig get config;

  Future logError(Db db, String message, Map? debug) async {
    try {
      throw Exception(message);
    } on Exception catch (exception, stackTrace) {
      List<String> lines = stackTrace
          .toString()
          .split('\n');
      String? location = lines.length > 1 ? lines[1] : lines.first;
      await handleError(db, config.getRequired<int>('service_id'), 'manual', exception, stackTrace, location: location, requestBody: debug != null ? jsonEncode(debug): null);
    }
  }

  Future handleError(Db db, int appId, String handler, error, stacktrace, {HttpRequest? request, String? requestBody, String? location}) async {

    if (config.getRequired<bool>('debug')) {
      print('###############################################################');
      print('###############         Unhandled Error         ###############');
      print(error.toString());
      print('###############           Stack Trace           ###############');
      print(stacktrace.toString());
      print('###############           Catch Trace           ###############');
      try {
        throw new Exception("handle trace");
      } catch (e, stack2) {
        print(stack2.toString());
      }
      print('###############################################################');
    }

    String debugRequest = '';
    if (request != null) {
      debugRequest += """${request.method} ${request.requestedUri}\n${request.headers.toString()}\n""";
    }
    if (requestBody != null) {
      debugRequest += requestBody;
    }
    String saveLocation = location != null ? location : stacktrace
        .toString()
        .split('\n')
        .first;

    await db.query(
        'INSERT INTO run_errors SET '
            '`app_id` = ?, '
            '`handler` = ?, '
            '`location` = ?, '
            '`status` = "new", '
            '`first_time` = NOW(), '
            '`first_message` = ?, '
            '`first_stack` = ?, '
            '`first_request` = ? '
            ' ON DUPLICATE KEY UPDATE '
            '`status` = VALUES(`status`), '
            '`current_count` = `current_count` + 1, '
            '`total_count` = `total_count` + 1, '
            '`last_time` = VALUES(`first_time`), '
            '`last_message` = VALUES(`first_message`), '
            '`last_stack` = VALUES(`first_stack`), '
            '`last_request` = VALUES(`first_request`)',
        [
          appId,
          handler,
          saveLocation,
          error.toString(),
          stacktrace.toString(),
          debugRequest
        ]
    );
  }
}
