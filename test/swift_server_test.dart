library swift_composer.test;

import 'dart:async';

import 'package:swift_server/api.dart';
import 'package:test/test.dart';
import '../example/raw_server.dart' as raw_server;
import '../example/raw_daemon.dart' as raw_daemon;
import '../example/raw_cli.dart' as raw_cli;
import 'package:swift_server/testsuite.dart';
import 'package:path/path.dart' as path;

String testConfigPath() {
  return path.dirname(Platform.script.toFilePath()) + '/config.yaml';
}

Future loadConfig() async {
  await raw_server.$om.server.config.load(testConfigPath());
  await raw_daemon.$om.daemon.config.load(testConfigPath());
}

var _log = [];
void Function() overridePrint(void testFn()) => () {
  _log = [];
  var spec = new ZoneSpecification(
      print: (_, __, ___, String msg) {
        _log.add(msg);
      }
  );
  return Zone.current.fork(specification: spec).run<void>(testFn);
};

List<dynamic> getLogs() {
  return _log;
}

void main() async {
  await loadConfig();

    test('routing', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/schema')
      );
      expect(response.statusCode, 200);
      Map <String, dynamic> ret = response.toJson();
      expect(ret.keys.length, 5);
      expect(ret.containsKey('/schema'), true);
      expect(ret.containsKey('/status'), true);
      expect(ret.containsKey('/test'), true);
      expect(ret.containsKey('/favicon.ico'), true);
      expect(ret.containsKey('/robots.txt'), true);
    }));

    test('404', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/somethingnotexisting')
      );
      expect(response.statusCode, 404);
    }));

    test('test action', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/test')
      );
      expect(response.statusCode, 200);
      expect(response.toString(), '{"response":"test","float":1.5}');
    }));

    test('database time settings', () async {
      DateTime dbTime = (await raw_daemon.$om.daemon.db.fetchOne<DateTime>('SELECT NOW()'))!;
      DateTime systemTime = new DateTime.now();
      expect(dbTime.difference(systemTime).inSeconds, 0);
      await raw_daemon.$om.daemon.db.disconnect();
    });

    test('database tools', () async {

      await raw_daemon.$om.daemon.db.query('DROP TABLE IF EXISTS `test_getIdOrInsert`');
      await raw_daemon.$om.daemon.db.query("""
            CREATE TABLE `test_getIdOrInsert` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `tag` varchar(512) NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `tag` (`tag`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
      """);
      String testTag1 = 'test123';
      String testTag2 = 'test1234';

      int id = await raw_daemon.$om.daemon.db.getIdOrInsert('test_getIdOrInsert', '`tag` = ?', [ testTag1 ], '`tag` = ?', [ testTag1 ]);
      expect(id, 1);
      id = await raw_daemon.$om.daemon.db.getIdOrInsert('test_getIdOrInsert', '`tag` = ?', [ testTag1 ], '`tag` = ?', [ testTag1 ]);
      expect(id, 1);
      id = await raw_daemon.$om.daemon.db.getIdOrInsert('test_getIdOrInsert', '`tag` = ?', [ testTag2 ], '`tag` = ?', [ testTag2 ]);
      expect(id, 2);

      await raw_daemon.$om.daemon.db.disconnect();
    });

    test('daemon jobs test', overridePrint(() async {
      //force jobs to be executed
      await raw_daemon.$om.daemon.db.query('DELETE FROM run_jobs WHERE job != ?', ['banana']);
      await raw_daemon.$om.daemon.step();
      int serviceId = raw_daemon.$om.daemon.config.getRequired<int>('service_id');

      var row = await raw_daemon.$om.daemon.db.fetchRow(
          'SELECT * FROM run_jobs WHERE app_id = ? AND job = ?',
          [ serviceId, 'Ticker' ]
      );
      DateTime daemonLastRun = row!['last_run'];
      expect(new DateTime.now().difference(daemonLastRun).inSeconds < 65, true);
      expect(getLogs().indexOf('running test job') > -1, true);
      await raw_daemon.$om.daemon.db.disconnect();
    }));

    test('daemon queues test', overridePrint(() async {
      await raw_daemon.$om.daemon.processQueuesIsolate();
      int serviceId = raw_daemon.$om.daemon.config.getRequired<int>('service_id');
      await raw_daemon.$om.testQueue1.postMessage(123);
      await raw_daemon.$om.testQueue1.postMessage(456);
      await raw_daemon.$om.testQueue2.postMessage('TEST1');
      await Future.delayed(Duration(milliseconds: 500));
      var row = await raw_daemon.$om.daemon.db.fetchRow(
          'SELECT * FROM run_queues WHERE app_id = ? AND queue = ?',
          [ serviceId, 'TestQueue1' ]
      );
      DateTime lastProcess = row!['last_process'];
      expect(new DateTime.now().difference(lastProcess).inSeconds < 5, true);
      expect(getLogs().indexOf('queue 1 message: 456') > -1, true);
      expect(getLogs().indexOf('queue 2 message: TEST1') > -1, true);
      await raw_daemon.$om.daemon.finishQueuesIsolate();
      await raw_daemon.$om.daemon.db.disconnect();
    }));

    test('daemon CLI test', overridePrint(() async {
      await raw_cli.$om.cli.run(['TestCommand', '--config', testConfigPath(), '--testArg', 'TEST_ARG']);
      expect(getLogs().indexOf('running test CLI command with arg = TEST_ARG') > -1, true);
    }));

    test('status', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/status')
      );
      expect(response.statusCode, 200);
      Map <String, dynamic> ret = response.toJson();
      expect(ret['healthy'], true);
    }));

    test('robots', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/robots.txt')
      );
      expect(response.statusCode, 200);
      expect(response.headers.contentType, ContentType.text);
      expect(response.toString().length > 0, true);
    }));

    test('favicon', overridePrint(() async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/favicon.ico')
      );
      expect(response.statusCode, 200);
      expect(response.headers.contentType.toString(), 'image/svg+xml');
      expect(
          response.toString(),
          '<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" height="100" width="100"><path d="M 60,100 C 42,100 20,94 9,79 39,97 80,85 84,60 89,35 71,23 55,22 33,22 9,35 31,59 35,65 51,72 59,59 73,35 25,35 50,56 33,57 30,45 35,39 38,34 56,30 65,36 82,50 64,74 48,79 29,85 9,72 3,55 -10,16 25,0 55,0 85,0 100,29 100,52 100,76 80,99 60,100 Z" style="fill:#4582b2"/></svg>'
      );
    }));

    test('exceptions handling test', overridePrint(() async {
      await raw_daemon.$om.daemon.db.query('DELETE FROM run_errors');
      await raw_daemon.$om.daemon.processQueuesIsolate();
      await raw_daemon.$om.testQueue2.postMessage('exception');
      await Future.delayed(Duration(milliseconds: 500));
      var count = await raw_daemon.$om.daemon.db.fetchOne<int>('SELECT COUNT(*) FROM run_errors');
      expect(count, 1);
      await raw_daemon.$om.daemon.finishQueuesIsolate();
      await raw_daemon.$om.daemon.db.disconnect();
      expect(getLogs().indexOf('###############         Unhandled Error         ###############') > -1, true);
    }));

    test('named locks', () async {
      [1,2,3].forEach((element) async {
        await raw_server.$om.namedLock.lock('test');
        await Future.delayed(const Duration(milliseconds: 100));
        await raw_server.$om.namedLock.unlock('test');
      });
    });

    test('net tools', () async {
      HttpServer server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        18256
      );
      StreamSubscription echo = server.listen((request) {
        request.response.statusCode = HttpStatus.ok;
        request.response.write('{\"ret\":\"${request.headers['headerX']}\"}');
        request.response.close();
      });

      var ret1 = await raw_cli.$om.cli.net.getHtml('http://localhost:18256/test', extraHeaders: {'headerX': 'value'});
      expect(ret1, '{"ret":"[value]"}');
      
      var ret2 = await raw_cli.$om.cli.net.postJson('http://localhost:18256/test', {'test': 'test'}, extraHeaders: {'headerX': 'value'});
      expect(ret2, {"ret":"[value]"});

      var ret3 = await raw_cli.$om.cli.net.getRaw('http://localhost:18256/test', extraHeaders: {'headerX': 'value'});
      expect(ret3, [123, 34, 114, 101, 116, 34, 58, 34, 91, 118, 97, 108, 117, 101, 93, 34, 125]);

      echo.cancel();
    });
}
