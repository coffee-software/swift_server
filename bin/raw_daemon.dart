import 'package:swift_server/daemon.dart';

part 'raw_daemon.c.dart';

void main (List<String> arguments) async {
  $om.daemon.run(arguments);
}