import 'package:influxdb_client/api.dart';
import 'package:swift_server/config.dart';

class Stats {
  ServerConfig config;
  String prefix;
  String className;
  int serviceId;

  Stats(this.config, this.serviceId, this.prefix, this.className);

  Map<String, String> tags = {};

  var points = List<Point>.empty(growable: true);

  Future<void> addTag(String tagName, String value) async {
    tags[tagName] = value;
  }

  String get pointPrefix => '${config.getOptional<String>('influx.pointPrefix', '')}_';

  Future addPoint(String key, int value) async {
    points.add(Point(pointPrefix + key).addField('value', value));
  }

  Future saveStats(int queriesCount, int timeMs) async {
    if (config.getOptional<String>('influx.url', 'none') == 'none') {
      return;
    }

    var client = InfluxDBClient(
      url: config.getRequired<String>('influx.url'),
      token: config.getRequired<String>('influx.token'),
      org: config.getRequired<String>('influx.org'),
      bucket: config.getRequired<String>('influx.bucket'),
    );

    // Create write service
    var writeApi = client.getWriteService(WriteOptions().merge(precision: WritePrecision.s, batchSize: 100, flushInterval: 5000, gzip: true));

    var time = DateTime.now().toUtc();
    var taggedPoint = Point(
      '$pointPrefix${prefix}_api',
    ).addTag('service_id', serviceId.toString()).addTag('action', className).addField('response_time', timeMs).addField('db_queries', queriesCount);

    var untaggedPoint = Point(
      '$pointPrefix${prefix}_api',
    ).addTag('service_id', 'ALL').addTag('action', 'ALL').addField('response_time', timeMs).addField('db_queries', queriesCount);

    tags.forEach((key, value) {
      taggedPoint.addTag(key, value);
      untaggedPoint.addTag(key, 'ALL');
    });

    points.add(taggedPoint);
    points.add(untaggedPoint);

    for (var i = 0; i < points.length; i++) {
      points[i].time(time);
    }
    await writeApi.write(points).catchError((exception) {
      print('STATS SAVE ERROR');
      print(exception);
    });
  }
}
