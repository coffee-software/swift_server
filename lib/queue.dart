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

  amqp.Client getClient() {
    amqp.ConnectionSettings settings = amqp.ConnectionSettings(host: config.getRequired<String>('amqp.host'), port: config.getRequired<int>('amqp.port'));
    return amqp.Client(settings: settings);
  }

  Future postMessages(Iterable<T> messages) async {
    var client = getClient();
    amqp.Queue queue = await (await client.channel()).queue(queueName);
    for (var m in messages) {
      queue.publish(jsonEncode(m));
    }
    await client.close();
  }

  Future postMessage(T message) async {
    var client = getClient();
    amqp.Queue queue = await (await client.channel()).queue(queueName);
    queue.publish(jsonEncode(message));
    await client.close();
  }
}
