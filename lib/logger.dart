import 'dart:convert';

import 'tools.dart';
import 'dart:io';

class Logger {
  Db db;
  int serviceId;
  bool debug;

  Logger(this.db, this.serviceId, this.debug);

  Future<void> error(String type, String message, {int? entityId = null, exception = null, StackTrace? stackTrace = null, Map? debugData = null}) async {
    await _logError(message, exception: exception, stackTrace: stackTrace, debug: debugData);
    await _addLogRow(type, 'error', message, entityId);
  }

  Future<void> log(String type, String message, {int? entityId = null}) async {
    await _addLogRow(type, 'info', message, entityId);
  }

  Future<void> _addLogRow(String type, String level, String message, int? entityId) async {
    await db.query('INSERT INTO `run_logs` SET `type` = ?, `level` = ?, `entity_id` = ?, `message` = ?', [type, level, entityId, message]);
  }

  Future _logError(String message, {exception, StackTrace? stackTrace, Map? debug}) async {
    if (exception == null || stackTrace == null) {
      try {
        exception = Exception(message);
        throw exception;
      } on Exception catch (e, trace) {
        List<String> lines = trace.toString().split('\n');
        //remove first line
        lines.removeAt(0);
        stackTrace = StackTrace.fromString(lines.join('\n'));
      }
    }
    await handleError('manual', exception!, stackTrace, requestBody: debug != null ? jsonEncode(debug) : null);
  }

  Future handleError(String handler, exception, StackTrace stacktrace, {HttpRequest? request, String? requestBody}) async {
    if (debug) {
      print('###############################################################');
      print('###############         Unhandled Error         ###############');
      print(exception.toString());
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
    String location = stacktrace.toString().split('\n').first;

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
      [serviceId, handler, location, exception.toString(), stacktrace.toString(), debugRequest],
    );
  }
}
