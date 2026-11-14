import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niko_ai/services/niko_api_chat_service.dart';
import 'package:niko_ai/services/niko_chat_service.dart';

void main() {
  test('API service sends Arabic text and returns the model reply', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'reply': 'هلا، عاصمة عُمان هي مسقط.',
          'language': 'automatic',
          'provider': 'ollama',
          'model': 'qwen2.5:3b',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = NikoApiChatService(
      baseUrl: 'http://localhost:8000/',
      client: client,
    );

    final reply = await service.createReply(
      userMessage: 'هلا نيكو، وش عاصمة عُمان؟',
      language: NikoReplyLanguage.automatic,
    );

    expect(reply, 'هلا، عاصمة عُمان هي مسقط.');
    expect(captured.url.toString(), 'http://localhost:8000/v1/chat');
    expect(jsonDecode(captured.body)['message'], 'هلا نيكو، وش عاصمة عُمان؟');
    expect(jsonDecode(captured.body)['language'], 'automatic');
    service.close();
  });

  test('API service surfaces a useful backend error', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({'detail': 'Ollama is unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        ));
    final service = NikoApiChatService(
      baseUrl: 'http://localhost:8000',
      client: client,
    );

    await expectLater(
      service.createReply(
        userMessage: 'مرحبا',
        language: NikoReplyLanguage.arabic,
      ),
      throwsA(isA<NikoChatException>()),
    );
    service.close();
  });
}
