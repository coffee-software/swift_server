

import 'dart:convert';

import 'package:swift_composer/swift_composer.dart';
import 'package:redis/redis.dart';
import 'package:swift_server/config.dart';

@Compose
abstract class RedisCache {

  @Inject
  ServerConfig get config;

  Command? command;

  Future<Command> getClient() async {
    if (command == null) {
      final conn = RedisConnection();
      command = await conn.connect(
        config.getRequired<String>('redis.host'),
        config.getRequired<int>('redis.port'),
      );
    }
    return command!;
  }

  Future<dynamic> _exec(List args) async {
    return await (await getClient()).send_object(args);
  }

  Future<void> clearValue(String key) async {
    await _exec([ "DEL", key ]);
  }

  Future<void> setValue(String key, Map value) async {
    await _exec([ "SET", key, jsonEncode(value) ]);
  }

  Future<Map?> getValue(String key) async {
    String? ret = await _exec([ "GET", key ]);
    return ret == null ? ret : jsonDecode(ret);
  }
}