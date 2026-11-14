import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'niko_chat_service.dart';

class NikoChatException implements Exception {
  const NikoChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Connects the app to the local NIKO API. Configure the URL with a dart-define.
class NikoApiChatService implements NikoChatService {
  NikoApiChatService({String? baseUrl, http.Client? client})
      : _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'NIKO_API_BASE_URL',
                  defaultValue: 'http://10.0.2.2:8000',
                ))
            .replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<String> createReply({
    required String userMessage,
    required NikoReplyLanguage language,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': userMessage,
              'language': language.name,
            }),
          )
          .timeout(const Duration(seconds: 160));

      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']?.toString()
            : null;
        throw NikoChatException(
          detail ?? 'تعذر على محرك نيكو معالجة الرسالة (${response.statusCode}).',
        );
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['reply'] is! String ||
          (decoded['reply'] as String).trim().isEmpty) {
        throw const NikoChatException('وصل رد غير صالح من محرك نيكو.');
      }
      return (decoded['reply'] as String).trim();
    } on TimeoutException {
      throw const NikoChatException(
        'استغرق نيكو وقتاً طويلاً في التفكير. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const NikoChatException(
        'تعذر الاتصال بعقل نيكو. تأكد من تشغيل الخادم على الكمبيوتر وأن الجهازين على الشبكة نفسها.',
      );
    } on FormatException {
      throw const NikoChatException('وصل رد غير مفهوم من خادم نيكو.');
    }
  }

  void close() => _client.close();
}
