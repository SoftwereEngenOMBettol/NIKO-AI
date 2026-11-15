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

/// Connects to the authenticated NIKO API. Configure an HTTPS URL with dart-define.
class NikoApiChatService implements NikoChatService {
  NikoApiChatService({String? baseUrl, http.Client? client})
      : _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'NIKO_API_BASE_URL',
                  defaultValue: '',
                ))
            .replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _endpoint(String path) {
    if (_baseUrl.isEmpty) {
      throw const NikoChatException(
        'لم يتم إعداد عنوان خادم NIKO. يجب ضبط NIKO_API_BASE_URL على عنوان HTTPS الخاص بالخادم.',
      );
    }
    final uri = Uri.tryParse('$_baseUrl$path');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw const NikoChatException(
        'عنوان خادم NIKO غير صالح. استخدم HTTPS للخادم البعيد.',
      );
    }
    return uri;
  }

  @override
  Future<String> createReply({
    required String userMessage,
    required NikoReplyLanguage language,
  }) async {
    try {
      final response = await _client
          .post(
            _endpoint('/v1/chat'),
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
        'تعذر الاتصال بخادم NIKO. تحقق من اتصال الإنترنت وحالة الخدمة.',
      );
    } on FormatException {
      throw const NikoChatException('وصل رد غير مفهوم من خادم نيكو.');
    }
  }

  void close() => _client.close();
}
