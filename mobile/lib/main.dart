import 'package:flutter/material.dart';

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
        fontFamily: 'Roboto',
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
}

class NikoHomePage extends StatefulWidget {
  const NikoHomePage({super.key});

  @override
  State<NikoHomePage> createState() => _NikoHomePageState();
}

class _NikoHomePageState extends State<NikoHomePage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'هلا، أنا نيكو. موجود معك — وش حاب نسوي اليوم؟',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? preset]) {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true));
      _messages.add(const ChatMessage(
        text: 'وصلتني رسالتك. واجهة المحادثة جاهزة، والخطوة التالية هي ربط عقل NIKO حتى أقدر أفهم طلبك وأرد عليك فعلياً.',
        fromUser: false,
      ));
    });
    _messageController.clear();
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

  void _showVoiceNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الإدخال الصوتي قيد التطوير وسيُضاف بعد اختبار محركات الصوت.'),
        behavior: SnackBarBehavior.floating,
      ),
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
                    ..._messages.map((message) => _MessageBubble(message: message)),
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('الإعدادات ستُضاف في المرحلة القادمة.')),
            ),
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
            onPressed: _showVoiceNotice,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1C2B37),
              foregroundColor: const Color(0xFF78DCCB),
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.mic_none_rounded),
            tooltip: 'الصوت',
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _messageController,
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
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
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
        child: Text(
          message.text,
          style: const TextStyle(color: Color(0xFFE6EDF4), fontSize: 14, height: 1.65),
        ),
      ),
    );
  }
}
