import 'api.dart';

class StatusActionTest {
  dynamic value;
  bool isOk;
  StatusActionTest(this.isOk, {this.value});
}

@ComposeSubtypes
abstract class StatusActionCheck {
  @Inject
  Server get server;

  Future<Map<String, StatusActionTest>> check(StatusAction action);
}

abstract class StatusActionDbCheck extends StatusActionCheck {
  @override
  Future<Map<String, StatusActionTest>> check(StatusAction action) async {
    return {'database': StatusActionTest(await action.db.fetchOne<int>('SELECT 1') == 1)};
  }
}

abstract class StatusActionTickerCheck extends StatusActionCheck {
  @override
  Future<Map<String, StatusActionTest>> check(StatusAction action) async {
    int serviceId = server.config.getRequired<int>('service_id');
    var lastRun = await action.db.fetchOne<DateTime>('SELECT last_run FROM run_jobs WHERE app_id = ? AND job = ?', [serviceId, 'Ticker']);
    var ret = false;
    if (lastRun != null) {
      ret = DateTime.now().difference(lastRun).inSeconds < 65;
    }
    return {'ticker': StatusActionTest(ret, value: lastRun.toString())};
  }
}

abstract class StatusActionErrorsCheck extends StatusActionCheck {
  @override
  Future<Map<String, StatusActionTest>> check(StatusAction action) async {
    int serviceId = server.config.getRequired<int>('service_id');
    var errorsCount = await action.db.fetchOne<String>('SELECT SUM(current_count) FROM run_errors WHERE app_id = ?', [serviceId]);
    var intCount = errorsCount != null ? BigInt.parse(errorsCount).toInt() : 0;
    return {'errors': StatusActionTest(intCount < 10, value: intCount)};
  }
}

DateTime? _uptimeTimer;

/// Status Action
abstract class StatusAction extends JsonAction {
  @InjectInstances
  Map<String, StatusActionCheck> get allChecks;

  @override
  Future<dynamic> run() async {
    Map<String, StatusActionTest> checks = {};
    for (var key in allChecks.keys) {
      try {
        checks.addAll(await allChecks[key]!.check(this));
      } catch (e) {
        checks[key] = StatusActionTest(false, value: e.toString());
      }
    }
    _uptimeTimer ??= DateTime.now();
    var healthy = checks.values.map((a) => a.isOk).reduce((a, b) => a && b);
    if (!healthy) {
      responseStatus = HttpStatus.serviceUnavailable;
    }
    var now = DateTime.now();
    Map checksInfo = {};
    checks.forEach((key, value) {
      checksInfo[key] = {'ok': value.isOk, 'value': value.value};
    });

    return {'time': now.toString(), 'uptime': now.difference(_uptimeTimer!).inSeconds.toDouble() / (60 * 60 * 24), 'healthy': healthy, 'checks': checksInfo};
  }
}

/// Schema Action
abstract class SchemaAction extends JsonAction {
  Map<String, dynamic> routeNodeToMap(String path, RouteNode node) {
    Map<String, dynamic> ret = {};
    if (node.className != null) {
      ret[path] = {'handler': node.className, 'params': {}};
    }
    for (var k in node.subNodes.keys) {
      ret.addAll(routeNodeToMap('$path/$k', node.subNodes[k]!));
    }
    return ret;
  }

  @override
  Future<dynamic> run() async {
    return routeNodeToMap('', server.routing.root);
  }
}

/// Robots Action
abstract class RobotsTxtAction extends HttpAction {
  //Disallow: /first_url/*/
  //Disallow: /second_url/*/
  List<String> getDisallowedUrls() {
    return ['/'];
  }

  @override
  Future handleRequest() async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.text;
    request.response.writeln('User-agent: *');
    for (var url in getDisallowedUrls()) {
      request.response.writeln('Disallow: $url');
    }
  }
}

/// Favicon Action
abstract class FaviconIcoAction extends HttpAction {
  @override
  Future handleRequest() async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType('image', 'svg+xml');
    request.response.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" height="100" width="100"><path d="M 60,100 C 42,100 20,94 9,79 39,97 80,85 84,60 89,35 71,23 55,22 33,22 9,35 31,59 35,65 51,72 59,59 73,35 25,35 50,56 33,57 30,45 35,39 38,34 56,30 65,36 82,50 64,74 48,79 29,85 9,72 3,55 -10,16 25,0 55,0 85,0 100,29 100,52 100,76 80,99 60,100 Z" style="fill:#4582b2"/></svg>',
    );
  }
}
