library swift_server;

import 'dart:convert';

import 'package:args/args.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';

import 'config.dart';
export 'config.dart';
import 'stats.dart';
export 'stats.dart';
import 'tools.dart';
export 'tools.dart';
export 'queue.dart';
import 'queue_processor.dart';
export 'queue_processor.dart';
import 'logger.dart';
export 'logger.dart';

export 'mailer.dart';
import 'server.dart';
export 'server.dart';


/**
 * Single Cron Job
 */
@ComposeSubtypes
abstract class Job implements BackendProcessorInterface {

  @Require
  late Daemon daemon;

  @InjectClassName
  String get className;

  Stats? stats;

  @Create
  late Db db;
  ServerConfig get serverConfig => daemon.config;
  Logger get logger => new Logger(db, serverConfig.getRequired<int>('service_id'), serverConfig.getRequired<bool>('debug'));

  Future run();

  int get minuteInterval => 5;

}

abstract class Ticker extends Job {

  int get minuteInterval => 1;

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

  @Create
  late Db db;

  @Inject
  DaemonArgs get args;

  @Inject
  ServerConfig get config;

  @SubtypeFactory
  Job createJob(String className, Daemon daemon);

  @Inject
  SubtypesOf<Job> get allJobs;

  @SubtypeFactory
  QueueProcessor createQueueProcessor(String className);

  @Inject
  SubtypesOf<QueueProcessor> get allQueueProcessors;

  Future runJob(String key) async {
    var job = createJob(key, this);
    int serviceId = config.getRequired<int>('service_id');
    job.stats = new Stats(config, serviceId, 'job', job.className);
    int start = new DateTime.now().millisecondsSinceEpoch;
    try {
      await job.run();
    } catch (error, stacktrace) {
      await job.logger.handleError('job.' + key, error, stacktrace);
    }
    await job.db.query(
        'INSERT INTO run_jobs SET app_id = ?, job = ? ON DUPLICATE KEY UPDATE run_count=run_count+1, last_run=NOW()',
        [
          serviceId,
          key
        ]
    );
    int timeMs = new DateTime.now().millisecondsSinceEpoch - start;
    await job.db.disconnect();
    job.stats?.saveStats(job.db.counter, timeMs);
  }

  Map<String, DateTime?> lastStarts = {};

  Future step() async {
    int serviceId = config.getRequired<int>('service_id');
    DateTime now = DateTime.now();
    for (var key in allJobs.allClassNames) {
      if (!lastStarts.containsKey(key)) {
        lastStarts[key] = await db.fetchOne<DateTime>(
            'SELECT last_run FROM run_jobs WHERE app_id = ? AND job =?',
            [serviceId, key]);
      }
      //TODO @Interval annotation
      if ((lastStarts[key] == null) || (now.difference(lastStarts[key]!).inMinutes >= createJob(key, this).minuteInterval)) {
        lastStarts[key] = now;
        await runJob(key);
      }
    }
    await db.disconnect();
  }

  void processJobsIsolate() async {
    print("start processing jobs(${allJobs.allClassNames.length}).");
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
    print("preparing queues(${allQueueProcessors.allClassNames.length}).");
    amqp.ConnectionSettings settings = amqp.ConnectionSettings(
        host: config.getRequired<String>('amqp.host'),
        port: config.getRequired<int>('amqp.port')
    );
    amqpClient = new amqp.Client(settings: settings);
    amqp.Channel channel = await amqpClient!.channel();
    //TODO: configurable concurrent processors
    channel = await channel.qos(0, 6);
    int serviceId = config.getRequired<int>('service_id');
    amqpConsumers = [];
    for (var processorName in allQueueProcessors.allClassNames) {
        var processor = createQueueProcessor(processorName);
        amqp.Queue amqpQueue = await channel.queue(processor.queue.queueName);
        amqp.Consumer consumer = await amqpQueue.consume(noAck: false);
        amqpConsumers.add(consumer);
        await consumer.listen((amqp.AmqpMessage message) async {
          var processor = createQueueProcessor(processorName);
          int start = new DateTime.now().millisecondsSinceEpoch;
          processor.stats = new Stats(config, serviceId, 'queue', processor.className);
          try {
            var decodedMessage = json.decode(message.payloadAsString);
            await processor.processMessage(decodedMessage);
          } catch (error, stacktrace) {
            await processor.logger.handleError(
                'queue.' + processor.queue.className,
                error,
                stacktrace,
                requestBody: message.payloadAsString
            );
          }
          await processor.db.query(
              'INSERT INTO run_queues SET app_id = ?, queue = ? ON DUPLICATE KEY UPDATE process_count=process_count+1, last_process=NOW()',
              [
                serviceId,
                processor.queue.className
              ]
          );
          int timeMs = new DateTime.now().millisecondsSinceEpoch - start;
          await processor.db.disconnect();
          processor.stats?.saveStats(processor.db.counter, timeMs);
          message.ack();
        });
    }
  }

  Future run(List<String> arguments) async {
    args.parse(arguments);
    await config.load(args.configPath);
    if (args.runSingleJob != null) {
      if (allJobs.allClassNames.contains(args.runSingleJob)) {
        await runJob(args.runSingleJob!);
        print('DONE');
      } else {
        print("unknown job ${args.runSingleJob}");
        print("available jobs ${allJobs.allClassNames}");
      }
    } else {
      print("starting daemon...");

      if (allQueueProcessors.allClassNames.isNotEmpty) {
        await processQueuesIsolate();
        //TODO separate isolates per queue?
        /*await Isolate.spawn(
          processQueuesIsolate,
          new DaemonIsolateArgs(receivePort.sendPort, this.config),
        );*/
      } else {
        print ('no queues');
      }
      if (allJobs.allClassNames.isNotEmpty) {
        processJobsIsolate();
      } else {
        print ('no jobs');
      }
    }
  }
}