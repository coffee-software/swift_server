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

    var type = config.getRequired<String>('mailer.type');
    if (type == 'smtp') {
      return await _sendSmtpEmail(subject, bodyHtml, recipients, replyTo: replyTo);
    } else if (type == 'print') {
      return await _printEmail(subject, bodyHtml, recipients, replyTo: replyTo);
    } else {
      throw Exception('undefined mailer type');
    }
  }

  Future<bool> _printEmail(
      String subject,
      String bodyHtml,
      Iterable<String> recipients,
      {
        Iterable<String> replyTo = const []
      }
      ) async {
    print('################## SENDING EMAIL ##################');
    print('# subject: ' + subject);
    print('# recipients: ' + recipients.join(','));
    print('# replyTo: ' + replyTo.join(','));
    print('##################    BODY       ##################');
    print(bodyHtml);
    print('###################################################');
    return true;
  }

  Future<bool> _sendSmtpEmail(
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