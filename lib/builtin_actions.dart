
import 'server.dart';



/**
 * Status Action
 */
abstract class StatusAction extends JsonAction {

  Future<dynamic> run() async
  {
    return {
      'time': DateTime.now().toString(),
      'healthy': true
    };
  }

}

/**
 * Schema Action
 */
abstract class SchemaAction extends JsonAction {

  Map<String, dynamic> routeNodeToMap(RouteNode node)
  {
    Map<String, dynamic> ret = {
      'handler': node.className,
      'subnodes': {}
    };
    node.subNodes.forEach((k, node){
      ret['subnodes'][k] = routeNodeToMap(node);
    });
    return ret;
  }

  Future<dynamic> run() async
  {
    return routeNodeToMap(server.routing.root);
  }

}

/**
 * Robots Action
 */
abstract class RobotsAction extends HttpAction {

  String? ext = 'txt';

  Future handleRequest() async
  {
    request.response.statusCode = 200;
    request.response.headers.contentType = new ContentType('text', 'plain');
    request.response.writeln('User-agent: *');
    request.response.writeln('Disallow: /');
  }

}


/**
 * Favicon Action
 */
abstract class FaviconAction extends HttpAction {

  String? ext = 'ico';

  Future handleRequest() async
  {
    request.response.statusCode = 200;
    request.response.headers.contentType = new ContentType('image', 'svg+xml');
    request.response.write('<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" height="238" width="238"><path d="M 141,237 C 95,243 47,223 20,188 92,230 189,202 199,143 209,83 168,54 129,53 77,52 20,83 71,141 82,154 120,170 139,140 172,84 58,84 118,134 78,136 70,107 81,92 89,81 133,70 152,86 194,118 151,177 113,188 68,202 20,170 6,130 -24,37 58,-4 129,0 200,5 240,52 237,124 c -1,44 -47,106 -97,113 z" style="fill:#4582b2;" /></svg>');
  }

}
