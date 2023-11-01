library swift_server.test;

import 'dart:io';
import 'dart:convert';

Future<Map> getJsonFromApi(String domain, String path, {Map? post, Map? headers}) async {
  Map<String, String> env = Platform.environment;
  var domainSuffix = env['SWIFT_SUFFIX'] ?? '';
  var proto = domainSuffix.isEmpty ? 'https' : 'http';
  String url = '$proto://$domain$domainSuffix';
  var client = new HttpClient();

  var request = await client.getUrl(Uri.parse('$url$path'));
  if (headers != null) {
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
  }
  if (post != null) {
    String body = json.encode(post);
    request.headers.set(HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");
    request.headers.set(HttpHeaders.contentLengthHeader, body.length);
    request.write(body);
  }
  var response = await request.close();
  String responseBody = await response.transform(const Utf8Decoder()).join();
  return jsonDecode(responseBody);
}
