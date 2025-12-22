library;

import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';

import 'api.dart';

Future<MockResponse> getServerResponse(Server server, MockRequest request) async {
  await server.handleRequest(request);
  return request.response;
}

class MockHeaders extends HttpHeaders {
  Map<String, String> data;

  MockHeaders(this.data);

  @override
  List<String>? operator [](String name) {
    return data.containsKey(name) ? [data[name]!] : null;
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    // TODO: implement add
  }

  @override
  void clear() {
    // TODO: implement clear
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    // TODO: implement forEach
  }

  @override
  void noFolding(String name) {
    // TODO: implement noFolding
  }

  @override
  void remove(String name, Object value) {
    // TODO: implement remove
  }

  @override
  void removeAll(String name) {
    // TODO: implement removeAll
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    // TODO: implement set
  }

  @override
  String? value(String name) {
    return data.containsKey(name) ? data[name]! : null;
  }
}

class MockResponse extends StringBuffer implements HttpResponse {
  @override
  bool bufferOutput = false;

  @override
  int get contentLength => length;

  @override
  set contentLength(int v) {}

  @override
  Duration? deadline;

  @override
  Encoding encoding = Utf8Codec();

  @override
  bool persistentConnection = false;

  @override
  String reasonPhrase = '';

  @override
  int statusCode = 0;

  @override
  void add(List<int> data) {
    // TODO: implement add
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // TODO: implement addError
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    // TODO: implement addStream
    throw UnimplementedError();
  }

  @override
  Future close() async {
    return;
  }

  @override
  // TODO: implement connectionInfo
  HttpConnectionInfo? get connectionInfo => throw UnimplementedError();

  @override
  // TODO: implement cookies
  List<Cookie> get cookies => throw UnimplementedError();

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    // TODO: implement detachSocket
    throw UnimplementedError();
  }

  @override
  // TODO: implement done
  Future get done => throw UnimplementedError();

  @override
  Future flush() {
    // TODO: implement flush
    throw UnimplementedError();
  }

  @override
  HttpHeaders headers = MockHeaders(<String, String>{});

  @override
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily}) {
    // TODO: implement redirect
    throw UnimplementedError();
  }

  dynamic toJson() {
    if (headers.contentType != ContentType.json) {
      throw Exception('wrong content type: ${headers.contentType}');
    }
    return jsonDecode(toString());
  }
}

class MockRequest extends StreamView<Uint8List> implements HttpRequest {
  @override
  String method;

  @override
  Uri uri;

  @override
  HttpHeaders headers;

  MockRequest.get(String path, {Map<String, String> headers = const {}})
    : method = "GET",
      uri = Uri(path: path),
      headers = MockHeaders(headers),
      super(Stream.empty());

  MockRequest.post(String path, String body, {Map<String, String> headers = const {}})
    : method = "POST",
      uri = Uri(path: path),
      headers = MockHeaders(headers),
      super(Stream.fromIterable(Uint8List.fromList(body.codeUnits).map((e) => Uint8List.fromList([e]))));

  @override
  // TODO: implement certificate
  X509Certificate? get certificate => throw UnimplementedError();

  @override
  // TODO: implement connectionInfo
  HttpConnectionInfo? get connectionInfo => throw UnimplementedError();

  @override
  // TODO: implement contentLength
  int get contentLength => throw UnimplementedError();

  @override
  // TODO: implement cookies
  List<Cookie> get cookies => throw UnimplementedError();

  @override
  // TODO: implement persistentConnection
  bool get persistentConnection => throw UnimplementedError();

  @override
  // TODO: implement protocolVersion
  String get protocolVersion => throw UnimplementedError();

  @override
  // TODO: implement requestedUri
  Uri get requestedUri => throw UnimplementedError();

  @override
  // TODO: implement response
  MockResponse response = MockResponse();

  @override
  // TODO: implement session
  HttpSession get session => throw UnimplementedError();
}
