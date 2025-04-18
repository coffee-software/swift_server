library swift_server;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:swift_composer/swift_composer.dart';
import 'package:swift_server/config.dart';

abstract class MailerAttachment {

  Attachment _getAttachment();

  Attachment getAsInline(String key) {
    var attachment = _getAttachment()
      ..location = Location.inline
      ..cid = '<$key>';
    attachment.additionalHeaders['X-Attachment-Id'] = key;
    return attachment;
  }

  Attachment getAsAttachment(String key) {
    var attachment = _getAttachment()
    ..fileName = key
    ..location = Location.attachment;
    return attachment;
  }

}

class MailerFileAttachment extends MailerAttachment {
  String mime;
  String name;
  File file;
  MailerFileAttachment(this.file, this.name, this.mime);

  Attachment _getAttachment() {
    return FileAttachment(file, fileName: name, contentType: '$mime; name="$name"');
  }
}

class MailerBase64Attachment extends MailerAttachment {
  String mime;
  String name;
  String contents;
  MailerBase64Attachment(this.contents, this.name, this.mime);

  Attachment _getAttachment() {
    return StreamAttachment(Stream.value(List<int>.from(base64Decode(contents))), '$mime; name="$name"', fileName: name);
  }
}

class MailAddress {

  final String? name;
  final String email;

  const MailAddress(this.email, [this.name]);

  @override
  String toString() => "${name ?? ''} <$email>";
}

@Compose
abstract class Mailer {

  @Inject
  ServerConfig get config;

  Future<bool> sendEmail(
      String subject,
      String bodyHtml,
      String bodyText,
      Iterable<MailAddress> recipients,
      {
        Map<String, MailerAttachment> images = const {},
        Map<String, MailerAttachment> attachments = const {},
        Iterable<MailAddress> replyTo = const [],
        Iterable<MailAddress> sendFyiTo = const [],
      }
      ) async {

    var type = config.getRequired<String>('mailer.type');
    if (type == 'smtp') {
      var ret = await _sendSmtpEmail(subject, bodyHtml, bodyText, recipients, replyTo: replyTo, images: images, attachments: attachments);
      if (sendFyiTo.isNotEmpty) {
        for (var fyiRecipient in sendFyiTo) {
          String fyiSubject = 'FYI: ' + recipients.join(',') + ' ' + subject;
          await _sendSmtpEmail(fyiSubject, bodyHtml, bodyText, [fyiRecipient], replyTo: replyTo, images: images, attachments: attachments);
        }
      }
      return ret;

    } else if (type == 'print') {
      return await _printEmail(subject, bodyText, recipients, replyTo: replyTo, images: images, attachments: attachments);
    } else {
      throw Exception('undefined mailer type');
    }
  }

  Future<bool> _printEmail(
      String subject,
      String bodyText,
      Iterable<MailAddress> recipients,
      {
        Map<String, MailerAttachment> images = const {},
        Map<String, MailerAttachment> attachments = const {},
        Iterable<MailAddress> replyTo = const []
      }
      ) async {
    print('################## SENDING EMAIL ##################');
    print('# subject: ' + subject);
    print('# recipients: ' + recipients.join(','));
    print('# replyTo: ' + replyTo.join(','));
    print('##################   TEXT BODY   ##################');
    print(bodyText);
    print('###################################################');
    print('images: ' + images.keys.join(', '));
    print('attachments: ' + attachments.keys.join(', '));
    print('###################################################');
    return true;
  }

  Future<bool> _sendSmtpEmail(
      String subject,
      String bodyHtml,
      String bodyText,
      Iterable<MailAddress> recipients,
      {
        Map<String, MailerAttachment> images = const {},
        Map<String, MailerAttachment> attachments = const {},
        Iterable<MailAddress> replyTo = const []
      }
      ) async {

    var smtpServer = new SmtpServer(
        config.getRequired<String>('mailer.hostName'),
        name: config.getRequired<String>('mailer.sender.email'),
        username: config.getRequired<String?>('mailer.username'),
        password: config.getRequired<String?>('mailer.password'),
        port: config.getRequired<int>('mailer.port'),
        allowInsecure: config.getRequired<String?>('mailer.username') == null
    );

    List<Attachment> mailAttachments = [];
    for (var i in images.keys) {
      mailAttachments.add(images[i]!.getAsInline(i));
    };
    for (var a in attachments.keys) {
      mailAttachments.add(attachments[a]!.getAsAttachment(a));
    };

    int randomIdPart = new Random().nextInt((1<<32) - 1);

    final emailMessage = Message()
      ..from = Address(
          config.getRequired<String>('mailer.sender.email'),
          config.getRequired<String>('mailer.sender.name')
      )
      ..recipients.addAll(recipients.map((e) => Address(e.email, e.name)))
      ..subject = subject
      ..text = bodyText
      ..html = bodyHtml
      ..attachments = mailAttachments;

    Map<String, dynamic> headers = {
      'Message-ID': '<${DateTime.now().millisecondsSinceEpoch}-${randomIdPart}@${Platform.localHostname}>'
    };

    if (replyTo.isNotEmpty) {
      headers['Reply-To'] = replyTo.map((e) => Address(e.email, e.name));
    }

    emailMessage.headers = headers;

    //TODO retry on MailerException catch (e)
    await send(emailMessage, smtpServer);
    return true;
  }

}