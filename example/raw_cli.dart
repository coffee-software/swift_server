import 'package:swift_server/cli.dart';

part 'raw_cli.c.dart';

void main(List<String> arguments) async {
  await $om.cli.run(arguments);
}

abstract class TestCommand extends Command {
  @CliArg
  late String testArg;

  Future run() async {
    print('running test CLI command with arg = ' + testArg);
  }
}
