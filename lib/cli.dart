library c7server;

import 'package:args/args.dart';
export 'package:args/args.dart';

import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';

import 'tools.dart';
export 'tools.dart';
export 'mailer.dart';

const CliArg = true;
const CliParameters = true;

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

  @Compile
  void setCliArgs(ArgResults args);

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _setCliArgsStringRequired(ArgResults args, String name, String field) {
    field = args[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _setCliArgsStringOptional(ArgResults args, String name, String? field) {
    field = args[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameters)
  // ignore: unused_element
  void _setCliArgsListRequired(ArgResults args, String name, List<String> field) {
    field = args.rest.sublist(1);
  }

  @Compile
  void configureCliArgs(ArgParser parser);

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringRequired(ArgParser parser, String name, String field) {
    parser.addOption(name, mandatory:true);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringOptional(ArgParser parser, String name, String? field) {
    parser.addOption(name, mandatory:false);
  }
}

/**
 * Daemon process handler
 */
@Compose
abstract class Cli {
  @Create
  late Db db;

  @Inject
  Net get net;

  @Inject
  ServerConfig get config;

  @InjectInstances
  Map<String, Command> get allCommands;

  Future run(List<String> arguments) async {
    if (arguments.length < 1 || !allCommands.containsKey(arguments[0])) {
      allCommands.forEach((key, value) {
        print(key);
      });
      throw new Exception('unknown command');
    }
    var command = allCommands[arguments[0]]!;

    var parser = ArgParser();
    parser.addOption('config', mandatory:true);
    command.configureCliArgs(parser);
    ArgResults args = parser.parse(arguments);
    await config.load(args['config']);
    command.setCliArgs(args);
    await command.run();
    await db.disconnect();
  }
}