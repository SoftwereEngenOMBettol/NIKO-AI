import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Calls the NIKO backend image endpoints. Provider credentials stay server-side.
class NikoImageService {
  NikoImageService({String? baseUrl, http.Client? client})
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
      throw const NikoImageException(
        'لم يتم إعداد عنوان خادم NIKO. يجب ضبط NIKO_API_BASE_URL على عنوان HTTPS الخاص بالخادم.',
      );
    }
    final uri = Uri.tryParse('$_baseUrl$path');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw const NikoImageException(
        'عنوان خادم NIKO غير صالح. استخدم HTTPS للخادم البعيد.',
      );
    }
    return uri;
  }

  Future<Uint8List> generate({
    required String prompt,
    String size = '1024x1024',
    String quality = 'high',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _endpoint('/v1/images/generations'),
    )
      ..fields['prompt'] = prompt
      ..fields['size'] = size
      ..fields['quality'] = quality;

    final response = await _client.send(request).timeout(
          const Duration(minutes: 4),
        );
    final bytes = await response.stream.toBytes();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = String.fromCharCodes(bytes);
      throw NikoImageException(
        detail.isNotEmpty ? detail : 'تعذر إنشاء الصورة (${response.statusCode}).',
      );
    }
    if (bytes.isEmpty ||
        !(response.headers['content-type'] ?? '').startsWith('image/')) {
      throw const NikoImageException('لم يرجع محرك الصور ملف صورة صالحاً.');
    }
    return bytes;
  }

  void close() => _client.close();
}

class NikoImageException implements Exception {
  const NikoImageException(this.message);
  final String message;

  @override
  String toString() => message;
}
