library c7server;

import 'dart:convert';
import 'dart:io';
import 'package:swift_composer/swift_composer.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:collection';

import 'package:swift_server/config.dart';

@Compose
abstract class Db {

  @Inject
  ServerConfig get config;

  MySqlConnection? connection;

  Future<MySqlConnection> getConnection() async {
    if (connection == null) {
      connection = await MySqlConnection.connect(
          ConnectionSettings(
              host: config.getRequired<String>('database.host'),
              port: config.getRequired<int>('database.port'),
              user: config.getRequired<String>('database.user'),
              db: config.getRequired<String>('database.database'),
              password: config.getRequired<String>('database.password')
          )
      );
      //temporary fix for new mysql version
      await Future.delayed(Duration(milliseconds: 1));
    }
    return connection!;
  }

  Future<void> disconnect() async {
    if (connection != null) {
      await connection!.close();
      connection = null;
    }
  }

  DateTime fixTZ(DateTime dbDate) {
    //datetime from database is returned with local value but with tz forced to UTC
    //fix for datetime beeing forced to utc
    return new DateTime.fromMillisecondsSinceEpoch(dbDate
        .subtract(new DateTime.now().timeZoneOffset)
        .millisecondsSinceEpoch);
  }

  Future<IterableBase<ResultRow>> fetchRows(String sql, [List<Object?>? values]) async {
    return await (await this.getConnection()).query(sql, values);
  }

  Future<Map?> fetchRow(String sql, [List<Object?>? values]) async {
    for (var row in await (await this.getConnection()).query(sql, values)) {
      return row.fields;
    }
    return null;
  }

  dynamic fetchOne(String sql, [List<Object?>? values]) async {
    for (var row in await (await this.getConnection()).query(sql, values)) {
      return row[0];
    }
    return null;
  }

  Future<Results> query(String sql, [List<Object?>? values]) async {
    return await (await this.getConnection()).query(sql, values);
  }

}

@Compose
abstract class Net {
  Future<dynamic> getJson(String url, {Map<String, String> headers = const {}}) async {
    var client = new HttpClient();
    var req = await client.getUrl(Uri.parse(url));
    headers.forEach((key, value) {
      req.headers.add(key, value);
    });

    var response = await req.close();
    client.close();
    final contents = StringBuffer();
    await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }
    return jsonDecode(contents.toString());
  }
}