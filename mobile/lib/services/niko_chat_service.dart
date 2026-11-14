enum NikoReplyLanguage {
  automatic,
  arabic,
  english,
  turkish,
}

extension NikoReplyLanguageLabel on NikoReplyLanguage {
  String get label => switch (this) {
        NikoReplyLanguage.automatic => 'تلقائي حسب لغة رسالتك',
        NikoReplyLanguage.arabic => 'العربية',
        NikoReplyLanguage.english => 'English',
        NikoReplyLanguage.turkish => 'Türkçe',
      };

  String get storageValue => name;

  static NikoReplyLanguage fromStorage(String? value) {
    return NikoReplyLanguage.values.firstWhere(
      (language) => language.name == value,
      orElse: () => NikoReplyLanguage.automatic,
    );
  }
}

/// A replaceable boundary for the future multilingual AI engine.
abstract interface class NikoChatService {
  Future<String> createReply({
    required String userMessage,
    required NikoReplyLanguage language,
  });
}

/// Transparent placeholder used until a real AI provider is configured.
class DemoNikoChatService implements NikoChatService {
  @override
  Future<String> createReply({
    required String userMessage,
    required NikoReplyLanguage language,
  }) async {
    return switch (language) {
      NikoReplyLanguage.arabic =>
        'وصلتني رسالتك. واجهة NIKO تعمل، لكن محرك الذكاء الاصطناعي لم يُربط بعد.',
      NikoReplyLanguage.english =>
        'I received your message. The NIKO interface is working, but its AI engine is not connected yet.',
      NikoReplyLanguage.turkish =>
        'Mesajını aldım. NIKO arayüzü çalışıyor, ancak yapay zekâ motoru henüz bağlanmadı.',
      NikoReplyLanguage.automatic =>
        'وصلتني رسالتك. محرك الذكاء الاصطناعي لم يُربط بعد؛ ستتم إضافة اكتشاف اللغة والرد التلقائي عند ربطه.',
    };
  }
}