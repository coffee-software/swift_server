import 'dart:convert';

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:swift_server/tools.dart';

@Compose
abstract class ErrorHandler {

  @Inject
  Db get db;

  @Inject
  ServerConfig get config;

  Future handleError(int appId, String handler, error, stacktrace) async {

    if (config.getRequired<bool>('debug')) {
      print('###############################################################');
      print('###############         Unhandled Error         ###############');
      print(error.toString());
      print('###############           Stack Trace           ###############');
      print(stacktrace.toString());
      print('###############################################################');
    }
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
          stacktrace
              .toString()
              .split('\n')
              .first,
          error.toString(),
          stacktrace.toString(),
          jsonEncode('todo: request')
        ]
    );
  }
}
