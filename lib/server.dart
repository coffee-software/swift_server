
import 'dart:io';

export 'package:swift_composer/swift_composer.dart';

export 'cache.dart';
export 'config.dart';
export 'tools.dart';

export 'annotations.dart';


Map sharedServerData = {};

class HttpException implements Exception {
  int code;
  String message;
  HttpException(this.code, this.message);
}

class HttpUnauthorizedException extends HttpException {
  HttpUnauthorizedException() : super(HttpStatus.unauthorized, 'Unauthorised');
}

class HttpRequestException extends HttpException {
  HttpRequestException(String message) : super(HttpStatus.unprocessableEntity, message);
}
