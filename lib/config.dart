library c7server;

import 'dart:io';
import 'package:swift_composer/swift_composer.dart';
import 'package:yaml/yaml.dart';

/**
 * Server Configuration Reader
 */
@Compose
class ServerConfig {

  @Create
  late Map data;

  load(String path) async {
    data = loadYaml(await new File(path).readAsString());
  }

  T _get<T>(String code, bool required, T? defaultValue) {
    List<String> path = code.split('.');
    Map ret = data;
    for (int i=0; i < path.length - 1; i++) {
      if (!ret.containsKey(path[i])) {
        if (required) {
          throw new Exception('missing required config value: ${path[i]}');
        } else {
          return defaultValue!;
        }
      }
      ret = ret[path[i]];
    }
    if (!ret.containsKey(path.last)) {
      if (required) {
        throw new Exception('missing required config value: ${path.last}');
      } else {
        return defaultValue!;
      }
    }
    return ret[path.last];

  }

  T getRequired<T>(String code) {
    return _get<T>(code, true, null);
  }

  T getOptional<T>(String code, T defaultValue) {
    return _get<T>(code, false, defaultValue);
  }
}

