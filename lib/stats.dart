
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:swift_server/tools.dart';


abstract class StatsAction {
  Db get db;
  int get statsSubId;
  String get className;
}

@Compose
abstract class Stats {

  Future saveStats(int appId, String prefix, StatsAction action, int timeMs) async {
      int interval = 7 * 60;
      await action.db.query(
          'INSERT INTO run_stats SET '
              '`time` = FROM_UNIXTIME((UNIX_TIMESTAMP(NOW()) div ($interval)) * ($interval)), '
              '`app_id` = ?, '
              '`sub_id` = ?, '
              '`handler` = ?, '
              '`count` = 1, '
              '`max_queries` = ?, '
              '`total_queries` = ?, '
              '`max_time` = ?, '
              '`total_time` = ? '
              ' ON DUPLICATE KEY UPDATE '
              '`count` = `count` + 1, '
              '`max_queries` = GREATEST(`max_queries`, VALUES(`max_queries`)), '
              '`total_queries` = `total_queries` + VALUES(`total_queries`), '
              '`max_time` = GREATEST(`max_time`, VALUES(`max_time`)), '
              '`total_time` = `total_time` + VALUES(`total_time`) ',
          [
            appId,
            action.statsSubId,
            prefix + '.' + action.className,
            action.db.counter,
            action.db.counter,
            timeMs,
            timeMs
          ]
      );
      action.db.counter = 0;
  }
}
