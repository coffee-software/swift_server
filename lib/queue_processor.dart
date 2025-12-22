import 'queue.dart';
import 'stats.dart';
import 'server.dart';

@ComposeSubtypes
abstract class QueueProcessor<Q extends Queue, T> implements BackendProcessorInterface {
  @override
  @Create
  late Db db;

  Stats? stats;

  @InjectClassName
  String get className;

  @override
  @Inject
  ServerConfig get serverConfig;

  @Inject
  Q get queue;

  @override
  Logger get logger => Logger(db, serverConfig.getRequired<int>('service_id'), serverConfig.getRequired<bool>('debug'));

  Future processMessage(dynamic message);
}
