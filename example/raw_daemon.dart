import 'package:swift_server/daemon.dart';

import 'raw_lib.dart';

part 'raw_daemon.c.dart';

void main(List<String> arguments) async {
  await $om.daemon.run(arguments);
}

abstract class TestJob extends Job {
  @Inject
  TestQueue1 get testQueue1;

  @Inject
  TestQueue2 get testQueue2;

  @override
  int get minuteInterval => 1;

  @override
  Future run() async {
    print('running test job');
    await testQueue2.postMessage('test_message');
  }
}

abstract class TestQueue1Processor extends QueueProcessor<TestQueue1, int> {
  @override
  Future processMessage(dynamic message) async {
    print('queue 1 message: $message');
  }
}

abstract class TestQueue2Processor extends QueueProcessor<TestQueue2, String> {
  @override
  Future processMessage(dynamic message) async {
    if (message == 'exception') {
      throw Exception('test exception');
    }
    print('queue 2 message: $message');
  }
}
