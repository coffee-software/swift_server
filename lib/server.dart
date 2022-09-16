library c7server;

import 'dart:io';
export 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/http_status_codes.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:args/args.dart';

import 'config.dart';
export 'config.dart';
import 'tools.dart';
export 'tools.dart';
export 'builtin_actions.dart';

export 'queues.dart';

const PostArg = true;
const GetArg = true;
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
  void _setPostArgsStringRequired(Map json, String name, String field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
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
  void _setPostArgsListRequired(Map json, String name, List field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = new List.from(json[name]!);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  void _setPostArgsListOptional(Map json, String name, List? field) {
    field = (json.containsKey(name) ? new List.from(json[name]) : null);
  }

  @Compile

  void setGetArgs(Map<String, String> queryParameters);

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  void _setGetArgsStringRequired(Map<String, String> queryParameters, String name, String field) {
    if (!queryParameters.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = queryParameters[name]!;
  }

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  void _setGetArgsIntRequired(Map<String, String> queryParameters, String name, int field) {
    if (!queryParameters.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = int.parse(queryParameters[name]!);
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

class HttpRequestException extends HttpException {
  HttpRequestException(String message) : super(HttpStatus.unprocessableEntity, message);
}

@ComposeSubtypes
abstract class JsonAction extends HttpAction {

  String? ext = 'json';
  int responseStatus = HttpStatus.ok;

  Future prapareData() async {}
  Future run();

  Future prepareArguments() async {
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
    setGetArgs(request.uri.queryParameters);
  }

  Future handleRequest() async {
    await prepareArguments();
    responseStatus = HttpStatus.ok;
    String ret = json.encode(await this.run());

    request.response.statusCode = responseStatus;
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
abstract class Router implements Pluggable {

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
          name = name.substring(7);
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
        print('STACK');
        print(stackTrace.toString());
        //TODO if developer mode:
        //request.response.write("<pre>${new HtmlEscape().convert()}</pre>");
        //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
      }
    }
    request.response.close();
    db.disconnect();
    print("${request.method} ${request.uri} ${request.response.statusCode} [${new DateTime.now().millisecondsSinceEpoch - start}ms]");
  }

}