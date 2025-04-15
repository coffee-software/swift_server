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

class Logger {
  Db db;
  Logger(this.db);

  Future<void> log(String type, String message, {String? subtype = null, int? entityId = null}) async {
    await db.query('INSERT INTO `run_logs` SET `type` = ?, `subtype` = ?, `entity_id` = ?, `message` = ?', [
      type,
      subtype,
      entityId,
      message
    ]);
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

  /*
   * this is a simple atomic verison of INSERT INTO .. ON DUPLCIATE KEY UPDATE id=LAST_INSERT_ID(`id`) that returns primary key and does not create large gaps in auto_increment
   */
  Future<int> getIdOrInsert(String tableName, String where, List<Object?> whereArgs, String set, List<Object?> setArgs) async {
    var id = await fetchOne<int>(
        'SELECT `id` FROM $tableName WHERE $where', whereArgs
    );
    if (id == null) {
      //this ON DUPLICATE KEY is here so this wont have to run in transaction
      id = (await query('INSERT INTO $tableName SET $set ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(`id`);',setArgs)).lastInsertID.toInt();
    }
    return id;
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

  Future<dynamic> _json(String method, String url, dynamic params, {Map<String, String> extraHeaders = const {}}) async {
    var client = new HttpClient();
    Map<String,String> headers = {
      'Content-type' : 'application/json',
      'Accept': 'application/json',
    };
    extraHeaders.forEach((key, value) {
      headers[key] = value;
    });

    HttpClientRequest req;
    switch (method) {
      case 'get':
        req = await client.getUrl(Uri.parse(url));
        break;
      case 'put':
        req = await client.putUrl(Uri.parse(url));
        break;
      default:
        req = await client.postUrl(Uri.parse(url));
        break;
    }

    headers.forEach((key, value) {
      req.headers.add(key, value);
    });
    if (params != null) {
      var body = json.encode(params);
      req.add(utf8.encode(body));
    }
    var response = await req.close();
    client.close();
    final contents = StringBuffer();
    await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }
    return jsonDecode(contents.toString());
  }

  Future<dynamic> getJson(String url, {Map<String, String> extraHeaders = const {}}) async {
    return await _json('get', url, null, extraHeaders: extraHeaders);
  }

  Future<dynamic> putJson(String url, dynamic params, {Map<String, String> extraHeaders = const {}}) async {
    return await _json('put', url, params, extraHeaders: extraHeaders);
  }

  Future<dynamic> postJson(String url, dynamic params, {Map<String, String> extraHeaders = const {}}) async {
    return await _json('post', url, params, extraHeaders: extraHeaders);
  }

  Future<List<int>> _raw(String method, String url, Map? params, {Map<String, String> extraHeaders = const {}}) async {
    var client = new HttpClient();
    HttpClientRequest req;
    Map<String,String> headers = {};
    if (params != null) {
      headers['Content-type'] = 'application/x-www-form-urlencoded';
    }
    extraHeaders.forEach((key, value) {
      headers[key] = value;
    });

    switch (method) {
      case 'get':
        req = await client.getUrl(Uri.parse(url));
        break;
      case 'put':
        req = await client.putUrl(Uri.parse(url));
        break;
      default:
        req = await client.postUrl(Uri.parse(url));
        break;
    }
    headers.forEach((key, value) {
      req.headers.add(key, value);
    });
    if (params != null) {
      req.writeAll(params.map((k,v) => MapEntry(k, Uri.encodeComponent(k) + '=' + Uri.encodeComponent(v))).values, '&');
    }
    var response = await req.close();
    client.close();
    List<int> bytes = [];
    await for (var data in response) {
      bytes.addAll(data);
    }
    return bytes;
  }

  @deprecated
  Future<List<int>> get(String url, {Map<String, String> extraHeaders = const {}}) async {
    return await getRaw(url, extraHeaders:extraHeaders);
  }

  Future<List<int>> getRaw(String url, {Map<String, String> extraHeaders = const {}}) async {
    return await _raw('get', url, null, extraHeaders:extraHeaders);
  }

  Future<List<int>> postRaw(String url, Map? params, {Map<String, String> extraHeaders = const {}}) async {
    return await _raw('post', url, params, extraHeaders:extraHeaders);
  }

  Future<String> getHtml(String url, {Map<String, String> extraHeaders = const {}}) async {
    return new String.fromCharCodes(await _raw('get', url, null, extraHeaders:extraHeaders));
  }

  Future<String> postHtml(String url, Map? params, {Map<String, String> extraHeaders = const {}}) async {
    return new String.fromCharCodes(await _raw('post', url, params, extraHeaders:extraHeaders));
  }

}