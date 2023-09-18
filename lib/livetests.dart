library swift_server.test;

import 'dart:io';
import 'dart:convert';

Future<Map> getJsonFromApi(String domain, String path) async {
  Map<String, String> env = Platform.environment;
  var domainSuffix = env['SWIFT_SUFFIX'] ?? '';
  var proto = domainSuffix.isEmpty ? 'https' : 'http';
  String url = '$proto://$domain$domainSuffix';
  var client = new HttpClient();
  var response = await(await client.getUrl(Uri.parse('$url$path'))).close();
  var body = await response.transform(const Utf8Decoder()).join();
  return jsonDecode(body);
}
