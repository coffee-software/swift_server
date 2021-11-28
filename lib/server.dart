library c7server;

import 'dart:io';
export 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

export 'builtin_actions.dart';

const PostArg = true;
const PathArg = true;

/**
 * Single HTTP API Endpoint
 */
@ComposeSubtypes
abstract class HttpAction {

  String? ext = null;

  @InjectClassName
  String get className;

  @Inject
  Server get server;

  //@Require
  late HttpRequest request;

  @Compile
  void setPostArgs(Map json);

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  void _setPostArgsStringRequired(Map json, String name, var field) {
    if (!json.containsKey(name)) {
      throw new HttpException(422, 'Missing required parameter ' + name);
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  void _setPostArgsStringOptional(Map json, String name, String? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  void _setPostArgsMap(Map json, String name, Map? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  void _setPostArgsList(Map json, String name, List? field) {
    field = (json.containsKey(name) ? new List.from(json[name]) : null);
  }

  Future handleRequest();
}

class Redirect implements Exception {
  String uri;
  Redirect(this.uri);
}

class Error404 implements Exception {
  Error404();
}

class HttpException implements Exception {
  int code;
  String message;
  HttpException(this.code, this.message);
}

@ComposeSubtypes
abstract class JsonAction extends HttpAction {

  String? ext = 'json';

  Future prapareData() async {}
  Future run();

  Future handleRequest() async
  {
    String body = await utf8.decoder.bind(request).join('');
    //String method = request.uri.pathSegments.length > 1 ? request.uri.pathSegments[1] : 'index';
    Map postArgs = {};
    if (body.length > 0) {
      var x = json.decode(body);
      if (x is Map){
        postArgs = x;
      }
    }
    setPostArgs(postArgs);

    String ret = json.encode(await this.run());

    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(ret);
  }
}

/**
 * Routing Node
 */
class RouteNode {
  String? className;
  Map<String, RouteNode> subNodes = {};

  String? find(List<String> path) {
    if (!path.isEmpty && subNodes.containsKey(path.first)) {
      return subNodes[path.removeAt(0)]!.find(path);
    }
    return className;
  }
  add(List<String> path, String className, {int depth = 0}) {
    if (path.length == depth) {
      this.className = className;
    } else {
      if (!subNodes.containsKey(path[depth])) {
        subNodes[path[depth]] = new RouteNode();
      }
      subNodes[path[depth]]!.add(path, className, depth:++depth);
    }
  }
}

/**
 * Routing Handler
 */
@Compose
abstract class Router {

  @SubtypeFactory
  HttpAction createAction(String className/*, HttpRequest request*/);

  //TODO:swift_composer only codes are required here
  @InjectInstances
  Map<String, HttpAction> get allActions;

  RouteNode? _root;
  RouteNode get root {
    if (_root == null) {
      _root = new RouteNode();
      allActions.keys.forEach((element) {
        String name = element;
        if (name.startsWith('module_')) {
          name = name.substring(6);
        }
        if (name.endsWith('Action')) {
          name = name.substring(0, name.length - 6);
        }
        var path = name.split('.').map((e) => e[0].toLowerCase() + e.substring(1)).toList();
        if (allActions[element]!.ext != null) {
          path.last = path.last + '.' + allActions[element]!.ext!;
        }
        _root!.add(
            path,
            element
        );
      });
    }
    return _root!;
  }

  String? mapPathToClassName(List<String> pathSegments) {
    return root.find(pathSegments);
  }

  HttpAction getForRequest(HttpRequest request) {
    List<String> pathArgs = new List<String>.from(request.uri.pathSegments);
    String? className = this.mapPathToClassName(pathArgs);
    if (className == null) {
      throw new Error404();
    }
    HttpAction action = createAction(className);
    action.request = request;
    return action;
  }

}

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

  T getRequired<T>(String code) {
    List<String> path = code.split('.');
    Map ret = data;
    for (int i=0; i < path.length - 1; i++) {
      ret = ret[path[i]];
    }
    return data[path.last];
  }
}

@Compose
abstract class ServerArgs {

  ArgResults? args;

  parse(List<String> arguments) {
    var parser = ArgParser();
    parser.addOption('config');
    this.args = parser.parse(arguments);
  }

  String get configPath {
    return this.args!['config'];
  }

}

/**
 * Server
 */
@Compose
abstract class Server {
  @Inject
  Router get routing;
  @Inject
  ServerConfig get config;
  @Inject
  ServerArgs get args;

  String get datadir => config.getRequired<String>('datadir');
  int get port => config.getRequired<int>('port');

  Future serve(List<String> arguments) async {
    args.parse(arguments);
    print("starting HTTP server...");
    await config.load(args.configPath);
    print('datadir: $datadir port: $port');
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print("listening on http://*:$port");
    server.listen(handleRequest);
  }

  Future handleRequest(HttpRequest request) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    try {

      await routing.getForRequest(request).handleRequest();

    } catch (error, stackTrace) {
      if (error is HttpException) {
        request.response.statusCode = error.code;
        request.response.headers.contentType = ContentType.html;
        request.response.write("<h1>${error.code} ERROR</h1>");
        request.response.write("<p>${error.message}</p>");
      } else if (error is Error404) {
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.html;
        request.response.write("<h1>404 ERROR</h1>");
      } else if (error is Redirect) {
        request.response.redirect(new Uri.http(request.uri.authority, error.uri));
      } else {
        request.response.statusCode = 500;
        request.response.headers.contentType = ContentType.html;
        request.response.write("<h1>500 ERROR</h1>");
        print(error.toString());
        print(stackTrace.toString());

        //request.response.write("<pre>${new HtmlEscape().convert()}</pre>");
        //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
      }
    }
    request.response.close();
    print("${request.method} ${request.uri} ${request.response.statusCode} [${new DateTime.now().millisecondsSinceEpoch - start}ms]");
  }

}