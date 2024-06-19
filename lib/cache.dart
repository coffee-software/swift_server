

import 'dart:convert';

import 'package:swift_composer/swift_composer.dart';
import 'package:redis/redis.dart';
import 'package:swift_server/config.dart';

@Compose
abstract class RedisCache {

  @Inject
  ServerConfig get config;

  Command? command;
  String? _prefix;
  String get prefix => _prefix ?? (_prefix = config.getOptional<String>('redis.prefix', ''));

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
    await _exec([ "DEL", prefix + key ]);
  }

  /**
   * expireIn in seconds
   */
  Future<void> setValue(String key, Map value, {int expireIn=-1}) async {
    var args = [ "SET", prefix + key, jsonEncode(value) ];
    if (expireIn != -1) {
      args.add('EX');
      args.add(expireIn.toString());
    }
    await _exec(args);
  }

  Future<Map?> getValue(String key) async {
    String? ret = await _exec([ "GET", prefix + key ]);
    return ret == null ? ret : jsonDecode(ret);
  }

  Future<void> setString(String key, String value, {int expireIn=-1}) async {
    var args = [ "SET", prefix + key, value ];
    if (expireIn != -1) {
      args.add('EX');
      args.add(expireIn.toString());
    }
    await _exec(args);
  }

  Future<String?> getString(String key) async {
    String? ret = await _exec([ "GET", prefix + key ]);
    return ret;
  }

}