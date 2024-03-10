library swift_server;

import 'dart:io';
export 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'http_status_codes.dart';
import 'package:args/args.dart';

import 'error_handler.dart';
export 'error_handler.dart';
import 'stats.dart';
export 'stats.dart';

import 'server.dart';
export 'server.dart';

export 'builtin_actions.dart';
export 'mailer.dart';

export 'queue.dart';

const PostArg = true;
const GetArg = true;
const PathArg = true;

/**
 * Single HTTP API Endpoint
 */
@ComposeSubtypes
abstract class HttpAction implements StatsAction {

  @InjectClassName
  String get className;

  int statsSubId = 0;

  @Inject
  Server get server;

  @Create
  late Db db;

  @Require
  late HttpRequest request;

  @Require
  late List<String> pathArgs;

  @Compile
  void setPostArgs(Map json);

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsStringRequired(Map json, String name, String field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsStringOptional(Map json, String name, String? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsBoolRequired(Map json, String name, bool field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsBoolOptional(Map json, String name, bool? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsIntRequired(Map json, String name, int field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsIntOptional(Map json, String name, int? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsMapRequired(Map json, String name, Map field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsMapOptional(Map json, String name, Map? field) {
    field = (json.containsKey(name) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsListRequired(Map json, String name, List field) {
    if (!json.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = new List.from(json[name]!);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsListOptional(Map json, String name, List? field) {
    field = (json.containsKey(name) ? new List.from(json[name]) : null);
  }

  @Compile

  void setGetArgs(Map<String, String> queryParameters);

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  // ignore: unused_element
  void _setGetArgsStringRequired(Map<String, String> queryParameters, String name, String field) {
    if (!queryParameters.containsKey(name)) {
      throw new HttpRequestException('Missing required parameter ' + name);
    }
    field = queryParameters[name]!;
  }

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  // ignore: unused_element
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

class HttpUnauthorizedException extends HttpException {
  HttpUnauthorizedException() : super(HttpStatus.unauthorized, 'Unauthorised');
}

class HttpRequestException extends HttpException {
  HttpRequestException(String message) : super(HttpStatus.unprocessableEntity, message);
}

@ComposeSubtypes
abstract class PostAction extends HttpAction {
  int responseStatus = HttpStatus.ok;

  late Map<String, String> postArgs;
  late String rawBody;

  Future<String> run();

  Encoding get encoding => utf8;

  Future prepareArguments() async {
    rawBody = await utf8.decoder.bind(request).join('');
    postArgs = Uri.splitQueryString(rawBody, encoding:encoding);
    setPostArgs(postArgs);
    setGetArgs(request.uri.queryParameters);
  }

  Future handleRequest() async {
    await prepareArguments();
    responseStatus = HttpStatus.ok;
    String ret = await this.run();
    request.response.statusCode = responseStatus;
    //TODO content type for post actions
    request.response.headers.contentType = ContentType.text;
    request.response.write(ret);
  }
}

@ComposeSubtypes
abstract class JsonAction extends HttpAction {

  int responseStatus = HttpStatus.ok;
  Map postArgs = {};

  Future run();

  Future prepareArguments() async {
    String body = await utf8.decoder.bind(request).join('');
    if (body.length > 0) {
      var x = json.decode(body);
      if (x is Map){
        postArgs = x;
      }
    }
    setPostArgs(postArgs);
    setGetArgs(request.uri.queryParameters);
  }

  Future outputResponse(dynamic response) async {
    String ret = json.encode(response);
    request.response.statusCode = responseStatus;
    request.response.headers.contentType = ContentType.json;
    request.response.write(ret);
  }

  Future handleRequest() async {
    await prepareArguments();
    responseStatus = HttpStatus.ok;
    await outputResponse(await this.run());
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
  HttpAction createAction(String className, HttpRequest request, List<String> pathArgs);

  @Inject
  SubtypesOf<HttpAction> get allActions;

  RouteNode? _root;
  RouteNode get root {
    if (_root == null) {
      _root = new RouteNode();
      allActions.allClassNames.forEach((className) {
        String name = className;
        if (name.startsWith('module_')) {
          name = name.substring(7);
        }
        if (name.endsWith('Action')) {
          name = name.substring(0, name.length - 6);
        }
        var path = name.split('.').map((e) => e[0].toLowerCase() + e.substring(1)).toList();
        var exts = ['Json', 'Txt', 'Ico'];
        for (var ext in exts) {
          if (path.last.endsWith(ext)) {
            path.last = path.last.substring(0, path.last.length - ext.length) + '.' + ext.toLowerCase();
          }
        }
        _root!.add(
            path,
            className
        );
      });
    }
    return _root!;
  }

  String? mapPathToClassName(List<String> pathSegments) {
    return root.find(pathSegments);
  }

  HttpAction? getForRequest(HttpRequest request) {
    List<String> pathArgs = new List<String>.from(request.uri.pathSegments);
    String? className = this.mapPathToClassName(pathArgs);
    if (className == null) {
      return null;
    }
    HttpAction action = createAction(className, request, pathArgs);
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
    parser.addOption('threads');
    this.args = parser.parse(arguments);
    var argsPort = this.args!['port'];
    if (argsPort != null) {
      if (int.tryParse(argsPort) == null || int.parse(argsPort) < 1) {
        throw new Exception('--port value must be a positive integer.');
      }
      port = int.tryParse(argsPort);
    }
    var argsThreads = this.args!['threads'];
    if (argsThreads != null) {
      if (int.tryParse(argsThreads) == null || int.parse(argsThreads) < 1) {
        throw new Exception('--threads value must be a positive integer.');
      }
      threads = int.tryParse(argsThreads);
    }

  }

  int? port;
  int? threads;

  String get configPath {
    return this.args!['config'];
  }

}

class ServerThreadArgs {

  int threadId;
  int port;
  String configPath;

  ServerThreadArgs(this.threadId, this.port, this.configPath);

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
  ErrorHandler get errorHandler;
  @Inject
  Stats get stats;

  int threadId = 1;

  String get datadir => config.getRequired<String>('datadir');


  Future serve(List<String> arguments) async {

    print("starting HTTP server...");
    args.parse(arguments);
    await config.load(args.configPath);

    int port = args.port ?? config.getRequired<int>('port');
    int threads = args.threads ?? config.getOptional<int>('threads', 1);

    print('datadir: ${config.getRequired<String>('datadir')} port: $port threads: ${threads}');

    _startServerIsolate(new ServerThreadArgs(1, port, args.configPath));
    for (var i = 2; i < threads + 1; i++) {
      await Isolate.spawn(_startServerIsolate, new ServerThreadArgs(i, port, args.configPath));
    }
    await ProcessSignal.sigterm.watch().first;
    print("HTTP server terminated");
  }

  void _startServerIsolate(ServerThreadArgs args) async {

    await config.load(args.configPath);
    threadId = args.threadId;
    print("thread ${threadId} listening on http://*:${args.port}");

    HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      args.port,
      shared: true,
    );

    await for (final request in server) {
      await handleRequestWithTimeout(request);
    }
  }

  void writeError(HttpRequest request, int code, String message, {StackTrace? trace = null}) {
    //TODO depend on request accepted header
    //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
    request.response.statusCode = code;
    request.response.headers.contentType = ContentType.json;

    var json = {
      'error': "${code} ${httpStatusMessage[code]!}",
      'message': message
    };
    if (config.getRequired<bool>('debug') && trace != null) {
      json['trace'] = trace.toString();
    }
    request.response.write(jsonEncode(json));
  }

  Future handleRequestWithTimeout(HttpRequest request) async {
    return handleRequest(request).timeout(
        new Duration(milliseconds: 1500),
        onTimeout: () {
          print('TODO: handle timeout');
          //try {
          //  writeError(request, HttpStatus.requestTimeout, 'request timeout');
          //}
          //request.response.close();
        },
    );
  }

  Future handleRequest(HttpRequest request) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    int serviceId = config.getRequired<int>('service_id');
    String actionName = 'unknown';
    HttpAction? action = routing.getForRequest(request);
    int queries = 0;
    if (action == null) {
      writeError(request, HttpStatus.notFound, request.uri.toString());
    } else {
      try {
        actionName = action.className;
        await action.handleRequest();
      } on Redirect catch (error) {
        request.response.redirect(new Uri.http(request.uri.authority, error.uri));
      } on HttpException catch (error, stacktrace) {
        writeError(request, error.code, error.message, trace: stacktrace);
      } catch (error, stacktrace) {
        writeError(
            request,
            HttpStatus.internalServerError,
            'unknown error occured',
            trace: stacktrace
        );
        try {
          await errorHandler.handleError(
              action.db, serviceId, 'action.' + actionName, error, stacktrace);
        } catch (e) {
          print(e);
        }
      } finally {
        queries = action.db.counter;
        await action.db.disconnect();
      }
    }
    request.response.close();
    int timeMs = new DateTime.now().millisecondsSinceEpoch - start;
    try {
      if (action != null) {
        await stats.saveStats(
            serviceId, 'action', action, timeMs
        );
        await action.db.disconnect();
      }
    } catch(e) {
      print(e);
    }
    print("T${threadId} ${request.method} ${request.uri} ${request.response.statusCode} [${timeMs}ms] [$queries]");
  }

}
