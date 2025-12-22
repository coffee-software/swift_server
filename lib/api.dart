library;

import 'dart:io';
export 'dart:io' hide HttpException;
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';


import 'http_status_codes.dart';
import 'package:args/args.dart';

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

/// Single HTTP API Endpoint
@ComposeSubtypes
abstract class HttpAction implements BackendProcessorInterface {
  @InjectClassName
  String get className;

  Stats? stats;

  @Inject
  Server get server;

  @override
  @Create
  late Db db;

  @override
  Logger get logger => server.logger;
  @override
  ServerConfig get serverConfig => server.config;

  String? rawBody;

  @Require
  late HttpRequest request;

  @Require
  late List<String> pathArgs;

  @Compile
  void setPostArgs(Map json);

  Future reportError(error, stackTrace) => server.logger.handleError('action.$className', error, stackTrace, request: request, requestBody: rawBody);

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsStringRequired(Map json, String name, String field) {
    if (!json.containsKey(name)) {
      throw HttpRequestException('Missing required parameter $name');
    }
    if (json[name] is! String) {
      throw HttpRequestException('Wrong required parameter $name');
    }
    field = json[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsStringOptional(Map json, String name, String? field) {
    field = ((json.containsKey(name) && json[name] is String) ? json[name] : null);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsBoolRequired(Map json, String name, bool field) {
    if (!json.containsKey(name)) {
      throw HttpRequestException('Missing required parameter $name');
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
      throw HttpRequestException('Missing required parameter $name');
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
      throw HttpRequestException('Missing required parameter $name');
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
      throw HttpRequestException('Missing required parameter $name');
    }
    field = List.from(json[name]!);
  }

  @CompileFieldsOfType
  @AnnotatedWith(PostArg)
  // ignore: unused_element
  void _setPostArgsListOptional(Map json, String name, List? field) {
    field = (json.containsKey(name) ? List.from(json[name]) : null);
  }

  @Compile
  void setGetArgs(Map<String, String> queryParameters);

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  // ignore: unused_element
  void _setGetArgsStringRequired(Map<String, String> queryParameters, String name, String field) {
    if (!queryParameters.containsKey(name)) {
      throw HttpRequestException('Missing required parameter $name');
    }
    field = queryParameters[name]!;
  }

  @CompileFieldsOfType
  @AnnotatedWith(GetArg)
  // ignore: unused_element
  void _setGetArgsIntRequired(Map<String, String> queryParameters, String name, int field) {
    if (!queryParameters.containsKey(name)) {
      throw HttpRequestException('Missing required parameter $name');
    }
    try {
      field = int.parse(queryParameters[name]!);
    } catch (_) {
      throw HttpRequestException('Wrong parameter format $name');
    }
  }

  Future handleRequest();
}

class Redirect implements Exception {
  String uri;
  Redirect(this.uri);
}

@ComposeSubtypes
abstract class PostAction extends HttpAction {
  int responseStatus = HttpStatus.ok;

  late Map<String, String> postArgs;
  Future<String> run();

  Encoding get encoding => utf8;

  Future prepareArguments() async {
    rawBody = await utf8.decoder.bind(request).join('');
    postArgs = Uri.splitQueryString(rawBody!, encoding: encoding);
    setPostArgs(postArgs);
    setGetArgs(request.uri.queryParameters);
  }

  @override
  Future handleRequest() async {
    await prepareArguments();
    responseStatus = HttpStatus.ok;
    String ret = await run();
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
    rawBody = await utf8.decoder.bind(request).join('');
    if (rawBody!.isNotEmpty) {
      try {
        var x = json.decode(rawBody!);
        if (x is Map) {
          postArgs = x;
        }
      } on FormatException catch (_) {
        throw HttpRequestException('wrong json format');
      }
    }
    setPostArgs(postArgs);
    Map<String, String> getParams = {};
    try {
      getParams = request.uri.queryParameters;
    } on FormatException catch (_) {
      throw HttpRequestException('malformed get params');
    }
    setGetArgs(getParams);
  }

  Future outputResponse(dynamic response) async {
    String ret = json.encode(response);
    request.response.statusCode = responseStatus;
    request.response.headers.contentType = ContentType.json;
    request.response.write(ret);
  }

  @override
  Future<void> handleRequest() async {
    await prepareArguments();
    responseStatus = HttpStatus.ok;
    await outputResponse(await run());
  }
}

/// Routing Node
class RouteNode {
  String? className;
  Map<String, RouteNode> subNodes = {};

  String? find(List<String> path) {
    if (path.isNotEmpty && subNodes.containsKey(path.first)) {
      return subNodes[path.removeAt(0)]!.find(path);
    }
    return className;
  }

  void add(List<String> path, String className, {int depth = 0}) {
    if (path.length == depth) {
      this.className = className;
    } else {
      if (!subNodes.containsKey(path[depth])) {
        subNodes[path[depth]] = RouteNode();
      }
      subNodes[path[depth]]!.add(path, className, depth: ++depth);
    }
  }
}

/// Routing Handler
@Compose
abstract class Router implements Pluggable {
  @SubtypeFactory
  HttpAction createAction(String className, HttpRequest request, List<String> pathArgs);

  @Inject
  SubtypesOf<HttpAction> get allActions;

  RouteNode? _root;
  RouteNode get root {
    if (_root == null) {
      _root = RouteNode();
      for (var className in allActions.allClassNames) {
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
            path.last = '${path.last.substring(0, path.last.length - ext.length)}.${ext.toLowerCase()}';
          }
        }
        _root!.add(path, className);
      }
    }
    return _root!;
  }

  String? mapPathToClassName(List<String> pathSegments) {
    return root.find(pathSegments);
  }

  HttpAction? getForRequest(HttpRequest request) {
    List<String> pathArgs = List<String>.from(request.uri.pathSegments);
    String? className = mapPathToClassName(pathArgs);
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

  void parse(List<String> arguments) {
    var parser = ArgParser();
    parser.addOption('config');
    parser.addOption('port');
    parser.addOption('threads');
    args = parser.parse(arguments);
    var argsPort = args!['port'];
    if (argsPort != null) {
      if (int.tryParse(argsPort) == null || int.parse(argsPort) < 1) {
        throw Exception('--port value must be a positive integer.');
      }
      port = int.tryParse(argsPort);
    }
    var argsThreads = args!['threads'];
    if (argsThreads != null) {
      if (int.tryParse(argsThreads) == null || int.parse(argsThreads) < 1) {
        throw Exception('--threads value must be a positive integer.');
      }
      threads = int.tryParse(argsThreads);
    }
  }

  int? port;
  int? threads;

  String get configPath {
    return args!['config'];
  }
}

class ServerThreadArgs {
  int threadId;
  int port;
  String configPath;
  Map sharedData;

  ServerThreadArgs(this.threadId, this.port, this.configPath, this.sharedData);
}

/// Server
@Compose
abstract class Server {
  @Inject
  Router get routing;
  @Inject
  ServerConfig get config;
  @Inject
  ServerArgs get args;

  int threadId = 1;

  String get datadir => config.getRequired<String>('datadir');

  Future serve(List<String> arguments) async {
    print("starting HTTP server...");
    args.parse(arguments);
    await config.load(args.configPath);

    int port = args.port ?? config.getRequired<int>('port');
    int threads = args.threads ?? config.getOptional<int>('threads', 1);

    print('PID: $pid datadir: $datadir port: $port threads: $threads');
    _startServerIsolate(ServerThreadArgs(1, port, args.configPath, sharedServerData));
    List<Isolate> isolates = [];
    for (var i = 2; i < threads + 1; i++) {
      isolates.add(await Isolate.spawn(_startServerIsolate, ServerThreadArgs(i, port, args.configPath, sharedServerData)));
    }
    await ProcessSignal.sigterm.watch().first;
    print("terminating HTTP server");
    exit(0);
  }

  void _startServerIsolate(ServerThreadArgs args) async {
    await config.load(args.configPath);
    threadId = args.threadId;
    sharedServerData = args.sharedData;
    print("thread $threadId, data ${sharedServerData.length}, listening on http://*:${args.port}");

    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, args.port, shared: true);
    server.listen(handleRequest);
  }

  void writeError(HttpRequest request, int code, String message, {StackTrace? trace}) {
    //TODO depend on request accepted header
    //request.response.write("<pre>${new HtmlEscape().convert(stackTrace.toString())}</pre>");
    try {
      request.response.statusCode = code;
      request.response.headers.contentType = ContentType.json;
    } catch (e) {}
    var json = {'error': "$code ${httpStatusMessage[code]!}", 'message': message};
    if (config.getRequired<bool>('debug') && trace != null) {
      json['trace'] = trace.toString();
    }
    request.response.write(jsonEncode(json));
  }

  @Create
  late Db db;

  Logger get logger => Logger(db, config.getRequired<int>('service_id'), config.getRequired<bool>('debug'));

  Future handleRequest(HttpRequest request) async {
    int? serviceId;
    String actionName = 'unknown';
    HttpAction? action;
    try {
      int start = DateTime.now().millisecondsSinceEpoch;
      serviceId = config.getRequired<int>('service_id');
      action = routing.getForRequest(request);
      int queries = 0;
      if (action == null) {
        writeError(request, HttpStatus.notFound, request.uri.toString());
      } else {
        action.stats = Stats(config, serviceId, 'action', action.className);
        try {
          actionName = action.className;
          //TODO: add timeout option
          await action.handleRequest(); //.timeout(new Duration(milliseconds: 1000));
        } on TimeoutException catch (error, stacktrace) {
          writeError(request, HttpStatus.requestTimeout, 'Request Timeout', trace: stacktrace);
        } on Redirect catch (error) {
          request.response.redirect(Uri.http(request.uri.authority, error.uri));
        } on HttpException catch (error, stacktrace) {
          writeError(request, error.code, error.message, trace: stacktrace);
        } catch (error, stacktrace) {
          writeError(request, HttpStatus.internalServerError, 'unknown error occured', trace: stacktrace);
          try {
            await logger.handleError('action.$actionName', error, stacktrace, request: request, requestBody: action.rawBody);
            db.disconnect();
          } catch (e) {
            print('CRITICAL! UNHANDLED ERROR');
            print(e);
          }
        } finally {
          queries = action.db.counter;
          await action.db.disconnect();
        }
      }
      int timeMs = DateTime.now().millisecondsSinceEpoch - start;
      print("T$threadId ${request.method} ${request.uri} ${request.response.statusCode} [${timeMs}ms] [$queries]");
      await request.response.close();

      if (action != null) {
        action.stats?.saveStats(action.db.counter, timeMs);
      }
    } catch (error, stacktrace) {
      try {
        await logger.handleError('action.$actionName', error, stacktrace, request: request, requestBody: action?.rawBody);
        db.disconnect();
      } catch (e) {
        print('CRITICAL! UNHANDLED ERROR');
        print(e);
      }
    }
  }
}
