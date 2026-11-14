import 'package:shared_preferences/shared_preferences.dart';

import '../services/niko_chat_service.dart';

class NikoPreferencesStore {
  static const _replyLanguageKey = 'niko.reply_language.v1';

  Future<NikoReplyLanguage> loadReplyLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    return NikoReplyLanguageLabel.fromStorage(
      preferences.getString(_replyLanguageKey),
    );
  }

  Future<void> saveReplyLanguage(NikoReplyLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_replyLanguageKey, language.storageValue);
  }
}