import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:swift_server/daemon.dart';
import 'dart:convert';

@ComposeSubtypes
abstract class Queue<T> {

  @InjectClassName
  String get className;

  @Inject
  ServerConfig get config;

  String get queueName => config.getRequired<String>('amqp.prefix') + className;

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
