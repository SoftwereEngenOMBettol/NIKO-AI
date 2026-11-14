// Flutter 3.50 marks the Material library as deprecated while its replacement API
// is still evolving. Keep the current stable widgets until the migration is ready.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'data/local_conversation_store.dart';
import 'data/niko_preferences_store.dart';
import 'services/niko_api_chat_service.dart';
import 'services/niko_chat_service.dart';
import 'services/niko_speech_output_service.dart';
import 'utils/text_direction.dart';

void main() {
  runApp(const NikoApp());
}

class NikoApp extends StatelessWidget {
  const NikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0B1018);
    return MaterialApp(
      title: 'NIKO AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6DE0D2),
          brightness: Brightness.dark,
          surface: const Color(0xFF151D29),
        ),
        useMaterial3: true,
      ),
      home: const NikoHomePage(),
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      fromUser: json['fromUser'] as bool? ?? false,
    );
  }
}

class NikoHomePage extends StatefulWidget {
  const NikoHomePage({super.key});

  @override
  State<NikoHomePage> createState() => _NikoHomePageState();
}

class _NikoHomePageState extends State<NikoHomePage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _conversationStore = LocalConversationStore();
  final _preferencesStore = NikoPreferencesStore();
  final NikoApiChatService _chatService = NikoApiChatService();
  final NikoSpeechOutputService _speechOutput = NikoSpeechOutputService();
  NikoReplyLanguage _replyLanguage = NikoReplyLanguage.automatic;
  bool _isReplying = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  TextDirection _composerDirection = TextDirection.rtl;
  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'هلا، أنا نيكو. موجود معك — وش حاب نسوي اليوم؟',
      fromUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _restoreConversation();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    try {
      final language = await _preferencesStore.loadReplyLanguage();
      if (mounted) setState(() => _replyLanguage = language);
    } catch (_) {
      // Keep automatic language mode if preferences cannot be read.
    }
  }

  Future<void> _showSettings() async {
    var selectedLanguage = _replyLanguage;
    final selected = await showDialog<NikoReplyLanguage>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إعدادات نيكو'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لغة ردود نيكو'),
              const SizedBox(height: 10),
              DropdownButtonFormField<NikoReplyLanguage>(
                initialValue: selectedLanguage,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: NikoReplyLanguage.values.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedLanguage = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'اختيار اللغة محفوظ على هذا الجهاز. وضع التلقائي سيعتمد على محرك اللغة عند ربط الذكاء الاصطناعي.',
                style: TextStyle(color: Color(0xFF91A0B2), fontSize: 12, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedLanguage),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _preferencesStore.saveReplyLanguage(selected);
    if (mounted) setState(() => _replyLanguage = selected);
  }

  Future<void> _restoreConversation() async {
    try {
      final saved = await _conversationStore.loadMessages();
      if (!mounted || saved.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(saved.map(ChatMessage.fromJson));
      });
    } catch (_) {
      // Keep the welcome conversation available if local storage is unavailable.
    }
  }

  Future<void> _persistConversation() async {
    await _conversationStore.saveMessages(
      _messages.map((message) => message.toJson()).toList(),
    );
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مسح المحادثة؟'),
        content: const Text('سيتم حذف سجل المحادثة المحفوظ على هذا الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _conversationStore.clear();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(const ChatMessage(
          text: 'هلا، أنا نيكو. موجود معك — وش حاب نسوي اليوم؟',
          fromUser: false,
        ));
    });
  }

  Future<void> _speakMessage(String text) async {
    try {
      await _speechOutput.speak(text);
    } catch (_) {
      _showVoiceMessage('تعذر تشغيل الصوت. تحقق من أصوات اللغة المثبتة على الجهاز.');
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _chatService.close();
    _speechOutput.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true));
      _isReplying = true;
      _composerDirection = TextDirection.rtl;
    });
    _messageController.clear();
    unawaited(_persistConversation());

    try {
      final reply = await _chatService.createReply(
        userMessage: text,
        language: _replyLanguage,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, fromUser: false));
        _isReplying = false;
      });
      unawaited(_persistConversation());
    } on NikoChatException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: error.message, fromUser: false));
        _isReplying = false;
      });
      unawaited(_persistConversation());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const ChatMessage(
          text: 'حدث خطأ غير متوقع أثناء الاتصال بعقل نيكو. حاول مرة أخرى.',
          fromUser: false,
        ));
        _isReplying = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            setState(() => _isListening = status == 'listening');
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تعذر التعرف على الصوت: ${error.errorMsg}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
        _speechInitialized = available;
      }

      if (!_speechInitialized) {
        _showVoiceMessage('التعرف على الصوت غير متاح. تحقق من الأذونات وإعدادات الجهاز.');
        return;
      }

      String? localeId;
      if (_replyLanguage != NikoReplyLanguage.automatic) {
        final prefix = switch (_replyLanguage) {
          NikoReplyLanguage.arabic => 'ar',
          NikoReplyLanguage.english => 'en',
          NikoReplyLanguage.turkish => 'tr',
          NikoReplyLanguage.automatic => '',
        };
        final locales = await _speech.locales();
        final matching = locales.where(
          (locale) => locale.localeId.toLowerCase().startsWith(prefix),
        );
        if (matching.isNotEmpty) {
          localeId = matching.first.localeId;
        } else {
          _showVoiceMessage('لغة التعرف المطلوبة غير مثبتة أو غير مدعومة على الجهاز.');
          return;
        }
      }

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _messageController.text = result.recognizedWords;
            _messageController.selection = TextSelection.collapsed(
              offset: _messageController.text.length,
            );
            _composerDirection = textDirectionFor(result.recognizedWords);
          });
        },
      );
      if (mounted) setState(() => _isListening = _speech.isListening);
    } catch (_) {
      _showVoiceMessage('حدث خطأ أثناء تشغيل الميكروفون. تحقق من أذونات iPhone.');
    }
  }

  void _showVoiceMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  children: [
                    _buildWelcome(),
                    const SizedBox(height: 26),
                    ..._messages.map((message) => _MessageBubble(
                      message: message,
                      onSpeak: message.fromUser ? null : () => _speakMessage(message.text),
                    )),
                    if (_isReplying)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12, right: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF8AF0DD), Color(0xFF3B9FAD)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF55CDBD).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Color(0xFF071218),
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NIKO AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                SizedBox(height: 3),
                Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF65D7B5)),
                    SizedBox(width: 6),
                    Text('مساعدك الشخصي', style: TextStyle(color: Color(0xFF91A0B2), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearConversation,
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFB8C5D3)),
            tooltip: 'مسح المحادثة',
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded, color: Color(0xFFB8C5D3)),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مساحتك، بطريقتك.',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 7),
        const Text(
          'تحدث معي بالعربية أو English أو Türkçe، وغيّر لهجتك في أي وقت.',
          style: TextStyle(color: Color(0xFF91A0B2), fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 17),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LanguageTag(label: 'العربية', code: 'AR'),
            _LanguageTag(label: 'English', code: 'EN'),
            _LanguageTag(label: 'Türkçe', code: 'TR'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF131D29),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF263747)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF72DCCB), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'هذه أول نسخة تجريبية من واجهة NIKO. نبني قدراته خطوة بخطوة.',
                  style: TextStyle(color: Color(0xFFB9C7D5), fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF101722),
        border: Border(top: BorderSide(color: Color(0xFF202B39))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            onPressed: _toggleVoiceInput,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1C2B37),
              foregroundColor: const Color(0xFF78DCCB),
              fixedSize: const Size(48, 48),
            ),
            icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
            tooltip: _isListening ? 'إيقاف الاستماع' : 'الإدخال الصوتي',
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _messageController,
              textDirection: _composerDirection,
              textAlign: TextAlign.start,
              onChanged: (value) {
                final direction = textDirectionFor(value);
                if (direction != _composerDirection) {
                  setState(() => _composerDirection = direction);
                }
              },
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'اكتب لنيكو...',
                hintStyle: const TextStyle(color: Color(0xFF778697), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A2431),
                contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          IconButton.filled(
            onPressed: _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF75DDCA),
              foregroundColor: const Color(0xFF071218),
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
            tooltip: 'إرسال',
          ),
        ],
      ),
    );
  }
}

class _LanguageTag extends StatelessWidget {
  const _LanguageTag({required this.label, required this.code});
  final String label;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF17232F),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2B3D4D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code, style: const TextStyle(color: Color(0xFF72DCCB), fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Color(0xFFD5DEE8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onSpeak});
  final ChatMessage message;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF244B4C) : const Color(0xFF192432),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isUser ? 5 : 17),
            bottomRight: Radius.circular(isUser ? 17 : 5),
          ),
          border: Border.all(
            color: isUser ? const Color(0xFF36706C) : const Color(0xFF283747),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: textDirectionFor(message.text),
              child: Text(
                message.text,
                textAlign: TextAlign.start,
                style: const TextStyle(color: Color(0xFFE6EDF4), fontSize: 14, height: 1.65),
              ),
            ),
            if (onSpeak != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  color: const Color(0xFF78DCCB),
                  tooltip: 'استمع إلى الرد',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
