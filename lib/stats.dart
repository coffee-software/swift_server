
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:swift_server/tools.dart';

@Compose
abstract class Stats {

  @Inject
  Db get db;

  @Inject
  ServerConfig get config;

  int subId = 0;

  Future saveStats(int appId, String handler, int queries, int timeMs) async {
      int interval = 7 * 60;
      await db.query(
          'INSERT INTO run_stats SET '
              '`time` = FROM_UNIXTIME((UNIX_TIMESTAMP(NOW()) div ($interval)) * ($interval)), '
              '`app_id` = ?, '
              '`sub_id` = ?, '
              '`handler` = ?, '
              '`count` = 1, '
              '`max_queries` = ?, '
              '`avg_queries` = ?, '
              '`max_time` = ?, '
              '`avg_time` = ? '
              ' ON DUPLICATE KEY UPDATE '
              '`count` = `count` + 1, '
              '`max_queries` = GREATEST(`max_queries`, VALUES(`max_queries`)), '
              '`avg_queries` = (`avg_queries` * `count` + VALUES(`avg_queries`)) / (`count` + 1), '
              '`max_time` = GREATEST(`max_time`, VALUES(`max_time`)), '
              '`avg_time` = (`avg_time` * `count` + VALUES(`avg_time`)) / (`count` + 1) ',
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
