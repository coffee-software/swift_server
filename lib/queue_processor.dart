import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/logger.dart';
import 'queue.dart';
import 'tools.dart';
import 'config.dart';
import 'stats.dart';
import 'server.dart';

@ComposeSubtypes
abstract class QueueProcessor<Q extends Queue, T> implements BackendProcessorInterface {
  @Create
  late Db db;

  Stats? stats;

  @InjectClassName
  String get className;

  @Inject
  ServerConfig get serverConfig;

  @Inject
  Q get queue;

  Logger get logger => new Logger(db, serverConfig.getRequired<int>('service_id'), serverConfig.getRequired<bool>('debug'));

  Future processMessage(dynamic message);
}
