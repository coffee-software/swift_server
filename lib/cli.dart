library c7server;

import 'package:args/args.dart';
import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';

import 'tools.dart';
export 'tools.dart';

/**
 * Single Command
 */
@ComposeSubtypes
abstract class Command {
  @InjectClassName
  String get className;

  @Inject
  Cli get cli;

  Future run();
}

@Compose
abstract class CliArgs {

  ArgResults? args;

  parse(List<String> arguments) {
    var parser = ArgParser();
    parser.addOption('config');
    this.args = parser.parse(arguments);
  }

  String get commandName => this.args!.rest[0];

  String get configPath {
    return this.args!['config'];
  }

}

/**
 * Daemon process handler
 */
@Compose
abstract class Cli {
  @Inject
  Db get db;

  @Inject
  Net get net;

  @Inject
  CliArgs get args;

  @Inject
  ServerConfig get config;

  @InjectInstances
  Map<String, Command> get allCommands;

  Future run(List<String> arguments) async {
    args.parse(arguments);
    await config.load(args.configPath);
    if (!allCommands.containsKey(args.commandName)) {
      allCommands.forEach((key, value) {
        print(key);
      });
      throw new Exception('unknown command ' + args.commandName);
    }
    var command = allCommands[args.commandName]!;
    await command.run();
    await db.disconnect();
  }
}