import 'package:flutter_tts/flutter_tts.dart';

/// Native text-to-speech output shared by iOS and Android.
class NikoSpeechOutputService {
  NikoSpeechOutputService({FlutterTts? engine}) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  bool _configured = false;

  Future<void> speak(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;

    await _configure();
    await _engine.stop();

    final language = _languageForText(message);
    final availableLanguages = await _engine.getLanguages;
    final matchingLanguages = availableLanguages
        .whereType<String>()
        .where((item) => item.toLowerCase().startsWith(language.substring(0, 2)))
        .toList();
    final locale = matchingLanguages.isNotEmpty ? matchingLanguages.first : language;

    await _engine.setLanguage(locale);
    await _selectMaleVoice(locale);
    await _engine.speak(message);
  }

  Future<void> stop() => _engine.stop();

  Future<void> _configure() async {
    if (_configured) return;
    // Keep speech in the foreground app session; do not request background audio.
    await _engine.setSharedInstance(true);
    await _engine.setSpeechRate(0.47);
    await _engine.setPitch(0.92);
    await _engine.setVolume(1.0);
    _configured = true;
  }

  Future<void> _selectMaleVoice(String locale) async {
    try {
      final voices = await _engine.getVoices;
      for (final item in voices) {
        if (item is! Map) continue;
        final voiceLocale = item['locale']?.toString().toLowerCase() ?? '';
        final gender = item['gender']?.toString().toLowerCase() ?? '';
        if (voiceLocale.startsWith(locale.substring(0, 2).toLowerCase()) &&
            gender.contains('male')) {
          final identifier = item['identifier']?.toString();
          final name = item['name']?.toString();
          if (identifier != null && identifier.isNotEmpty) {
            await _engine.setVoice({'identifier': identifier});
          } else if (name != null && name.isNotEmpty) {
            await _engine.setVoice({'name': name, 'locale': voiceLocale});
          }
          return;
        }
      }
    } catch (_) {
      // Use the system's default voice when voice metadata is unavailable.
    }
  }

  String _languageForText(String text) {
    if (RegExp(r'[\\u0600-\\u06FF]').hasMatch(text)) return 'ar-SA';
    if (RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(text)) return 'tr-TR';
    return 'en-US';
  }
}
