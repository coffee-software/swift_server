library swift_composer.test;

import 'package:test/test.dart';

import 'servers/raw_server.dart' as raw_server;

void main() {

    test('routing', () {

      raw_server.$om.server.serve([]);

    });

}
