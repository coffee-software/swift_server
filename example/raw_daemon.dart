import 'package:swift_server/daemon.dart';

import 'raw_lib.dart';

part 'raw_daemon.c.dart';

void main (List<String> arguments) async {
  await $om.daemon.run(arguments);
}

abstract class TestJob extends Job {

  @Inject
  TestQueue1 get testQueue1;

  @Inject
  TestQueue2 get testQueue2;

  int minuteInterval = 1;

  Future run() async {
    print('running test job');
    await testQueue2.postMessage('test_message');
  }
}

abstract class TestQueue1Processor extends QueueProcessor<TestQueue1, int> {

  Future processMessage(int message) async {
    print('queue 1 message: ' + message.toString());
  }
}

abstract class TestQueue2Processor extends QueueProcessor<TestQueue2, String> {

  Future processMessage(String message) async {
    if (message == 'exception') {
      throw new Exception('test exception');
    }
    print('queue 2 message: ' + message.toString());
  }
}