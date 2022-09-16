library c7server;

import 'dart:convert';

import 'package:args/args.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';

import 'tools.dart';
export 'tools.dart';

import 'queues.dart';
export 'queues.dart';

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

@Compose
abstract class DaemonArgs {

  ArgResults? args;

  parse(List<String> arguments) {
    var parser = ArgParser();
    parser.addOption('config');
    parser.addOption('run');
    this.args = parser.parse(arguments);
  }

  String? get runSingleJob {
    return this.args?['run'];
  }

  String get configPath {
    return this.args!['config'];
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
  Net get net;

  @Inject
  DaemonArgs get args;

  @Inject
  ServerConfig get config;

  @InjectInstances
  Map<String, Job> get allJobs;

  @InjectInstances
  Map<String, Queue> get allQueues;

  Future runJob(String key) async {
    var job = allJobs[key]!;
    int serviceId = config.getRequired<int>('service_id');

    print('RUN JOB $key');
    try {
      await job.run();
    } catch (error, stackTrace) {
      print('JOB $key: $error');
    }
    await db.query(
        'INSERT INTO run_jobs SET app_id = ?, job = ? ON DUPLICATE KEY UPDATE run_count=run_count+1, last_run=NOW()',
        [
          serviceId,
          key
        ]
    );
  }

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
      //print('JOB $key ${now.difference(job.lastStart!).inMinutes}');

      if ((job.lastStart == null) || (now.difference(job.lastStart!).inMinutes >= job.minuteInterval)) {
        await runJob(key);
      }
    }
    await db.disconnect();

  }

  Future run(List<String> arguments) async {
    args.parse(arguments);
    await config.load(args.configPath);
    if (args.runSingleJob != null) {
      if (allJobs.containsKey(args.runSingleJob)) {
        var job = allJobs[args.runSingleJob]!;
        job.lastStart = await db.fetchOne('SELECT NOW()');
        await runJob(args.runSingleJob!);
        await db.disconnect();
        print('DONE');
      } else {
        print("unknown job ${args.runSingleJob}");
        print("available jobs ${allJobs.keys}");
      }
    } else {
      print("starting daemon...");
      if (allJobs.length > 1 && allQueues.isNotEmpty) {
        throw new Exception('TODO: daemon for jobs and queues');
      }
      if (allJobs.length > 1) {
        while (true) {
          step();
          await Future.delayed(Duration(milliseconds: 5000));
        }
      } else {
        amqp.ConnectionSettings settings = amqp.ConnectionSettings(
            host: config.getRequired<String>('amqp.host'),
            port: config.getRequired<int>('amqp.port')
        );
        print(allQueues.keys);
        for (var key in allQueues.keys) {
          var queue = allQueues[key]!;
          print('TODO isolates');
          amqp.Client client = new amqp.Client(settings: settings);
          amqp.Channel channel = await client.channel();
          amqp.Queue amqpQueue = await channel.queue(queue.className);
          amqp.Consumer consumer = await amqpQueue.consume();

          consumer.listen((amqp.AmqpMessage message) {
            queue.processMessage(json.decode(message.payloadAsString));
          });
        }
      }
    }
  }
}