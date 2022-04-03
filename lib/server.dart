library c7server;

import 'dart:collection';
import 'dart:io';
export 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mysql1/mysql1.dart';
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/http_status_codes.dart';
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
      throw new HttpException(HttpStatus.notFound, request.uri.toString());
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
      if (!ret.containsKey(path[i])) {
        throw new Exception('missing required config value: ${path[i]}');
      }
      ret = ret[path[i]];
    }
    if (!ret.containsKey(path.last)) {
      throw new Exception('missing required config value: ${path.last}');
    }
    return ret[path.last];
  }
}

@Compose
abstract class ServerArgs {

  ArgResults? args;

  parse(List<String> arguments) {
    var parser = ArgParser();
    parser.addOption('config');
    parser.addOption('port');
    this.args = parser.parse(arguments);
    var argsPort = this.args!['port'];
    if (argsPort != null) {
      if (int.tryParse(argsPort) == null || int.parse(argsPort) < 1) {
        throw new Exception('--port value must be a positive integer.');
      }
      port = int.tryParse(argsPort);
    }
  }

  int? port;

  String get configPath {
    return this.args!['config'];
  }

}

@Compose
abstract class Db {

  @Inject
  ServerConfig get config;

  MySqlConnection? connection;

  Future<MySqlConnection> getConnection() async {
    if (connection == null) {
      connection = await MySqlConnection.connect(
          ConnectionSettings(
              host: config.getRequired<String>('database.host'),
              port: config.getRequired<int>('database.port'),
              user: config.getRequired<String>('database.user'),
              db: config.getRequired<String>('database.database'),
              password: config.getRequired<String>('database.password')
          )
      );
    }
    //temporary fix for new mysql version
    await Future.delayed(Duration(milliseconds: 1000));
    return connection!;
  }

  Future<void> disconnect() async {
    if (connection != null) {
      await connection!.close();
    }
  }

  Future<IterableBase<ResultRow>> fetchRows(String sql, [List<Object?>? values]) async {
    return await (await this.getConnection()).query(sql, values);
  }

  Future<ResultRow?> fetchRow(String sql, [List<Object?>? values]) async {
    for (var row in await (await this.getConnection()).query(sql, values)) {
      return row;
    }
    return null;
  }

  dynamic fetchOne(String sql, [List<Object?>? values]) async {
    for (var row in await (await this.getConnection()).query(sql, values)) {
      return row[0];
    }
    return null;
  }

  Future<void> query(String sql, [List<Object?>? values]) async {
    await (await this.getConnection()).query(sql, values);
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
  @Inject
  Db get db;

  String get datadir => config.getRequired<String>('datadir');
  int get port => args.port ?? config.getRequired<int>('port');


  Future serve(List<String> arguments) async {
    args.parse(arguments);
    print("starting HTTP server...");
    await config.load(args.configPath);
    print('datadir: $datadir port: $port');
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print("listening on http://*:$port");
    server.listen(handleRequest);
  }

  void writeError(HttpRequest request, int code, String message) {
    //TODO depend on request accepted header
    request.response.statusCode = code;
    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode({
      'error':  "${code} ${httpStatusMessage[code]!}",
      'message': message
    }));
  }

  Future handleRequest(HttpRequest request) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    try {

      await routing.getForRequest(request).handleRequest();

    } catch (error, stackTrace) {
      if (error is HttpException) {
        writeError(request, error.code, error.message);
      } else if (error is Redirect) {
        request.response.redirect(new Uri.http(request.uri.authority, error.uri));
      } else {
        writeError(request, HttpStatus.internalServerError, 'unknown error occured');
        print(error.toString());
        print(stackTrace.toString());
        //TODO if developer mode:
        //request.response.write("<pre>${new HtmlEscape().convert()}</pre>");
        //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
      }
    }
    request.response.close();
    print("${request.method} ${request.uri} ${request.response.statusCode} [${new DateTime.now().millisecondsSinceEpoch - start}ms]");
  }

}