import 'package:swift_server/server.dart';

part 'raw_server.c.dart';

void main (List<String> arguments) async {
  $om.server.serve(arguments);
}