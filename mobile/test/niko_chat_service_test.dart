import 'package:flutter_test/flutter_test.dart';
import 'package:niko_ai/services/niko_chat_service.dart';

void main() {
  const service = DemoNikoChatService();

  test('Arabic reply mode returns an Arabic setup notice', () async {
    final reply = await service.createReply(
      userMessage: 'مرحبا',
      language: NikoReplyLanguage.arabic,
    );

    expect(reply, contains('لم يُربط بعد'));
  });

  test('English reply mode returns an English setup notice', () async {
    final reply = await service.createReply(
      userMessage: 'Hello',
      language: NikoReplyLanguage.english,
    );

    expect(reply, contains('not connected yet'));
  });

  test('Turkish reply mode returns a Turkish setup notice', () async {
    final reply = await service.createReply(
      userMessage: 'Merhaba',
      language: NikoReplyLanguage.turkish,
    );

    expect(reply, contains('henüz bağlanmadı'));
  });
}