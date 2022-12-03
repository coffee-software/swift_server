
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:swift_server/tools.dart';

@Compose
abstract class Stats {

  int subId = 0;

  Future saveStats(Db db, int appId, String handler, int queries, int timeMs) async {
      int interval = 7 * 60;
      await db.query(
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
            subId,
            handler,
            queries,
            queries,
            timeMs,
            timeMs
          ]
      );
  }
}
