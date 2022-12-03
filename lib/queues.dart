import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'dart:convert';

import 'package:swift_server/tools.dart';

@ComposeSubtypes
abstract class Queue<T> {

  @InjectClassName
  String get className;

  @Inject
  ServerConfig get config;

  String get queueName => className + '.' + config.getRequired<int>('service_id').toString();

  Future postMessage(T message) async {
    amqp.ConnectionSettings settings = amqp.ConnectionSettings(
        host: config.getRequired<String>('amqp.host'),
        port: config.getRequired<int>('amqp.port')
    );
    amqp.Client client = amqp.Client(settings: settings);
    amqp.Channel channel = await client.channel();
    amqp.Queue queue = await channel.queue(queueName);
    queue.publish(jsonEncode(message));
    await client.close();
  }
}



@ComposeSubtypes
abstract class QueueProcessor<Q extends Queue, T> {

  @Create
  late Db db;

  @Inject
  ServerConfig get config;

  @Inject
  Q get queue;

  Future processMessage(T message);
}
