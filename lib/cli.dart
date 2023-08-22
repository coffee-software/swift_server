library c7server;

import 'dart:io';

import 'package:args/args.dart';
export 'package:args/args.dart';

import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/annotations.dart';
export 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';
export 'package:swift_server/config.dart';
import 'package:path/path.dart' as path;

import 'tools.dart';
export 'tools.dart';
export 'mailer.dart';

const CliArg = true;
const CliParameter = true;
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

  int paramI = 1;

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
  void _setCliArgsBool(ArgResults args, String name, bool field) {
    field = args[name];
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameters)
  // ignore: unused_element
  void _setCliArgsListRequired(ArgResults args, String name, List<String> field) {
    field = args.rest.sublist(1);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliParameter)
  // ignore: unused_element
  void _setCliArgsParameterString(ArgResults args, String name, String field) {
    field = args.rest[paramI++];
  }

  @Compile
  void configureCliArgs(ArgParser parser);

  @Compile
  void configureCliParams(List<String> params);

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringRequired(ArgParser parser, String name, String field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp:name, mandatory:true);
  }

  @CompileFieldsOfType
  @AnnotatedWith(CliArg)
  // ignore: unused_element
  void _configureCliArgsStringOptional(ArgParser parser, String name, String? field, {String HelpText_value = ''}) {
    parser.addOption(name, help: HelpText_value, valueHelp:name, mandatory:false);
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

  ArgParser getCommandArgParser(Command command) {
    var parser = ArgParser();
    parser.addOption('config', valueHelp: 'path', help: 'path to config file, defaults to \'config.yaml\'', mandatory:false);
    command.configureCliArgs(parser);
    return parser;
  }

  Future run(List<String> arguments) async {
    if (arguments.length < 1) {
      print('available commands:');
      availableCommands.allSubtypes.forEach((key, info) {
        String help = info.annotations.containsKey('HelpText') ? info.annotations['HelpText'] : '';
        print(classCodeToCommand(key) + ' ' + allCommands[key]!.params.map((e) => '[$e]').join(' ') + '\t' + help);
      });
      return;
    }
    String classCode = commandToClassCode(arguments[0]);
    if (!allCommands.containsKey(classCode)) {
      throw new Exception('unknown command ${arguments[0]}');
    }
    var command = allCommands[classCode]!;

    var parser = getCommandArgParser(command);

    ArgResults args = parser.parse(arguments);
    await config.load(args['config'] ?? path.dirname(Platform.script.toFilePath()) + '/config.yaml');
    command.setCliArgs(args);

    await command.run();
    await db.disconnect();
  }
}

@HelpText('print detailed help for given command')
abstract class Help extends Command {

  @CliParameter
  @HelpText('test')
  late String command;

  Future<void> run() async {
    String classCode = cli.commandToClassCode(command);
    if (cli.allCommands.containsKey(classCode)) {
      var commandObj = cli.allCommands[classCode]!;
      var parser = cli.getCommandArgParser(commandObj);
      var annotations = cli.availableCommands.allSubtypes[classCode]!.annotations;
      String help = annotations.containsKey('HelpText') ? annotations['HelpText'] : '';
      print(command + ' [options] ' + commandObj.params.map((e) => '[$e]').join(' ') + '\t' + help);
      print('detailed options:');
      print(parser.usage);
    } else {
      print('unknown command $command');
    }
  }

}
