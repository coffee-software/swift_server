import 'package:swift_server/server.dart';

part 'raw_server.c.dart';

void main (List<String> arguments) async {
  await $om.server.serve(arguments);
}

abstract class TestAction extends JsonAction {

  Future run() async {
    return {
      'response': 'test',
      'float': 1.5
    };
  }
}