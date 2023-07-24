import 'package:swift_composer/swift_composer.dart';
import 'queue.dart';
import 'tools.dart';
import 'config.dart';
import 'stats.dart';

@ComposeSubtypes
abstract class QueueProcessor<Q extends Queue, T> implements StatsAction {

  @Create
  late Db db;

  int statsSubId = 0;

  @InjectClassName
  String get className;

  @Inject
  ServerConfig get config;

  @Inject
  Q get queue;

  Future processMessage(dynamic message);
}
