library swift_server;

import 'dart:convert';
import 'dart:io';
import 'package:mysql_client/exception.dart';
import 'package:swift_composer/swift_composer.dart';
import 'package:mysql_client/mysql_client.dart';

import 'package:swift_server/config.dart';

@Compose
abstract class NamedLock {

  Map<String, RandomAccessFile?> _locks = {};

  Future<void> lock(String name) async {
    await Future.doWhile(() async {
      if (_locks.containsKey(name)) {
        await Future.delayed(const Duration(milliseconds: 10));
        return true;
      }
      String path = '/var/lock/swift_' + name;
      final file = File(path);
      var raf = file.openSync(mode: FileMode.write);
      _locks[name] = raf;
      return false;
    });
    await _locks[name]!.lock(FileLock.blockingExclusive);
  }

  Future<void> unlock(String name) async {
    _locks[name]!.closeSync();
    _locks.remove(name);
  }
}

@Compose
abstract class Db {

  @Inject
  ServerConfig get config;

  MySQLConnection? _connection;

  int counter = 0;

  Future<MySQLConnection> getConnection() async {
    if (_connection == null) {
      _connection = await MySQLConnection.createConnection(
        host: config.getRequired<String>('database.host'),
        port: config.getRequired<int>('database.port'),
        userName: config.getRequired<String>('database.user'),
        databaseName: config.getRequired<String>('database.database'),
        password: config.getRequired<String>('database.password'),
        secure: config.getRequired<bool>('database.secure'),
        //maxConnections: 10
      );
      await _connection!.connect();
    }
    return _connection!;
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      var tmpConnection = _connection;
      _connection = null;
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

  Future<T?> fetchOne<T>(String sql, [List<Object?>? values]) async {
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
    var connection = await this.getConnection();
    int retried = 0;
    while (retried <= 1) {
      try {
        if (values == null) {
          return await connection.execute(sql);
        }
        var stmt = await connection.prepare(sql);
        var ret = await stmt.execute(values);
        await stmt.deallocate();
        return ret;
      } on MySQLClientException catch(_) {
        //connection was closed. retrying once
        if (!connection.connected) {
          _connection = null;
          retried++;
          connection = await this.getConnection();
        } else {
          rethrow;
        }
      }
    }
    throw new MySQLClientException('can not retry');
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

  Future<dynamic> postJson(String url, dynamic params) async {
    var client = new HttpClient();
    var body = json.encode(params);
    Map<String,String> headers = {
      'Content-type' : 'application/json',
      'Accept': 'application/json',
    };
    final req = await client.postUrl(Uri.parse(url));
    headers.forEach((key, value) {
      req.headers.add(key, value);
    });
    req.write(body);
    var response = await req.close();
    client.close();
    final contents = StringBuffer();
    await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }
    return jsonDecode(contents.toString());
  }
}