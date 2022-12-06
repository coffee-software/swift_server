library c7server;

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';

@Compose
abstract class Mailer {

  @Inject
  ServerConfig get config;

  Future<bool> sendEmail(
      String subject,
      String bodyHtml,
      Iterable<String> recipients,
      {
        Iterable<String> replyTo = const []
      }
      ) async {
    var smtpServer = new SmtpServer(
        config.getRequired<String>('mailer.hostName'),
        name: config.getRequired<String>('mailer.sender.email'),
        username: config.getRequired<String>('mailer.username'),
        password: config.getRequired<String>('mailer.password'),
        port: config.getRequired<int>('mailer.port')
    );

    final emailMessage = Message()
      ..from = Address(
          config.getRequired<String>('mailer.sender.email'),
          config.getRequired<String>('mailer.sender.name')
      )
      ..recipients.addAll(recipients)
      ..subject = subject
      //TODO html stripper:
      ..text = bodyHtml.replaceAll(RegExp(
          r"<[^>]*>",
          multiLine: true
        ), '')
      ..html = bodyHtml;

    if (replyTo.isNotEmpty) {
      emailMessage.headers = {
        'Reply-To': replyTo.join(',')
      };
    }

    //TODO retry on MailerException catch (e)
    await send(emailMessage, smtpServer);
    return true;
  }
}