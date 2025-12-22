import 'package:swift_server/api.dart';

part 'raw_server.c.dart';

void main(List<String> arguments) async {
  await $om.server.serve(arguments);
}

abstract class TestAction extends JsonAction {
  @override
  Future run() async {
    return {'response': 'test', 'float': 1.5};
  }
}
