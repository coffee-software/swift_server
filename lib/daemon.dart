library c7server;

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/server.dart';
export 'package:swift_server/server.dart';

/**
 * Single Cron Job
 */
@ComposeSubtypes
abstract class Job {

  @InjectClassName
  String get className;

  @Inject
  Daemon get daemon;

  DateTime? lastStart;

  Future run();

  int minuteInterval = 5;

}

abstract class Ticker extends Job {

  int minuteInterval = 1;

  Future run() async {
    //this job does nothing. it is used to check if daemon is running properly
  }
}


/**
 * Daemon process handler
 */
@Compose
abstract class Daemon {
  @Inject
  Db get db;

  @Inject
  ServerArgs get args;

  @Inject
  ServerConfig get config;

  @InjectInstances
  Map<String, Job> get allJobs;

  Future step() async {
    int serviceId = config.getRequired<int>('service_id');
    DateTime now = await db.fetchOne('SELECT NOW()');
    for (var key in allJobs.keys) {
      var job = allJobs[key]!;

      if (job.lastStart == null) {
        job.lastStart = await db.fetchOne(
            'SELECT last_run FROM run_jobs WHERE app_id = ? AND job =?',
            [serviceId, key]);
      }

      if (job.lastStart == null || now.difference(job.lastStart!).inMinutes >= job.minuteInterval) {
        print('RUN JOB $key');
        job.lastStart = now;
        await job.run();
        await db.query(
            'INSERT INTO run_jobs SET app_id = ?, job = ? ON DUPLICATE KEY UPDATE run_count=run_count+1, last_run=?',
            [
              serviceId,
              key,
              job.lastStart
            ]
        );
      }
    }
    await db.disconnect();

  }

  Future run(List<String> arguments) async {

    args.parse(arguments);
    print("starting daemon...");
    await config.load(args.configPath);
    while(true) {
      step();
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
}