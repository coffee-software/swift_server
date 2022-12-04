library c7server;

import 'dart:convert';
import 'dart:io';
import 'package:swift_composer/swift_composer.dart';
import 'package:mysql_client/mysql_client.dart';
import 'dart:collection';

import 'package:swift_server/config.dart';

@Compose
abstract class Db {

  @Inject
  ServerConfig get config;

  MySQLConnection? connection;

  int counter = 0;

  Future<MySQLConnection> getConnection() async {
    if (connection == null) {
      connection = await MySQLConnection.createConnection(
        host: config.getRequired<String>('database.host'),
        port: config.getRequired<int>('database.port'),
        userName: config.getRequired<String>('database.user'),
        databaseName: config.getRequired<String>('database.database'),
        password: config.getRequired<String>('database.password'),
        secure: true
      );
      await connection!.connect();
      //temporary fix for new mysql version
      //await Future.delayed(Duration(milliseconds: 1));
    }
    return connection!;
  }

  Future<void> disconnect() async {
    if (connection != null) {
      var tmpConnection = connection;
      connection = null;
      await tmpConnection!.close();
    }
  }

  /*DateTime fixTZ(DateTime dbDate) {
    //datetime from database is returned with local value but with tz forced to UTC
    //fix for datetime beeing forced to utc
    return new DateTime.fromMillisecondsSinceEpoch(dbDate
        .subtract(new DateTime.now().timeZoneOffset)
        .millisecondsSinceEpoch);
  }*/

  Future<Iterable<Map>> fetchRows(String sql, [List<Object?>? values]) async {
    counter++;
    List<Map> ret = [];
    for (var row in (await _prepareAndExecute(sql, values)).rows) {
      ret.add(row.typedAssoc());
    }
    return ret;
  }

  Future<List<T>> fetchCol<T>(String sql, [List<Object?>? values]) async {
    counter++;
    List<T> ret = [];
    for (var row in (await _prepareAndExecute(sql, values)).rows) {
      ret.add(row.typedColAt<T>(0)!);
    }
    return ret;
  }

  Future<Map?> fetchRow(String sql, [List<Object?>? values]) async {
    counter++;
    Map? ret = null;
    for (var row in (await _prepareAndExecute(sql, values)).rows) {
      ret = row.typedAssoc();
    }
    return ret;
  }

  Future<T> fetchOne<T>(String sql, [List<Object?>? values]) async {
    counter++;
    dynamic ret = null;
    for (var row in (await _prepareAndExecute(sql, values)).rows) {
      ret = row.typedColAt<T>(0);
    }
    return ret;
  }

  Future<IResultSet> query(String sql, [List<dynamic>? values]) async {
    counter++;
    return await _prepareAndExecute(sql, values);
  }

  Future<IResultSet> _prepareAndExecute(String sql, [List<dynamic>? values]) async {
    if (values == null) {
      return await (await this.getConnection()).execute(sql);
    }
    var stmt = await (await this.getConnection()).prepare(sql);
    var ret = await stmt.execute(values);
    await stmt.deallocate();
    return ret;
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