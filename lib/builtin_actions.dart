
import 'server.dart';



/**
 * Status Action
 */
abstract class StatusAction extends JsonAction {

  Future<dynamic> run() async
  {
    var healthChecks = {
      'db' : () async => await server.db.fetchOne('SELECT 1') == 1,
      'daemon' : () async {
        int serviceId = server.config.getRequired<int>('service_id');
        var lastRun = await server.db.fetchOne(
            'SELECT last_run FROM run_jobs WHERE app_id = ? AND job = ?',
            [ serviceId, 'Ticker' ]
        );
        if (lastRun == null) {
          return false;
        }
        DateTime daemonLastRun = server.db.fixTZ(lastRun);
        return new DateTime.now().difference(daemonLastRun).inSeconds < 65;
      }
    };

    Map<String, bool> checks = {};
    for (var key in healthChecks.keys) {
      try {
        checks[key] = await healthChecks[key]!();
      } catch (e) {
        checks[key] = false;
      }
    }

    return {
      'time': DateTime.now().toString(),
      'healthy': checks.values.reduce((a, b) => a && b),
      'checks': checks
    };
  }

}

/**
 * Schema Action
 */
abstract class SchemaAction extends JsonAction {

  Map<String, dynamic> routeNodeToMap(String path, RouteNode node)
  {
    Map<String, dynamic> ret = {};
    if (node.className != null) {
      ret[path] = {
        'handler': node.className,
        'params': {}
      };
    }
    node.subNodes.forEach((k, node){
      ret.addAll(routeNodeToMap(path + '/' + k, node));
    });
    return ret;
  }

  Future<dynamic> run() async
  {
    return routeNodeToMap('', server.routing.root);
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
    request.response.headers.contentType = ContentType.text;
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
    request.response.write('<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" height="100" width="100"><path d="M 60,100 C 42,100 20,94 9,79 39,97 80,85 84,60 89,35 71,23 55,22 33,22 9,35 31,59 35,65 51,72 59,59 73,35 25,35 50,56 33,57 30,45 35,39 38,34 56,30 65,36 82,50 64,74 48,79 29,85 9,72 3,55 -10,16 25,0 55,0 85,0 100,29 100,52 100,76 80,99 60,100 Z" style="fill:#4582b2"/></svg>');
  }

}
