library swift_composer.test;

import 'package:swift_server/server.dart';
import 'package:test/test.dart';
import 'servers/raw_server.dart' as raw_server;
import 'swift_server_testsuite.dart';

void main() {
    test('routing', () async {
      var request = new MockRequest('GET', '/schema.json');
      await raw_server.$om.server.handleRequest(request);
      Map <String, dynamic> ret = request.response.toJson();

      expect(ret.keys.length, 4);
      expect(ret.containsKey('/schema.json'), true);
      expect(ret.containsKey('/status.json'), true);
      expect(ret.containsKey('/favicon.ico'), true);
      expect(ret.containsKey('/robots.txt'), true);
    });

    test('404', () async {
      var request = new MockRequest('GET', '/somethingnotexisting');
      await raw_server.$om.server.handleRequest(request);
      expect(request.response.statusCode, 404);
    });

    test('status', () async {
      var request = new MockRequest('GET', '/status.json');
      await raw_server.$om.server.handleRequest(request);
      Map <String, dynamic> ret = request.response.toJson();
      expect(ret['healthy'], true);
    });

    test('robots', () async {
      var request = new MockRequest('GET', '/robots.txt');
      await raw_server.$om.server.handleRequest(request);
      expect(request.response.headers.contentType, ContentType.text);
      expect(request.response.toString().length > 0, true);
    });

    test('favicon', () async {
      var request = new MockRequest('GET', '/favicon.ico');
      await raw_server.$om.server.handleRequest(request);
      expect(request.response.headers.contentType.toString(), 'image/svg+xml');
      expect(
          request.response.toString(),
          '<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" height="100" width="100"><path d="M 60,100 C 42,100 20,94 9,79 39,97 80,85 84,60 89,35 71,23 55,22 33,22 9,35 31,59 35,65 51,72 59,59 73,35 25,35 50,56 33,57 30,45 35,39 38,34 56,30 65,36 82,50 64,74 48,79 29,85 9,72 3,55 -10,16 25,0 55,0 85,0 100,29 100,52 100,76 80,99 60,100 Z" style="fill:#4582b2"/></svg>'
      );
    });
}
