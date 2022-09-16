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

  @Inject
  Db get db;

  Future postMessage(T message) async {
    amqp.ConnectionSettings settings = amqp.ConnectionSettings(
        host: config.getRequired<String>('amqp.host'),
        port: config.getRequired<int>('amqp.port')
    );
    amqp.Client client = amqp.Client(settings: settings);
    amqp.Channel channel = await client.channel();
    amqp.Queue queue = await channel.queue(className);
    queue.publish(json.encode(message));
    client.close();
  }

  Future processMessage(T message);
}