import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's conversation on this device only.
class LocalConversationStore {
  static const String _storageKey = 'niko.conversation.v1';

  Future<List<Map<String, dynamic>>> loadMessages() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];

    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(messages));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}