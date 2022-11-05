library c7server;

import 'dart:convert';

import 'package:args/args.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';
import 'package:swift_server/error_handler.dart';
export 'package:swift_server/error_handler.dart';

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

  @Inject
  ErrorHandler get errorHandler;

  @InjectInstances
  Map<String, Job> get allJobs;

  @InjectInstances
  Map<String, QueueProcessor> get allQueueProcessors;

  Future runJob(String key) async {
    var job = allJobs[key]!;
    int serviceId = config.getRequired<int>('service_id');

    print('RUN JOB $key');
    try {
      await job.run();
    } catch (error, stacktrace) {
      await errorHandler.handleError(serviceId, 'job.' + key, error, stacktrace);
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
      if ((job.lastStart == null) || (now.difference(job.lastStart!).inMinutes >= job.minuteInterval)) {
        await runJob(key);
      }
    }
    await db.disconnect();

  }

  void processJobsIsolate() async {
    print("start processing jobs(${allJobs.length}).");
    while (true) {
      step();
      await Future.delayed(Duration(milliseconds: 5000));
    }
  }

  amqp.Client? amqpClient = null;
  List<amqp.Consumer> amqpConsumers = [];

  Future finishQueuesIsolate() async {
    if (amqpClient != null) {
      for (var consumer in amqpConsumers) {
        await consumer.cancel();
      };
      await amqpClient!.close();
    }
  }

  Future processQueuesIsolate() async {
    print("preparing queues(${allQueueProcessors.length}).");
    amqp.ConnectionSettings settings = amqp.ConnectionSettings(
        host: config.getRequired<String>('amqp.host'),
        port: config.getRequired<int>('amqp.port')
    );
    amqpClient = new amqp.Client(settings: settings);
    amqp.Channel channel = await amqpClient!.channel();
    int serviceId = config.getRequired<int>('service_id');
    for (var processor in allQueueProcessors.values) {
        amqp.Queue amqpQueue = await channel.queue(processor.queue.queueName);
        amqp.Consumer consumer = await amqpQueue.consume();
        amqpConsumers.add(consumer);
        await consumer.listen((amqp.AmqpMessage message) async {
          try {
            var decodedMessage = json.decode(message.payloadAsString);
            await processor.processMessage(decodedMessage);
          } catch (error, stacktrace) {
            await errorHandler.handleError(serviceId, 'queue.' + processor.queue.className, error, stacktrace);
          }
          await db.query(
              'INSERT INTO run_queues SET app_id = ?, queue = ? ON DUPLICATE KEY UPDATE process_count=process_count+1, last_process=NOW()',
              [
                serviceId,
                processor.queue.className
              ]
          );
        });
    }
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

      if (allQueueProcessors.isNotEmpty) {
        await processQueuesIsolate();
        //TODO separate isolates per queue?
        /*await Isolate.spawn(
          processQueuesIsolate,
          new DaemonIsolateArgs(receivePort.sendPort, this.config),
        );*/
      }

      if (allJobs.isNotEmpty) {
        processJobsIsolate();
      }
    }
  }
}