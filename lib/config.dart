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

  Map mergeMaps(Map target, Map source) {
    Map ret = Map.from(target);
    source.forEach((key, value) {
      if ((value is Map) && (target.containsKey(key)) && (target[key] is Map)) {
        ret[key] = mergeMaps(target[key] as Map, value);
      } else {
        ret[key] = value;
      }
    });
    return ret;
  }

  load(String path) async {
    var configFile = new File(path);
    var overrideFile = new File(path.replaceFirst('.yaml', '.override.yaml'));
    data = loadYaml(await configFile.readAsString());
    if (overrideFile.existsSync()) {
      var overrideData = loadYaml(await overrideFile.readAsString());
      data = mergeMaps(data, overrideData);
    }
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
        return defaultValue as T;
      }
    }
    var value = ret[path.last];
    if (value is YamlList) {
      value = value.toList();
    }
    return value;
  }

  T getRequired<T>(String code) {
    return _get<T>(code, true, null);
  }

  T getOptional<T>(String code, T defaultValue) {
    return _get<T>(code, false, defaultValue);
  }
}

