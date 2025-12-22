import 'dart:io';

import 'package:swift_composer/swift_composer.dart';
export 'package:swift_composer/swift_composer.dart';

export 'cache.dart';
import 'config.dart';
export 'config.dart';
import 'tools.dart';
export 'tools.dart';
import 'logger.dart';
export 'logger.dart';

export 'annotations.dart';

Map sharedServerData = {};

class HttpException implements Exception {
  int code;
  String message;
  HttpException(this.code, this.message);

  @override
  String toString() {
    return "Exception: $message";
  }
}

class HttpUnauthorizedException extends HttpException {
  HttpUnauthorizedException() : super(HttpStatus.unauthorized, 'Unauthorised');
}

class HttpRequestException extends HttpException {
  HttpRequestException(String message) : super(HttpStatus.unprocessableEntity, message);
}

//shared in actions, queue processors and jobs
abstract class BackendProcessorInterface {
  Db get db;
  Logger get logger;
  ServerConfig get serverConfig;
}
