import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/chat_conversation.dart';

class ChatHistoryService {
  static const boxName = 'chatHistory';
  static const maxConversations = 50;

  Box get _box => Hive.box(boxName);

  /// All conversations, newest activity first.
  List<ChatConversation> getAll() {
    return _box.values
        .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  ChatConversation? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return ChatConversation.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> save(ChatConversation conversation) async {
    await _box.put(conversation.id, conversation.toJson());
    await _enforceLimit();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Keep only the [maxConversations] most recently updated conversations.
  Future<void> _enforceLimit() async {
    if (_box.length <= maxConversations) return;
    final all = getAll(); // sorted newest-first
    for (final stale in all.skip(maxConversations)) {
      await _box.delete(stale.id);
    }
  }
}
