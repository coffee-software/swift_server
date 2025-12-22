library swift_server;

import 'dart:io';

import 'package:args/args.dart';
export 'package:args/args.dart';

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/annotations.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';
import 'package:path/path.dart' as path;
import 'package:swift_server/server.dart';

import 'tools.dart';
export 'tools.dart';
export 'mailer.dart';
export 'cache.dart';
import 'logger.dart';

const CliArg = true;
const CliParameter = true;
const CliParameters = true;

/**
 * Single Command
 */
@ComposeSubtypes
abstract class Command implements BackendProcessorInterface {
  @InjectClassName
  String get className;

  @Inject
  Cli get cli;

  Db get db => cli.db;
  ServerConfig get serverConfig => cli.config;

  Logger get logger => new Logger(cli.db, 0, cli.config.getRequired<bool>('debug'));

  Future run();

  int paramI = 0;

  List<String> get params {
    List<String> params = [];
    configureCliParams(params);
    return params;
  }

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
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _setCliArgsIntRequired(ArgResults args, String name, int field) {
    field = args[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _setCliArgsIntOptional(ArgResults args, String name, int? field) {
    field = args[name] ?? null;
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _setCliArgsBool(ArgResults args, String name, bool field) {
    field = args[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameters)
  // ignore: unused_element
  void _setCliArgsListRequired(ArgResults args, String name, List<String> field) {
    field = args.rest.sublist(0);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameter)
  // ignore: unused_element
  void _setCliArgsParameterString(ArgResults args, String name, String field) {
    if (args.rest.length <= this.paramI) {
      throw Exception("Missing CLI ARG " + name);
    }
    field = args.rest[this.paramI++];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameter)
  // ignore: unused_element
  void _setCliArgsParameterInt(ArgResults args, String name, int field) {
    if (args.rest.length <= this.paramI) {
      throw Exception("Missing CLI ARG " + name);
    }
    field = int.parse(args.rest[this.paramI++]);
  }

  @Compile
  void configureCliArgs(ArgParser parser);

  @Compile
  void configureCliParams(List<String> params);

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringRequired(ArgParser parser, String name, String field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp: name, mandatory: true);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringOptional(ArgParser parser, String name, String? field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp: name, mandatory: false);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsIntRequired(ArgParser parser, String name, int field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp: name, mandatory: true);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsIntOptional(ArgParser parser, String name, int? field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp: name, mandatory: false);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsBool(ArgParser parser, String name, bool field, {String HelpText_value = ''}) {
    parser.addFlag(name, help: HelpText_value);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameter)
  // ignore: unused_element
  void _configureCliParamsString(List<String> params, String name, String field, {String HelpText_value = ''}) {
    params.add(name);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameter)
  // ignore: unused_element
  void _configureCliParamsInt(List<String> params, String name, int field, {String HelpText_value = ''}) {
    params.add(name);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameters)
  // ignore: unused_element
  void _configureCliParamsStringsList(List<String> params, String name, List<String> field, {String HelpText_value = ''}) {
    params.add(name + ',..');
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

  @Inject
  SubtypesOf<Command> get availableCommands;

  String commandToClassCode(String command) {
    var bits = command.split(':');
    if (bits.length > 1) {
      bits[0] = 'module_' + bits[0];
      bits[1] = bits[1][0].toUpperCase() + bits[1].substring(1);
    } else {
      bits[0] = bits[0][0].toUpperCase() + bits[0].substring(1);
    }
    return bits.join('.');
  }

  String classCodeToCommand(String code) {
    var bits = code.split('.');
    bits[0] = bits[0].replaceFirst('module_', '');
    return bits.map((e) => e[0].toLowerCase() + e.substring(1)).join(':');
  }

  ArgParser getRootArgParser() {
    var parser = ArgParser();
    parser.addOption('config', valueHelp: 'path', help: 'path to config file, defaults to \'config.yaml\'', mandatory: false);
    return parser;
  }

  ArgParser getCommandArgParser(Command command) {
    var parser = ArgParser();
    command.configureCliArgs(parser);
    return parser;
  }

  @Inject
  RedisCache get redisCache;

  String get executableName => 'cli';

  void printUsage(String error) async {
    print('Error: ' + error);
    print('Usage: $executableName <command> [arguments]');
    print('Global options:');
    print(argParser!.usage.split('\n').map((l) => '\t' + l).join('\n'));
    print('Available commands:');
    availableCommands.allSubtypes.forEach((key, info) {
      String help = info.annotations.containsKey('HelpText') ? info.annotations['HelpText'] : '';
      print('\t' + classCodeToCommand(key) + ' ' + allCommands[key]!.params.map((e) => '<$e>').join(' ') + '\t' + help);
    });
    print('Run "$executableName help <command>" for more information about a command.');
  }

  ArgParser? argParser;

  Future run(List<String> arguments) async {
    argParser = getRootArgParser();
    availableCommands.allSubtypes.forEach((key, info) {
      var command = allCommands[key]!;
      argParser!.addCommand(classCodeToCommand(key), getCommandArgParser(command));
    });
    ArgResults args;
    String? error;
    try {
      args = argParser!.parse(arguments);
    } on FormatException catch (e) {
      error = e.message;
      args = argParser!.parse([]);
    }
    if (args.command == null) {
      printUsage(error == null ? 'Unknown command' : error);
      return 1;
    } else {
      await config.load(args['config'] ?? path.dirname(Platform.script.toFilePath()) + '/config.yaml');
      String classCode = commandToClassCode(args.command!.name!);
      var command = allCommands[classCode]!;
      command.setCliArgs(args.command!);
      await command.run();
      await db.disconnect();
      await redisCache.disconnect();
      return 0;
    }
  }
}

@HelpText('print detailed help for given command')
abstract class Help extends Command {
  @CliParameter
  @HelpText('command to display help for')
  late String command;

  Future<void> run() async {
    String classCode = cli.commandToClassCode(command);
    if (cli.allCommands.containsKey(classCode)) {
      var commandObj = cli.allCommands[classCode]!;
      var parser = cli.getCommandArgParser(commandObj);
      var annotations = cli.availableCommands.allSubtypes[classCode]!.annotations;
      String help = annotations.containsKey('HelpText') ? annotations['HelpText'] : '';
      print('${cli.executableName} $command [options] ' + commandObj.params.map((e) => '<$e>').join(' '));
      print(help);
      print('Detailed options:');
      print(parser.usage);
    } else {
      print('unknown command $command');
    }
  }
}
