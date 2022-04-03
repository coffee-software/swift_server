library swift_composer.test;

import 'package:swift_server/server.dart';
import 'package:test/test.dart';
import '../bin/raw_server.dart' as raw_server;
import 'package:swift_server/testsuite.dart';
import 'package:path/path.dart' as path;

void main() {
    test('routing', () async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/schema.json')
      );
      expect(response.statusCode, 200);
      Map <String, dynamic> ret = response.toJson();
      expect(ret.keys.length, 4);
      expect(ret.containsKey('/schema.json'), true);
      expect(ret.containsKey('/status.json'), true);
      expect(ret.containsKey('/favicon.ico'), true);
      expect(ret.containsKey('/robots.txt'), true);
    });

    test('404', () async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/somethingnotexisting')
      );
      expect(response.statusCode, 404);
    });

    test('status', () async {
      final pathToDirectory = path.dirname(Platform.script.toFilePath());
      await raw_server.$om.server.config.load(pathToDirectory + '/config.yaml');
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/status.json')
      );
      expect(response.statusCode, 200);
      Map <String, dynamic> ret = response.toJson();
      expect(ret['healthy'], true);
      await raw_server.$om.server.db.disconnect();
    });

    test('robots', () async {
      var response = await getServerResponse(
          raw_server.$om.server,
          MockRequest.get('/robots.txt')
      );
      expect(response.statusCode, 200);
      expect(response.headers.contentType, ContentType.text);
      expect(response.toString().length > 0, true);
    });

    test('favicon', () async {
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
    });
}
