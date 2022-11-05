import 'dart:convert';

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/tools.dart';

@Compose
abstract class ErrorHandler {

  @Inject
  Db get db;

  Future handleError(int appId, String source, error, stacktrace) async {

    /*if (config.getRequired<bool>('debug')) {
      //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
      print(error.toString());
      print('STACK');
      print(stacktrace.toString());
    }*/
    await db.query(
        'INSERT INTO run_errors SET '
            '`app_id` = ?, '
            '`process` = ?, '
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
          source,
          stacktrace.toString().split('\n').first,
          error.toString(),
          stacktrace.toString(),
          jsonEncode('todo: request')
        ]
    );
  }
}
