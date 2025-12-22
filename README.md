# swift_server

Simple Micro Service Framework using swift_composer.
Create servers, daemons and cli tools with a layer to access mysql db, amqp and files.
Used by https://swift.shop

## Development Info

Running example server:

```
dart run build_runner build && dart example/raw_server.dart --config test/config.yaml
```

## Running tests:

To run tests you will need `amqp` and `database` services. 
Please see / modify `test/config.yaml` with proper configuration.

On debian you can install services by:
```
apt install rabbitmq-server mariadb-server
```

Then create proper DB schema in database:

```
CREATE DATABASE IF NOT EXISTS `swift_test`;
CREATE USER IF NOT EXISTS 'swift_test'@'%' IDENTIFIED BY 'swift_test';
GRANT ALL PRIVILEGES ON `swift_test`.* TO 'swift_test'@'%';
```

Run queries in `config/schema.sql` to create schema.

Lastly run tests:

```
dart run build_runner build
dart test/swift_server_test.dart
```
